import AppKit
import CoreGraphics

final class WindowCollector {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let spaceResolver = SpaceResolver()
    private(set) var lastDebugSummary = ""
    private(set) var lastActiveSpaceID: Int32?
    private let ignoredOwners: Set<String> = [
        "Dock",
        "Window Server",
        "Control Center",
        "Notification Center",
        "SystemUIServer",
        "SpaceWindowSwitcher"
    ]

    func currentSpaceWindows() -> [WindowItem] {
        lastActiveSpaceID = nil

        if let items = currentSpaceWindowsViaActiveSpaceWindowIDs() {
            return items
        }

        if let items = currentSpaceWindowsViaSkyLightMembership() {
            lastDebugSummary = debugSummary(source: "skylight-membership-fallback", items: items)
            return items
        }

        let items = currentSpaceWindowsViaOnScreenFallback()
        lastDebugSummary = debugSummary(source: "onscreen-fallback", items: items)
        return items
    }

    func currentActiveSpaceID() -> Int32? {
        spaceResolver?.activeSpaceID()
    }

    private func currentSpaceWindowsViaActiveSpaceWindowIDs() -> [WindowItem]? {
        guard let spaceResolver, let activeSpaceWindows = spaceResolver.activeSpaceWindows() else {
            return nil
        }

        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let windowsByID = Dictionary(uniqueKeysWithValues: windowList.compactMap { info -> (CGWindowID, [String: Any])? in
            guard let windowNumber = info[kCGWindowNumber as String] as? NSNumber else {
                return nil
            }

            return (CGWindowID(windowNumber.uint32Value), info)
        })

        let items = activeSpaceWindows.windowIDs.compactMap { windowID -> WindowItem? in
            guard let info = windowsByID[windowID] else {
                return nil
            }

            return makeWindowItem(from: info)
        }

        let dedupedItems = dedupe(items)
        lastActiveSpaceID = activeSpaceWindows.spaceID
        lastDebugSummary = debugSummary(
            source: "active-space-window-ids",
            activeSpaceID: activeSpaceWindows.spaceID,
            rawWindowCount: activeSpaceWindows.windowIDs.count,
            items: dedupedItems
        )
        return dedupedItems.isEmpty ? nil : dedupedItems
    }

    private func currentSpaceWindowsViaSkyLightMembership() -> [WindowItem]? {
        guard let spaceResolver else {
            return nil
        }

        let activeSpaceIDs = spaceResolver.activeSpaceIDs()
        let normalSpaceIDs = spaceResolver.normalSpaceIDs()
        guard !activeSpaceIDs.isEmpty else {
            return nil
        }

        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let items = windowList.compactMap { info -> WindowItem? in
            guard let item = makeWindowItem(from: info) else {
                return nil
            }

            let windowSpaceIDs = spaceResolver.spaceIDs(for: item.windowID)
            guard !isStickyAcrossNormalSpaces(windowSpaceIDs, normalSpaceIDs: normalSpaceIDs) else {
                return nil
            }

            guard !windowSpaceIDs.isDisjoint(with: activeSpaceIDs) else {
                return nil
            }

            return item
        }

        return dedupe(items)
    }

    private func currentSpaceWindowsViaOnScreenFallback() -> [WindowItem] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return dedupe(windowList.compactMap(makeWindowItem))
    }

    private func makeWindowItem(from info: [String: Any]) -> WindowItem? {
        guard
            let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
            let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
            let ownerName = info[kCGWindowOwnerName as String] as? String,
            let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
            let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDict)
        else {
            return nil
        }

        let pid = pidNumber.int32Value
        guard pid != ownPID, layerNumber.intValue == 0, !ignoredOwners.contains(ownerName) else {
            return nil
        }

        let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        guard alpha > 0, bounds.width >= 80, bounds.height >= 40 else {
            return nil
        }

        let runningApp = NSRunningApplication(processIdentifier: pid)
        let title = info[kCGWindowName as String] as? String ?? ""

        return WindowItem(
            id: CGWindowID(windowNumber.uint32Value),
            windowID: CGWindowID(windowNumber.uint32Value),
            pid: pid,
            appName: runningApp?.localizedName ?? ownerName,
            title: title,
            bounds: bounds,
            icon: runningApp?.icon
        )
    }

    private func dedupe(_ items: [WindowItem]) -> [WindowItem] {
        var orderedKeys: [String] = []
        var representatives: [String: WindowItem] = [:]
        var representativeAreas: [String: CGFloat] = [:]

        for item in items {
            let key = dedupeKey(for: item)
            let itemArea = area(item.bounds)

            guard representatives[key] != nil else {
                orderedKeys.append(key)
                representatives[key] = item
                representativeAreas[key] = itemArea
                continue
            }

            if itemArea > (representativeAreas[key] ?? 0) {
                representatives[key] = item
                representativeAreas[key] = itemArea
            }
        }

        return orderedKeys.compactMap { representatives[$0] }
    }

    private func dedupeKey(for item: WindowItem) -> String {
        let keyTitle = item.title.isEmpty ? "__empty__" : item.title
        return "\(item.pid)|\(keyTitle)"
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }

    private func isStickyAcrossNormalSpaces(_ windowSpaceIDs: Set<Int>, normalSpaceIDs: Set<Int>) -> Bool {
        let normalHits = windowSpaceIDs.intersection(normalSpaceIDs)
        return normalHits.count > 1
    }

    private func debugSummary(
        source: String,
        activeSpaceID: Int32? = nil,
        rawWindowCount: Int? = nil,
        items: [WindowItem]
    ) -> String {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostText = "\(frontmost?.localizedName ?? "nil")#\(frontmost?.processIdentifier ?? 0)"
        let spaceText = activeSpaceID.map { " space=\($0)" } ?? ""
        let rawText = rawWindowCount.map { " rawWindows=\($0)" } ?? ""
        let itemText = items.map { "\($0.appName)#\($0.pid):\($0.windowID)" }.joined(separator: ", ")
        return "source=\(source)\(spaceText)\(rawText) frontmost=\(frontmostText) items=[\(itemText)]"
    }
}
