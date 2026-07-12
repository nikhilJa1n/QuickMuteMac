import Carbon
import Cocoa

class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onKeyPressed: (() -> Void)?

    init() {
        setupHotKey()
    }

    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func setupHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass self pointer as user data to the callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let callback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr && hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    manager.onKeyPressed?()
                }
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        if installStatus != noErr {
            print("QuickMute: Failed to install event handler: \(installStatus)")
            return
        }

        // F5 key code is 96. Modifiers is 0 (no mod keys like Cmd/Shift/Opt)
        let hotKeyID = EventHotKeyID(signature: OSType(12345), id: 1)
        
        let registerStatus = RegisterEventHotKey(
            96, // F5 virtual key code
            0,  // No modifiers
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("QuickMute: Failed to register hotkey F5: \(registerStatus)")
        } else {
            print("QuickMute: F5 Global Hotkey registered successfully!")
        }
    }
}
