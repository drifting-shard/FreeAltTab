import Carbon.HIToolbox
import Foundation

final class HotKeyManager {
    var handler: (() -> Void)?

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let hotKeyID = EventHotKeyID(signature: "SpSw".fourCharCode, id: 1)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    deinit {
        unregister()
    }

    static func optionTab() -> HotKeyManager {
        HotKeyManager(keyCode: UInt32(kVK_Tab), modifiers: UInt32(optionKey))
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var pressedHotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedHotKeyID
                )

                guard status == noErr else {
                    return status
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if pressedHotKeyID.signature == manager.hotKeyID.signature,
                   pressedHotKeyID.id == manager.hotKeyID.id {
                    DispatchQueue.main.async {
                        manager.handler?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            NSLog("SpaceWindowSwitcher failed to install hotkey handler: \(installStatus)")
            return
        }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            NSLog("SpaceWindowSwitcher failed to register Option-Tab: \(registerStatus)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        unicodeScalars.reduce(0) { result, scalar in
            (result << 8) + FourCharCode(scalar.value)
        }
    }
}

