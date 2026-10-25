import Foundation

/// The input device Parrot records from (#44). The menu bar's Microphone
/// submenu and the Settings window write it; nil follows the system default.
///
/// The `settings.json` field for this feature; see `Settings`.
struct AudioSettings: Codable, Equatable {
    /// The chosen device's Core Audio UID. A UID survives reconnects and
    /// restarts, unlike an `AudioDeviceID`, which Core Audio assigns per run.
    var device: String?
    /// The chosen device's name when it was picked, shown while it is
    /// disconnected. Display only: a connected device's current name wins.
    var name: String?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        device = try c.decodeIfPresent(String.self, forKey: .device)
        name = try c.decodeIfPresent(String.self, forKey: .name)
    }

    /// The chosen device if it is connected right now.
    var connected: InputDevice? {
        device.flatMap(InputDevice.device(uid:))
    }

    /// "System Default", the device's current name, or the saved name marked
    /// not connected. Capture falls back to the default when it is away.
    var displayName: String {
        guard device != nil else { return "System Default" }
        if let connected { return connected.name ?? name ?? "Microphone" }
        return name.map { "\($0) (not connected)" } ?? "Microphone (not connected)"
    }
}
