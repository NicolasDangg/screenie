import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private enum PositionKeys {
        static let x = "overlayPosition.x"
        static let y = "overlayPosition.y"
    }

    private let model: AppModel
    private let panel: KeyablePanel
    private let defaults: UserDefaults
    private var hasBeenPositioned = false
    private(set) var isPresented = false

    init(model: AppModel, defaults: UserDefaults = .standard) {
        self.model = model
        self.defaults = defaults
        let panel = KeyablePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: OverlayLayout.width,
                height: OverlayLayout.collapsedHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: OverlayView(
            model: model,
            close: { [weak self] in self?.hide() },
            setExpanded: { [weak self] in self?.setExpanded($0) }
        ))
    }

    static func saveOrigin(_ origin: NSPoint, in defaults: UserDefaults) {
        defaults.set(origin.x, forKey: PositionKeys.x)
        defaults.set(origin.y, forKey: PositionKeys.y)
    }

    static func savedOrigin(in defaults: UserDefaults) -> NSPoint? {
        guard defaults.object(forKey: PositionKeys.x) != nil,
              defaults.object(forKey: PositionKeys.y) != nil else { return nil }
        return NSPoint(
            x: defaults.double(forKey: PositionKeys.x),
            y: defaults.double(forKey: PositionKeys.y)
        )
    }

    func toggle() {
        isPresented ? hide() : show()
    }

    func toggleTaskScreen() {
        if isPresented, model.presentationMode == .tasks {
            hide()
        } else {
            showTasks()
        }
    }

    func showTasks() {
        if !isPresented { show() }
        model.presentTasks()
        setExpanded(true)
        panel.makeKeyAndOrderFront(nil)
    }

    func startNewChat() {
        model.finishConversation()
        if isPresented {
            setExpanded(false)
        } else {
            show()
        }
    }

    func show() {
        guard !isPresented else { return }
        model.prepareForPresentation()
        setExpanded(model.isExpanded, animated: false)
        isPresented = true
        if !hasBeenPositioned {
            var savedFrame = panel.frame
            if let savedOrigin = Self.savedOrigin(in: defaults) {
                savedFrame.origin = savedOrigin
                if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(savedFrame) }) {
                    panel.setFrameOrigin(savedOrigin)
                    hasBeenPositioned = true
                }
            }
            if !hasBeenPositioned {
                let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
                    ?? NSScreen.main
                if let visibleFrame = screen?.visibleFrame {
                    panel.setFrameOrigin(NSPoint(
                        x: visibleFrame.midX - panel.frame.width / 2,
                        y: visibleFrame.minY + 64
                    ))
                }
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
        Self.saveOrigin(panel.frame.origin, in: defaults)
        model.suspendConversation()
        isPresented = false
        animate({ self.panel.animator().alphaValue = 0 }) { [weak self] in
            guard let self, !self.isPresented else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool = true) {
        let height = model.presentationMode == .tasks
            ? OverlayLayout.taskHeight
            : (expanded ? OverlayLayout.expandedHeight : OverlayLayout.collapsedHeight)
        guard panel.frame.height != height else { return }
        var frame = panel.frame
        frame.size.height = height
        if let visibleFrame = panel.screen?.visibleFrame, frame.maxY > visibleFrame.maxY - 12 {
            frame.origin.y = visibleFrame.maxY - height - 12
        }
        if animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
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
