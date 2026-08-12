import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let panel: KeyablePanel

    init(model: AppModel) {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 390),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: OverlayView(model: model) { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    func show() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            let origin = NSPoint(
                x: visibleFrame.midX - panel.frame.width / 2,
                y: visibleFrame.maxY - panel.frame.height - 28
            )
            panel.setFrameOrigin(origin)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}
