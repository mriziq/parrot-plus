import AppKit

/// Status bar item in the top-right of the menu bar. Shows recording state at
/// a glance and provides the only persistent control surface for the daemon
/// (since we run as `.accessory` — no dock icon, no main window).
///
/// The menu has named slots, top to bottom: `statusLine`, `modelLine`,
/// `microphoneItem`, `grantPermissionsItem`, `pasteLastTranscriptItem`,
/// `settingsItem`, `quitItem`. Features update a slot rather than rebuilding
/// the menu.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private static func readyStatus(_ key: HotkeyKey) -> String { "idle · hold \(key.shortName) to dictate" }

    private let statusItem: NSStatusItem
    /// Slot: what the dictation loop is doing. Driven as a `DictationObserver`.
    let statusLine: NSMenuItem
    /// Slot: the loaded model.
    let modelLine: NSMenuItem
    /// Slot: the input Parrot records from (#44), as a submenu.
    let microphoneItem: NSMenuItem
    /// What picking an input does; set by the daemon, which saves the setting.
    var onSelectMicrophone: ((_ uid: String?, _ name: String?) -> Void)?
    private var microphone = AudioSettings()
    /// Slot: reopens the onboarding window (#51). Shown in Parrot.app while
    /// a permission is missing.
    let grantPermissionsItem: NSMenuItem
    /// What `grantPermissionsItem` does; set by `OnboardingWindow`.
    var onGrantPermissions: (() -> Void)?
    /// Slot: opens the Settings window (#41) through `onOpenSettings`.
    let settingsItem: NSMenuItem
    /// Re-pastes the latest successfully delivered transcript.
    let pasteLastTranscriptItem: NSMenuItem
    private var lastTranscript = LastTranscript()
    /// Wired by the daemon to the normal guarded text-delivery path.
    var onPasteLastTranscript: ((String) -> Void)?
    /// Called by Settings…; set by the daemon, which owns the window.
    var onOpenSettings: (() -> Void)?
    /// Slot: quits Parrot Plus.
    let quitItem: NSMenuItem

    /// A degraded hotkey tap replaces the idle line, so the menu bar does not
    /// claim fn works when it does not (#37).
    private var hotkeyHealth: HotkeyHealth = .ok
    /// The key the idle line tells the user to hold (#42).
    private var hotkey: HotkeyKey = .fn
    private var isIdle = true
    private var idleStatus: String { hotkeyHealth.statusText ?? Self.readyStatus(hotkey) }

    init(modelID: String) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.autoenablesItems = false

        statusLine = NSMenuItem(title: Self.readyStatus(.fn), action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        modelLine = NSMenuItem(title: "model: \(modelID)", action: nil, keyEquivalent: "")
        modelLine.isEnabled = false
        menu.addItem(modelLine)

        microphoneItem = NSMenuItem(title: "microphone: System Default", action: nil, keyEquivalent: "")
        let microphoneMenu = NSMenu()
        microphoneMenu.autoenablesItems = false
        microphoneItem.submenu = microphoneMenu
        menu.addItem(microphoneItem)

        grantPermissionsItem = NSMenuItem(
            title: "Grant Permissions…",
            action: #selector(grantPermissionsClicked),
            keyEquivalent: ""
        )
        grantPermissionsItem.isHidden = true
        menu.addItem(grantPermissionsItem)

        menu.addItem(.separator())

        settingsItem = NSMenuItem(title: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
        menu.addItem(settingsItem)

        pasteLastTranscriptItem = NSMenuItem(
            title: "Paste Last Transcript",
            action: #selector(pasteLastTranscriptClicked),
            keyEquivalent: ""
        )
        pasteLastTranscriptItem.isEnabled = false
        menu.insertItem(pasteLastTranscriptItem, at: menu.index(of: settingsItem))

        quitItem = NSMenuItem(
            title: "Quit Parrot Plus",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        super.init()

        statusItem.menu = menu
        menu.delegate = self
        quitItem.target = self
        settingsItem.target = self
        pasteLastTranscriptItem.target = self
        grantPermissionsItem.target = self
        configureButton()
    }

    func setStatus(_ text: String) {
        statusLine.title = text
    }

    func setHotkeyHealth(_ health: HotkeyHealth) {
        hotkeyHealth = health
        if isIdle { setStatus(idleStatus) }
    }

    func setHotkey(_ key: HotkeyKey) {
        hotkey = key
        if isIdle { setStatus(idleStatus) }
    }

    func setModel(_ modelID: String) {
        modelLine.title = "model: \(modelID)"
    }

    func setMicrophone(_ audio: AudioSettings) {
        microphone = audio
        microphoneItem.title = "microphone: \(audio.displayName)"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        rebuildMicrophoneMenu()
    }

    /// Lists the current inputs each time the menu opens, so a device plugged
    /// in since the last time appears without a watcher.
    private func rebuildMicrophoneMenu() {
        guard let menu = microphoneItem.submenu else { return }
        menu.removeAllItems()

        let defaultName = InputDevice.defaultName
        let systemDefault = NSMenuItem(
            title: defaultName.map { "System Default (\($0))" } ?? "System Default",
            action: #selector(microphoneClicked(_:)),
            keyEquivalent: ""
        )
        systemDefault.target = self
        systemDefault.state = microphone.device == nil ? .on : .off
        menu.addItem(systemDefault)

        let devices = InputDevice.all()
            .filter { $0.uid != nil }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
        if !devices.isEmpty { menu.addItem(.separator()) }
        for device in devices {
            guard let uid = device.uid else { continue }
            let item = NSMenuItem(title: device.name ?? "Microphone", action: #selector(microphoneClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = uid
            item.state = uid == microphone.device ? .on : .off
            menu.addItem(item)
        }

        if let uid = microphone.device, !devices.contains(where: { $0.uid == uid }) {
            menu.addItem(.separator())
            let missing = NSMenuItem(
                title: "\(microphone.name ?? "Selected microphone") (not connected; using System Default)",
                action: nil,
                keyEquivalent: ""
            )
            missing.state = .on
            missing.isEnabled = false
            menu.addItem(missing)
        }

        microphoneItem.title = "microphone: \(microphone.displayName)"
    }

    func setLastTranscript(_ text: String) {
        lastTranscript.update(text)
        pasteLastTranscriptItem.isEnabled = lastTranscript.text != nil
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = Self.birdImage()
        image?.isTemplate = true
        button.image = image
    }

    // Inlined Lucide bird SVG. Keeping it in source means the executable has
    // no separate resource bundle to install alongside it — true single-binary.
    static let birdSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" \
    viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" \
    stroke-linecap="round" stroke-linejoin="round">\
    <path d="M16 7h.01"/>\
    <path d="M3.4 18H12a8 8 0 0 0 8-8V7a4 4 0 0 0-7.28-2.3L2 20"/>\
    <path d="m20 7 2 .5-2 .5"/>\
    <path d="M10 18v3"/>\
    <path d="M14 17.75V21"/>\
    <path d="M7 18a6 6 0 0 0 3.84-10.61"/>\
    </svg>
    """

    private static func birdImage() -> NSImage? {
        guard let data = birdSVG.data(using: .utf8),
              let image = NSImage(data: data)
        else { return nil }
        // Menu-bar status icons are nominally 18pt tall; size the SVG to match.
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc private func settingsClicked() {
        onOpenSettings?()
    }

    @objc private func microphoneClicked(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else {
            onSelectMicrophone?(nil, nil)
            return
        }
        onSelectMicrophone?(uid, sender.title)
    }

    @objc private func grantPermissionsClicked() {
        onGrantPermissions?()
    }

    @objc private func pasteLastTranscriptClicked() {
        guard let text = lastTranscript.text else { return }
        // Let AppKit close the menu before checking the currently focused field.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.onPasteLastTranscript?(text)
        }
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}

extension MenuBarController: DictationObserver {
    func dictationStarted() {
        isIdle = false
        setStatus("● recording")
    }

    func dictationTranscribing() {
        isIdle = false
        setStatus("transcribing…")
    }

    func dictationFinished(_ result: DictationResult) {
        isIdle = true
        setStatus(idleStatus)
    }

    func dictationFailed(_ error: Error) {
        isIdle = true
        setStatus(idleStatus)
    }
}
