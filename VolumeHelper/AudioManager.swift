import CoreAudio
import Foundation

struct AudioDevice: Hashable {
    let id: AudioDeviceID
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}

enum AudioDirection {
    case input
    case output

    var scope: AudioObjectPropertyScope {
        switch self {
        case .input:
            return kAudioObjectPropertyScopeInput
        case .output:
            return kAudioObjectPropertyScopeOutput
        }
    }

    var defaultSelector: AudioObjectPropertySelector {
        switch self {
        case .input:
            return kAudioHardwarePropertyDefaultInputDevice
        case .output:
            return kAudioHardwarePropertyDefaultOutputDevice
        }
    }
}

final class AudioManager {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)

    func devices(for direction: AudioDirection) -> [AudioDevice] {
        allDevices()
            .filter { device in
                switch direction {
                case .input:
                    return device.hasInput
                case .output:
                    return device.hasOutput
                }
            }
            .sorted { first, second in
                first.name.localizedStandardCompare(second.name) == .orderedAscending
            }
    }

    func defaultDevice(for direction: AudioDirection) -> AudioDeviceID? {
        readDefaultDevice(direction.defaultSelector)
    }

    @discardableResult
    func setDefaultDevice(_ deviceID: AudioDeviceID, for direction: AudioDirection) -> Bool {
        switch direction {
        case .input:
            return writeDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultInputDevice)
        case .output:
            let outputChanged = writeDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultOutputDevice)
            _ = writeDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
            return outputChanged
        }
    }

    func volume(for direction: AudioDirection) -> Float? {
        guard let deviceID = defaultDevice(for: direction) else {
            return nil
        }

        return volume(for: deviceID, direction: direction)
    }

    @discardableResult
    func setVolume(_ value: Float, for direction: AudioDirection) -> Bool {
        guard let deviceID = defaultDevice(for: direction) else {
            return false
        }

        return setVolume(value, for: deviceID, direction: direction)
    }

    private func allDevices() -> [AudioDevice] {
        var address = propertyAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.stride

        guard count > 0 else {
            return []
        }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)

        let status = deviceIDs.withUnsafeMutableBufferPointer { buffer in
            AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, buffer.baseAddress!)
        }

        guard status == noErr else {
            return []
        }

        return deviceIDs.compactMap { deviceID in
            let hasInput = channelCount(for: deviceID, direction: .input) > 0
            let hasOutput = channelCount(for: deviceID, direction: .output) > 0

            guard hasInput || hasOutput else {
                return nil
            }

            return AudioDevice(
                id: deviceID,
                name: deviceName(for: deviceID) ?? "Unnamed Device",
                hasInput: hasInput,
                hasOutput: hasOutput
            )
        }
    }

    private func readDefaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var address = propertyAddress(selector)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.stride)

        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceID) == noErr else {
            return nil
        }

        return deviceID == 0 ? nil : deviceID
    }

    private func writeDefaultDevice(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> Bool {
        var address = propertyAddress(selector)
        var selectedDeviceID = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.stride)

        return AudioObjectSetPropertyData(systemObject, &address, 0, nil, size, &selectedDeviceID) == noErr
    }

    private func deviceName(for deviceID: AudioDeviceID) -> String? {
        var address = propertyAddress(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.stride)

        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }

        guard status == noErr, let deviceName = name?.takeUnretainedValue() else {
            return nil
        }

        return deviceName as String
    }

    private func volume(for deviceID: AudioDeviceID, direction: AudioDirection) -> Float? {
        if let value = readVolume(deviceID, direction: direction, element: kAudioObjectPropertyElementMain) {
            return value
        }

        let values = channels(for: deviceID, direction: direction).compactMap { channel in
            readVolume(deviceID, direction: direction, element: channel)
        }

        guard values.isEmpty == false else {
            return nil
        }

        return values.reduce(0, +) / Float(values.count)
    }

    private func setVolume(_ value: Float, for deviceID: AudioDeviceID, direction: AudioDirection) -> Bool {
        let level = min(max(value, 0), 1)

        if writeVolume(level, deviceID: deviceID, direction: direction, element: kAudioObjectPropertyElementMain) {
            return true
        }

        var changed = false

        for channel in channels(for: deviceID, direction: direction) {
            if writeVolume(level, deviceID: deviceID, direction: direction, element: channel) {
                changed = true
            }
        }

        return changed
    }

    private func readVolume(_ deviceID: AudioDeviceID, direction: AudioDirection, element: AudioObjectPropertyElement) -> Float? {
        var address = propertyAddress(kAudioDevicePropertyVolumeScalar, direction.scope, element)
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.stride)

        guard AudioObjectHasProperty(deviceID, &address) else {
            return nil
        }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }

        return Float(value)
    }

    private func writeVolume(_ value: Float, deviceID: AudioDeviceID, direction: AudioDirection, element: AudioObjectPropertyElement) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyVolumeScalar, direction.scope, element)
        var writable = DarwinBoolean(false)
        var level = Float32(value)
        let size = UInt32(MemoryLayout<Float32>.stride)

        guard AudioObjectHasProperty(deviceID, &address) else {
            return false
        }

        guard AudioObjectIsPropertySettable(deviceID, &address, &writable) == noErr, writable.boolValue else {
            return false
        }

        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &level) == noErr
    }

    private func channels(for deviceID: AudioDeviceID, direction: AudioDirection) -> [AudioObjectPropertyElement] {
        let count = channelCount(for: deviceID, direction: direction)

        guard count > 0 else {
            return []
        }

        return (1...count).map { AudioObjectPropertyElement($0) }
    }

    private func channelCount(for deviceID: AudioDeviceID, direction: AudioDirection) -> Int {
        var address = propertyAddress(kAudioDevicePropertyStreamConfiguration, direction.scope)
        var size: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }

        let data = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer {
            data.deallocate()
        }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, data) == noErr else {
            return 0
        }

        let buffers = UnsafeMutableAudioBufferListPointer(data.assumingMemoryBound(to: AudioBufferList.self))

        return buffers.reduce(0) { total, buffer in
            total + Int(buffer.mNumberChannels)
        }
    }

    private func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }
}
