import AppKit
import SwiftUI

struct OverlayHeaderView: View {
    let isWorking: Bool
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PanelDragArea()
                .overlay(alignment: .leading) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        Text("Screen Sage")
                            .font(.headline)
                        Text(isWorking ? "Reading this screen…" : "One screenshot • Local OCR")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            Text("⌥⌘Space")
                .font(.subheadline.monospaced())
                .foregroundStyle(.tertiary)
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .frame(height: OverlayLayout.compactButtonHeight)
        }
    }
}

private struct PanelDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelDragView {
        PanelDragView()
    }

    func updateNSView(_ nsView: PanelDragView, context: Context) {}
}

private final class PanelDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
