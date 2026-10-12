import Foundation

/// Turns hotkey edges into dictation actions (ADR-003). Pure, so the rules
/// are tested without an event tap.
///
/// The tap sees modifier changes only, so it cannot see the C in ⌘C. Two
/// rules keep a shortcut typed on the hotkey from producing text:
/// - A hold shorter than `minimumHold` is discarded without transcribing.
/// - A recording is cancelled if another modifier changes while the hotkey
///   is held, and a press while another modifier is already held does not
///   record. Either way the rest of that hold is ignored.
///
/// Recording still starts on key-down, so press latency is unchanged; a
/// discarded hold just throws its audio away.
///
/// Hands-free toggle: a quick tap (down and up within `minimumHold`) keeps
/// recording and opens a `doublePressWindow`. A second press inside the
/// window locks hands-free recording, which the next press stops; a second
/// hold longer than `minimumHold` transcribes on release exactly like an
/// ordinary hold. If the window lapses with no second press, the tap is
/// discarded. The window's timer lives in `HotkeyMonitor`, which calls
/// `timeout()`; everything else here is timeless.
struct Gesture {
    /// Holds shorter than this are taps or shortcuts, not dictation.
    static let minimumHold: TimeInterval = 0.3
    /// How long after a quick tap a second press locks hands-free recording.
    static let doublePressWindow: TimeInterval = 0.4

    enum Input: Equatable {
        /// The hotkey went down. `othersHeld`: another modifier was already
        /// down, so this is a chord.
        case hotkeyDown(othersHeld: Bool)
        /// The hotkey went up.
        case hotkeyUp
        /// Another modifier changed while the hotkey was down.
        case otherModifier
    }

    enum Action: Equatable {
        /// Start recording.
        case start
        /// Stop recording and transcribe.
        case transcribe
        /// Stop recording and discard it.
        case cancel
        /// Released too quickly to dictate: recording continues while the
        /// double-press window runs. The caller starts the window's timer
        /// and calls `timeout()` when it lapses.
        case tap
    }

    private enum Phase: Equatable {
        case idle
        /// Recording since this time; the hotkey is down.
        case recording(since: TimeInterval)
        /// The hotkey is down but this hold is a chord: ignore it until release.
        case ignoring
        /// A quick tap released at this time: the hotkey is up but recording
        /// continues until the double-press window lapses or a second press.
        case pendingDoublePress(releasedAt: TimeInterval)
        /// The second press of a double-press, down since this time.
        /// Releasing quickly locks hands-free; holding on transcribes.
        case confirming(since: TimeInterval)
        /// Hands-free recording: the hotkey may be up or down. The next
        /// press stops and transcribes.
        case handsFree
    }

    private var phase: Phase = .idle

    /// Whether the hotkey is physically down, as far as the edges seen so
    /// far say. False while a tap awaits its double or hands-free runs: the
    /// next down is a fresh press.
    var isHeld: Bool {
        switch phase {
        case .recording, .ignoring, .confirming: true
        case .idle, .pendingDoublePress, .handsFree: false
        }
    }

    /// Feed one edge at `time` (seconds on a monotonic clock).
    mutating func handle(_ input: Input, at time: TimeInterval) -> Action? {
        switch (phase, input) {
        case (.idle, .hotkeyDown(let othersHeld)):
            if othersHeld {
                phase = .ignoring
                return nil
            }
            phase = .recording(since: time)
            return .start
        case (.recording(let since), .hotkeyUp):
            if time - since < Self.minimumHold {
                phase = .pendingDoublePress(releasedAt: time)
                return .tap
            }
            phase = .idle
            return .transcribe
        case (.recording, .otherModifier):
            phase = .ignoring
            return .cancel
        case (.pendingDoublePress, .hotkeyDown(let othersHeld)):
            if othersHeld {
                phase = .idle
                return .cancel
            }
            phase = .confirming(since: time)
            return nil
        case (.pendingDoublePress, .otherModifier):
            phase = .idle
            return .cancel
        case (.confirming(let since), .hotkeyUp):
            if time - since < Self.minimumHold {
                phase = .handsFree
                return nil
            }
            phase = .idle
            return .transcribe
        case (.confirming, .otherModifier):
            phase = .ignoring
            return .cancel
        case (.handsFree, .hotkeyDown):
            phase = .idle
            return .transcribe
        case (.handsFree, .hotkeyUp):
            // The end of the locking press, or a stray release: still
            // hands-free either way.
            return nil
        case (.ignoring, .hotkeyUp):
            phase = .idle
            return nil
        default:
            // A repeated down, an up with no down seen, or a modifier change
            // outside a recording.
            return nil
        }
    }

    /// The double-press window lapsed: discard the tap's recording. Anything
    /// else returns nil, so a leaked or repeated timer is harmless.
    mutating func timeout() -> Action? {
        guard case .pendingDoublePress = phase else { return nil }
        phase = .idle
        return .cancel
    }

    /// Forget the current hold, for a switch to another key. A recording in
    /// progress — held, pending its double, confirming, or hands-free — is
    /// cancelled.
    mutating func reset() -> Action? {
        defer { phase = .idle }
        switch phase {
        case .recording, .pendingDoublePress, .confirming, .handsFree: return .cancel
        case .idle, .ignoring: return nil
        }
    }
}
