import AppKit
import CoreGraphics

struct WindowItem: Identifiable, Equatable {
    let id: CGWindowID
    let windowID: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let bounds: CGRect
    let icon: NSImage?

    var displayTitle: String {
        title.isEmpty ? "Untitled Window" : title
    }

    static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
        lhs.windowID == rhs.windowID
    }
}

final class SwitcherModel: ObservableObject {
    @Published private(set) var items: [WindowItem] = []
    @Published var selectedIndex: Int = 0

    var selectedItem: WindowItem? {
        guard items.indices.contains(selectedIndex) else {
            return nil
        }

        return items[selectedIndex]
    }

    func replaceItems(_ newItems: [WindowItem], preferNextWindow: Bool) {
        items = newItems

        if items.isEmpty {
            selectedIndex = 0
        } else if preferNextWindow, items.count > 1 {
            selectedIndex = 1
        } else {
            selectedIndex = 0
        }
    }

    func selectNext() {
        guard !items.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex + 1) % items.count
    }

    func selectPrevious() {
        guard !items.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex - 1 + items.count) % items.count
    }
}

