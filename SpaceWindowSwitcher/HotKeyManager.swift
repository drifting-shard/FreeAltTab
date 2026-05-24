import ApplicationServices
import Carbon.HIToolbox
import Foundation

final class HotKeyManager {
    var handler: (() -> Void)?

    private let keyCode: Int64
    private let requiredFlags: CGEventFlags
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(keyCode: Int64, requiredFlags: CGEventFlags) {
        self.keyCode = keyCode
        self.requiredFlags = requiredFlags
    }

    deinit {
        unregister()
    }

    static func commandTab() -> HotKeyManager {
        HotKeyManager(keyCode: Int64(kVK_Tab), requiredFlags: .maskCommand)
    }

    static func requestInputMonitoringIfNeeded() {
        let granted = CGRequestListenEventAccess()
        DebugLogger.log("inputMonitoring request result=\(granted)")
    }

    func register() {
        unregister()
        DebugLogger.log("hotkey register start axTrusted=\(AXIsProcessTrusted()) inputMonitoring=\(CGPreflightListenEventAccess())")

        let eventMask = [
            CGEventType.keyDown,
            CGEventType.keyUp,
            CGEventType.tapDisabledByTimeout,
            CGEventType.tapDisabledByUserInput
        ].reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << CGEventMask(type.rawValue))
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userData in
                guard let userData else {
                    return Unmanaged.passUnretained(event)
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let eventTap = manager.eventTap {
                        CGEvent.tapEnable(tap: eventTap, enable: true)
                    }

                    return Unmanaged.passUnretained(event)
                }

                guard (type == .keyDown || type == .keyUp),
                      event.getIntegerValueField(.keyboardEventKeycode) == manager.keyCode,
                      event.flags.contains(manager.requiredFlags) else {
                    return Unmanaged.passUnretained(event)
                }

                if type == .keyDown {
                    DispatchQueue.main.async {
                        manager.handler?()
                    }
                }

                return nil
            },
            userInfo: selfPointer
        ) else {
            let message = "hotkey eventTap=hid failed axTrusted=\(AXIsProcessTrusted()) inputMonitoring=\(CGPreflightListenEventAccess())"
            NSLog("SpaceWindowSwitcher \(message)")
            DebugLogger.log(message)
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            DebugLogger.log("hotkey eventTap=hid failed to create runLoopSource")
            CFMachPortInvalidate(tap)
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        DebugLogger.log("hotkey eventTap=hid shortcut=Command-Tab registered")
    }

    func unregister() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }
}
