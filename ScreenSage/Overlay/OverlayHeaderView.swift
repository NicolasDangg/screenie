import SwiftUI

struct OverlayHeaderView: View {
    let isWorking: Bool
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text("Screen Sage")
                .font(.headline)
            Text(isWorking ? "Reading this screen…" : "One screenshot • Local OCR")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("⌥⌘Space")
                .font(.subheadline.monospaced())
                .foregroundStyle(.tertiary)
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
        }
    }
}

