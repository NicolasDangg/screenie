import AppKit
import SwiftUI

struct LiveBackdropView: NSViewRepresentable {
    static func makeVisualEffectView() -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        return view
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        Self.makeVisualEffectView()
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
