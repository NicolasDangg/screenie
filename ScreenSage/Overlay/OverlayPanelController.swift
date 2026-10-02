import AppKit
import SwiftUI

enum OverlayResizeHandle {
    case left, right, topLeft, topRight, bottomLeft, bottomRight
}

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
    private var resizeStart: (frame: NSRect, mouse: NSPoint)?
    private(set) var isPresented = false

    init(model: AppModel, defaults: UserDefaults = .standard, showHistory: @escaping () -> Void = {}) {
        self.model = model
        self.defaults = defaults
        let panel = KeyablePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: OverlayLayout.collapsedWidth,
                height: OverlayLayout.collapsedHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
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
        let hostingView = NSHostingView(rootView: OverlayView(
            model: model,
            close: { [weak self] in self?.hide() },
            setExpanded: { [weak self] in self?.setExpanded($0) },
            resize: { [weak self] handle, location in self?.resize(handle, at: location) },
            endResize: { [weak self] in self?.resizeStart = nil },
            showHistory: showHistory
        ))
        // Keep everything outside the rounded glass fully transparent.
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.safeAreaRegions = []
        panel.contentView = hostingView
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

    static func origin(on visibleFrame: NSRect, panelSize: NSSize, previousOrigin: NSPoint?) -> NSPoint {
        if let previousOrigin,
           visibleFrame.contains(NSRect(origin: previousOrigin, size: panelSize)) {
            return previousOrigin
        }
        return NSPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.minY + 64
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

    /// Shows a saved conversation in the overlay so it can be continued.
    func continueConversation(_ conversation: Conversation) {
        model.resume(conversation)
        if isPresented {
            setExpanded(true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            show()
        }
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
        let pointerScreen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main
        if model.settings.followFocusedDisplay, let visibleFrame = pointerScreen?.visibleFrame {
            let previousOrigin = hasBeenPositioned ? panel.frame.origin : Self.savedOrigin(in: defaults)
            panel.setFrameOrigin(Self.origin(
                on: visibleFrame,
                panelSize: panel.frame.size,
                previousOrigin: previousOrigin
            ))
            hasBeenPositioned = true
        }
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
                if let visibleFrame = pointerScreen?.visibleFrame {
                    panel.setFrameOrigin(NSPoint(
                        x: visibleFrame.midX - panel.frame.width / 2,
                        y: visibleFrame.minY + 64
                    ))
                }
                hasBeenPositioned = true
            }
        }
        panel.alphaValue = 0
        // The panel is nonactivating: it takes key focus while the frontmost app stays active.
        panel.makeKeyAndOrderFront(nil)
        animate { self.panel.animator().alphaValue = 1 }
    }

    func hide() {
        guard isPresented else { return }
        resizeStart = nil
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
        let width = model.presentationMode == .tasks ? OverlayLayout.width
            : (expanded ? model.expandedChatSize.width : OverlayLayout.collapsedWidth)
        let height = model.presentationMode == .tasks
            ? OverlayLayout.taskHeight
            : (expanded ? model.expandedChatSize.height : OverlayLayout.collapsedHeight)
        guard panel.frame.width != width || panel.frame.height != height else { return }
        var frame = panel.frame
        let centerX = frame.midX
        frame.size.width = width
        frame.size.height = height
        frame.origin.x = centerX - width / 2
        if let visibleFrame = panel.screen?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX + 12), visibleFrame.maxX - width - 12)
            if frame.maxY > visibleFrame.maxY - 12 {
                frame.origin.y = visibleFrame.maxY - height - 12
            }
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

    func resize(_ handle: OverlayResizeHandle, at location: CGPoint) {
        guard isPresented, model.presentationMode == .chat, model.isExpanded else { return }
        // The handle moves with the panel, so measure drag positions in screen coordinates.
        let mouse = NSPoint(x: panel.frame.minX + location.x, y: panel.frame.maxY - location.y)
        if resizeStart == nil { resizeStart = (panel.frame, mouse) }
        guard let start = resizeStart, let visibleFrame = panel.screen?.visibleFrame else { return }
        let translation = CGSize(width: mouse.x - start.mouse.x, height: start.mouse.y - mouse.y)
        let frame = Self.resizedFrame(start.frame, handle: handle, translation: translation, within: visibleFrame)
        panel.setFrame(frame, display: true)
        model.expandedChatSize = frame.size
    }

    static func resizedFrame(
        _ frame: NSRect,
        handle: OverlayResizeHandle,
        translation: CGSize,
        within visibleFrame: NSRect
    ) -> NSRect {
        let inset = 12.0
        var left = frame.minX
        var right = frame.maxX
        var bottom = frame.minY
        var top = frame.maxY
        switch handle {
        case .left, .topLeft, .bottomLeft:
            left = min(max(left + translation.width, visibleFrame.minX + inset), right - OverlayLayout.minimumExpandedWidth)
        case .right, .topRight, .bottomRight:
            right = max(min(right + translation.width, visibleFrame.maxX - inset), left + OverlayLayout.minimumExpandedWidth)
        }
        switch handle {
        case .topLeft, .topRight:
            top = max(min(top - translation.height, visibleFrame.maxY - inset), bottom + OverlayLayout.minimumExpandedHeight)
        case .bottomLeft, .bottomRight:
            bottom = min(max(bottom - translation.height, visibleFrame.minY + inset), top - OverlayLayout.minimumExpandedHeight)
        case .left, .right:
            break
        }
        return NSRect(x: left, y: bottom, width: right - left, height: top - bottom)
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
