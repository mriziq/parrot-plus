import CoreAudio
import Foundation

/// The default input device as Core Audio reports it, read before any
/// capture path touches it.
///
/// With no input device, or one that reports 0 Hz or 0 channels,
/// `AVAudioEngine` raises an Objective-C exception on `installTap` or
/// `start()`, which Swift cannot catch. Checking here turns that into a
/// `CaptureError`.
package struct InputDevice: Equatable {
    package var sampleRate: Double
    package var channels: UInt32
    /// The Core Audio device, or `kAudioObjectUnknown` when not read from one.
    package var id: AudioDeviceID = kAudioObjectUnknown
    /// The device's persistent Core Audio UID, or nil when not read from one.
    package var uid: String?
    /// The device's name as the Sound settings show it, or nil.
    package var name: String?
    /// Whether capture follows the system default. False for a device the
    /// user picked, which keeps recording if the default changes.
    package var followsDefault = true

    /// The current default input. Throws `CaptureError.noInputDevice` if there
    /// is none, or `.invalidInputFormat` if it cannot be recorded.
    package static func current() throws -> InputDevice {
        guard let id = defaultInputID() else { throw CaptureError.noInputDevice }
        let device = InputDevice(
            sampleRate: nominalSampleRate(id),
            channels: inputChannels(id),
            id: id,
            uid: uid(of: id),
            name: name(of: id)
        )
        try validate(sampleRate: device.sampleRate, channels: device.channels)
        return device
    }

    /// The input `uid` names, marked as chosen rather than the default, or the
    /// system default when it is away. Throws like `current()`.
    package static func selected(uid: String?) throws -> InputDevice {
        guard let uid else { return try current() }
        guard let device = pick(uid: uid, from: all(), defaultID: defaultInputID()) else {
            throw CaptureError.noInputDevice
        }
        return device
    }

    /// The device `uid` names among `devices`, then the default input, marked
    /// with whether capture follows the default. Nil if neither is there.
    /// Pure, so the fallback is tested without hardware.
    static func pick(uid: String?, from devices: [InputDevice], defaultID: AudioDeviceID?) -> InputDevice? {
        if let uid, var chosen = devices.first(where: { $0.uid == uid }) {
            chosen.followsDefault = false
            return chosen
        }
        var fallback = devices.first { $0.id == defaultID }
        fallback?.followsDefault = true
        return fallback
    }

    /// Every connected input that can be recorded, in Core Audio's order.
    package static func all() -> [InputDevice] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var ids = [AudioDeviceID](
            repeating: kAudioObjectUnknown,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        let status = ids.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, bytes.baseAddress!)
        }
        guard status == noErr else { return [] }
        return ids.compactMap { id in
            let rate = nominalSampleRate(id)
            let channels = inputChannels(id)
            guard (try? validate(sampleRate: rate, channels: channels)) != nil else { return nil }
            return InputDevice(
                sampleRate: rate,
                channels: channels,
                id: id,
                uid: uid(of: id),
                name: name(of: id)
            )
        }
    }

    /// The connected input with `uid`, or nil.
    package static func device(uid: String) -> InputDevice? {
        all().first { $0.uid == uid }
    }

    /// The system default input's name, or nil.
    package static var defaultName: String? {
        defaultInputID().flatMap(name(of:))
    }

    /// The device's stable UID, or nil.
    package static func uid(of id: AudioDeviceID) -> String? {
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &uid) == noErr,
              let value = uid?.takeRetainedValue()
        else { return nil }
        return value as String
    }

    /// The device's name as the Sound settings show it, or nil.
    package static func name(of id: AudioDeviceID) -> String? {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr,
              let value = name?.takeRetainedValue()
        else { return nil }
        return value as String
    }

    /// Throws `CaptureError.invalidInputFormat` unless both are positive.
    static func validate(sampleRate: Double, channels: UInt32) throws {
        guard sampleRate > 0, sampleRate.isFinite, channels > 0 else {
            throw CaptureError.invalidInputFormat(sampleRate: sampleRate, channels: channels)
        }
    }

    static func defaultInputID() -> AudioDeviceID? {
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id
        )
        guard status == noErr, id != kAudioObjectUnknown else { return nil }
        return id
    }

    static func nominalSampleRate(_ id: AudioDeviceID) -> Double {
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &rate) == noErr else { return 0 }
        return rate
    }

    static func inputChannels(_ id: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, list) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + $1.mNumberChannels }
    }
}
