import Cocoa
import Carbon

class HotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let onActivate: () -> Void

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
    }

    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install event handler
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onActivate()
            return noErr
        }

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &eventHandler)

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return false
        }

        // Register hotkey
        let hotKeyID = EventHotKeyID(signature: OSType(0x4857524b), id: 1) // 'HWRK'
        var mutableHotKeyID = hotKeyID

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            mutableHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            print("Failed to register hotkey: \(registerStatus)")
            return false
        }

        print("Hotkey registered successfully")
        return true
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }

    // Helper to create modifiers
    static func modifiers(command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) -> UInt32 {
        var mods: UInt32 = 0
        if command { mods |= UInt32(cmdKey) }
        if shift { mods |= UInt32(shiftKey) }
        if option { mods |= UInt32(optionKey) }
        if control { mods |= UInt32(controlKey) }
        return mods
    }
}
