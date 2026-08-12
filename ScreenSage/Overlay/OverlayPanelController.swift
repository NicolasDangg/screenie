import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let panel: KeyablePanel
    private var hasBeenPositioned = false
    private(set) var isPresented = false

    init(model: AppModel) {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: OverlayLayout.width, height: OverlayLayout.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: OverlayView(model: model) { [weak self] in
            self?.hide()
        })
    }

    func toggle() {
        isPresented ? hide() : show()
    }

    func show() {
        guard !isPresented else { return }
        isPresented = true
        if !hasBeenPositioned {
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            if let visibleFrame = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(
                    x: visibleFrame.midX - panel.frame.width / 2,
                    y: visibleFrame.maxY - panel.frame.height - 28
                ))
                hasBeenPositioned = true
            }
        }
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        animate { self.panel.animator().alphaValue = 1 }
    }

    func hide() {
        guard isPresented else { return }
        isPresented = false
        animate({ self.panel.animator().alphaValue = 0 }) { [weak self] in
            guard let self, !self.isPresented else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        }
    }

    private func animate(
        _ changes: () -> Void,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            changes()
        } completionHandler: {
            Task { @MainActor in completion?() }
        }
    }
}
