import AppKit
import ApplicationServices

final class WindowFocuser {
    static func requestAccessibilityIfNeeded(prompt: Bool) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    func focus(_ item: WindowItem) {
        let app = NSRunningApplication(processIdentifier: item.pid)
        app?.activate(options: [])

        guard AXIsProcessTrusted() else {
            return
        }

        let axApp = AXUIElementCreateApplication(item.pid)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        guard let axWindow = matchingWindow(in: axApp, item: item) else {
            return
        }

        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, axWindow)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        app?.activate(options: [])
    }

    private func matchingWindow(in axApp: AXUIElement, item: WindowItem) -> AXUIElement? {
        guard let windows = axWindows(in: axApp), !windows.isEmpty else {
            return nil
        }

        if !item.title.isEmpty {
            if let exact = windows.first(where: { axTitle(of: $0) == item.title }) {
                return exact
            }

            if let partial = windows.first(where: { axTitle(of: $0).contains(item.title) || item.title.contains(axTitle(of: $0)) }) {
                return partial
            }
        }

        return windows.first
    }

    private func axWindows(in axApp: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        guard status == .success else {
            return nil
        }

        return value as? [AXUIElement]
    }

    private func axTitle(of window: AXUIElement) -> String {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        guard status == .success else {
            return ""
        }

        return value as? String ?? ""
    }
}
