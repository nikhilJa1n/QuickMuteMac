import CoreAudio
import Foundation

class MicrophoneManager {
    private var currentDeviceID: AudioDeviceID?
    private var savedVolume: Float32 = 0.8
    var onMuteStatusChanged: ((Bool) -> Void)?

    init() {
        if let deviceID = queryDefaultInputDeviceID() {
            self.currentDeviceID = deviceID
            print("QuickMute: Found default input device: \(deviceID)")
            addDeviceListeners()
        } else {
            print("QuickMute: No default input device found initially")
        }
        registerDefaultInputDeviceListener()
    }

    deinit {
        removeDeviceListeners()
        
        // Remove system default input device listener
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, systemPropertyListener, selfPointer)
    }

    func isMuted() -> Bool {
        guard let deviceID = currentDeviceID else { return false }
        
        // 1. Try checking the mute property
        var isMutedValue: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isMutedValue)
        if status == noErr {
            return isMutedValue != 0
        }
        
        // 2. Fallback: check if volume is 0.0
        var volume: Float32 = 0.0
        size = UInt32(MemoryLayout<Float32>.size)
        address.mSelector = kAudioDevicePropertyVolumeScalar
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        if status == noErr {
            return volume == 0.0
        }
        
        return false
    }

    func setMuted(_ muted: Bool) {
        guard let deviceID = currentDeviceID else { return }
        
        // Prevent feedback loops by disabling notifications temporarily
        // or just let notifications trigger and resolve.
        // Let's set the property directly.
        
        // 1. Try mute property
        var muteValue: UInt32 = muted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteValue)
        if status == noErr {
            print("QuickMute: Successfully set mute to \(muted) on device \(deviceID)")
            return
        }
        
        // 2. Fallback: toggle volume scalar
        if muted {
            let currentVol = getVolume()
            if currentVol > 0 {
                savedVolume = currentVol
            }
            setVolume(0.0)
            print("QuickMute: Fallback mute (volume 0.0) on device \(deviceID)")
        } else {
            let targetVol = savedVolume > 0.0 ? savedVolume : 0.8
            setVolume(targetVol)
            print("QuickMute: Fallback unmute (volume \(targetVol)) on device \(deviceID)")
        }
    }

    func toggleMute() {
        setMuted(!isMuted())
    }

    // MARK: - Volume Helpers

    private func getVolume() -> Float32 {
        guard let deviceID = currentDeviceID else { return 0.0 }
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : 0.0
    }

    private func setVolume(_ volume: Float32) {
        guard let deviceID = currentDeviceID else { return }
        var vol = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
    }

    // MARK: - CoreAudio Observers

    private func queryDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        
        return status == noErr ? deviceID : nil
    }

    private func registerDefaultInputDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            systemPropertyListener,
            selfPointer
        )
        if status != noErr {
            print("QuickMute: Failed to register default input device listener: \(status)")
        }
    }

    private func addDeviceListeners() {
        guard let deviceID = currentDeviceID else { return }
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListener(deviceID, &muteAddress, devicePropertyListener, selfPointer)
        AudioObjectAddPropertyListener(deviceID, &volumeAddress, devicePropertyListener, selfPointer)
    }

    private func removeDeviceListeners() {
        guard let deviceID = currentDeviceID else { return }
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListener(deviceID, &muteAddress, devicePropertyListener, selfPointer)
        AudioObjectRemovePropertyListener(deviceID, &volumeAddress, devicePropertyListener, selfPointer)
    }

    fileprivate func handleDefaultDeviceChanged() {
        removeDeviceListeners()
        if let newDevice = queryDefaultInputDeviceID() {
            print("QuickMute: Default input device changed to \(newDevice)")
            currentDeviceID = newDevice
            addDeviceListeners()
        } else {
            currentDeviceID = nil
        }
        onMuteStatusChanged?(isMuted())
    }

    fileprivate func handleDeviceMuteChanged() {
        onMuteStatusChanged?(isMuted())
    }
}

// MARK: - Global C Callback Implementations

private let systemPropertyListener: AudioObjectPropertyListenerProc = { (objectID, numAddresses, addresses, clientData) -> OSStatus in
    guard let clientData = clientData else { return noErr }
    let manager = Unmanaged<MicrophoneManager>.fromOpaque(clientData).takeUnretainedValue()
    
    for i in 0..<Int(numAddresses) {
        let addr = addresses[i]
        if addr.mSelector == kAudioHardwarePropertyDefaultInputDevice {
            DispatchQueue.main.async {
                manager.handleDefaultDeviceChanged()
            }
        }
    }
    return noErr
}

private let devicePropertyListener: AudioObjectPropertyListenerProc = { (objectID, numAddresses, addresses, clientData) -> OSStatus in
    guard let clientData = clientData else { return noErr }
    let manager = Unmanaged<MicrophoneManager>.fromOpaque(clientData).takeUnretainedValue()
    
    for i in 0..<Int(numAddresses) {
        let addr = addresses[i]
        if addr.mSelector == kAudioDevicePropertyMute || addr.mSelector == kAudioDevicePropertyVolumeScalar {
            DispatchQueue.main.async {
                manager.handleDeviceMuteChanged()
            }
        }
    }
    return noErr
}
