import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = SwitcherModel()
    private lazy var panelController = SwitcherPanelController(model: model)
    private let windowCollector = WindowCollector()
    private let windowFocuser = WindowFocuser()
    private var hotKeyManager: HotKeyManager?
    private var statusItem: NSStatusItem?
    private var localEventMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var visiblePanelSpaceID: Int32?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupHotKey()
        setupEventMonitors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }

        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Space Switcher")
        item.button?.title = item.button?.image == nil ? "SW" : ""

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Switcher  Option-Tab", action: #selector(showSwitcher), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func setupHotKey() {
        let manager = HotKeyManager.optionTab()
        manager.handler = { [weak self] in
            self?.handleSwitcherHotKey()
        }
        manager.register()
        hotKeyManager = manager
    }

    private func setupEventMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleLocalEvent(event) ?? event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    private func handleSwitcherHotKey() {
        if panelController.isVisible {
            if shouldCycleVisiblePanel() {
                model.selectNext()
            } else {
                showSwitcher(selectNextWindow: true)
            }
        } else {
            showSwitcher(selectNextWindow: true)
        }
    }

    private func showSwitcher(selectNextWindow: Bool = false) {
        let items = windowCollector.currentSpaceWindows()
        model.replaceItems(items, preferNextWindow: selectNextWindow)
        visiblePanelSpaceID = windowCollector.lastActiveSpaceID
        DebugLogger.log("open preferNext=\(selectNextWindow) \(windowCollector.lastDebugSummary)")
        panelController.show(rebuild: true)
    }

    private func shouldCycleVisiblePanel() -> Bool {
        guard let visiblePanelSpaceID,
              let currentSpaceID = windowCollector.currentActiveSpaceID() else {
            return true
        }

        return visiblePanelSpaceID == currentSpaceID
    }

    private func activateSelected() {
        guard let item = model.selectedItem else {
            panelController.hide()
            visiblePanelSpaceID = nil
            return
        }

        panelController.hide()
        visiblePanelSpaceID = nil
        windowFocuser.focus(item)
    }

    private func cancelSwitcher() {
        panelController.hide()
        visiblePanelSpaceID = nil
    }

    private func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        guard panelController.isVisible else {
            return event
        }

        if event.type == .flagsChanged {
            handleFlagsChanged(event)
            return nil
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            cancelSwitcher()
            return nil
        case kVK_Return:
            activateSelected()
            return nil
        case kVK_Tab, kVK_RightArrow, kVK_DownArrow:
            model.selectNext()
            return nil
        case kVK_LeftArrow, kVK_UpArrow:
            model.selectPrevious()
            return nil
        default:
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard panelController.isVisible else {
            return
        }

        if !event.modifierFlags.contains(.option) {
            activateSelected()
        }
    }

    @objc private func showSwitcher() {
        showSwitcher(selectNextWindow: false)
    }

    @objc private func requestAccessibilityPermission() {
        WindowFocuser.requestAccessibilityIfNeeded(prompt: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
