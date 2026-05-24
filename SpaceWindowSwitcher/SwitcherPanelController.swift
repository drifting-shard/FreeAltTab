import AppKit
import SwiftUI

final class SwitcherPanelController {
    private let model: SwitcherModel
    private var panel: SwitcherPanel?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    init(model: SwitcherModel) {
        self.model = model
    }

    func show(rebuild: Bool = false) {
        if rebuild {
            discardPanel()
        }

        let size = preferredPanelSize()
        let panel = panel ?? makePanel(size: size)
        panel.setFrame(centeredFrame(size: size), display: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func discardPanel() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
    }

    private func makePanel(size: NSSize) -> SwitcherPanel {
        let hostingView = NSHostingView(rootView: SwitcherView(model: model))
        let panel = SwitcherPanel(
            contentRect: centeredFrame(size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [
            .moveToActiveSpace,
            .transient,
            .fullScreenAuxiliary
        ]

        self.panel = panel
        return panel
    }

    private func preferredPanelSize() -> NSSize {
        let itemCount = max(model.items.count, 1)
        let tileWidth: CGFloat = 82
        let tileSpacing: CGFloat = 10
        let horizontalPadding: CGFloat = 36
        let contentWidth = CGFloat(itemCount) * tileWidth + CGFloat(max(itemCount - 1, 0)) * tileSpacing + horizontalPadding
        return NSSize(width: min(max(contentWidth, 116), 700), height: 118)
    }

    private func centeredFrame(size: NSSize) -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)

        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
