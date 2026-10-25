import CoreAudio
import SwiftUI

/// The input Parrot records from (#44), a row in the General section. The
/// menu bar's Microphone submenu writes the same setting.
struct MicrophoneRow: View {
    @ObservedObject var store: SettingsStore
    @StateObject private var inputs = AudioInputs()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            PillRow("Microphone") {
                PillMenu(title: store.current.audio.displayName) {
                    Toggle("System Default", isOn: Binding(
                        get: { store.current.audio.device == nil },
                        set: { on in if on { store.update { $0.audio = AudioSettings() } } }
                    ))
                    Divider()
                    ForEach(inputs.devices.filter { $0.uid != nil }, id: \.id) { device in
                        Toggle(device.name ?? "Microphone", isOn: Binding(
                            get: { device.uid != nil && store.current.audio.device == device.uid },
                            set: { on in
                                guard on, let uid = device.uid else { return }
                                store.update {
                                    $0.audio.device = uid
                                    $0.audio.name = device.name
                                }
                            }
                        ))
                    }
                }
            }
            if store.current.audio.device != nil, store.current.audio.connected == nil {
                Text("Not connected; using the system default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The connected inputs, refreshed when one is plugged in or removed while
/// the window is open.
private final class AudioInputs: ObservableObject {
    @Published private(set) var devices = InputDevice.all()

    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var listener: AudioObjectPropertyListenerBlock?

    init() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.devices = InputDevice.all()
        }
        let system = AudioObjectID(kAudioObjectSystemObject)
        if AudioObjectAddPropertyListenerBlock(system, &address, .main, block) == noErr {
            listener = block
        }
    }

    deinit {
        guard let listener else { return }
        var address = address
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, listener
        )
    }
}
