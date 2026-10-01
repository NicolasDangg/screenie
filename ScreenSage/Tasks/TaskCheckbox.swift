import SwiftUI

/// A round completion checkbox: the fill springs in, then the checkmark draws itself.
/// Modeled on shadcn's (Radix) checkbox states with an animated, stroke-drawn check.
struct TaskCheckbox: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOn: Bool
    let tint: Color
    var ringColor: Color = .secondary
    var size: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(isOn ? tint : ringColor, lineWidth: 1.5)
                Circle()
                    .fill(tint)
                    .scaleEffect(isOn ? 1 : 0.2)
                    .opacity(isOn ? 1 : 0)
                CheckmarkShape()
                    .trim(from: 0, to: isOn ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: max(1.5, size * 0.11), lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.48, height: size * 0.4)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2).delay(isOn ? 0.1 : 0), value: isOn)
            }
            .frame(width: size, height: size)
            // A generous, fully hit-testable target; the stroked ring alone has a hollow middle.
            .frame(width: max(24, size + 6), height: max(24, size + 6))
            .contentShape(.rect)
        }
        .buttonStyle(CheckboxPressStyle())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        .accessibilityLabel(isOn ? "Mark incomplete" : "Mark complete")
        .accessibilityValue(isOn ? "Completed" : "Not completed")
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct CheckboxPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.85 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Text with a strikethrough that sweeps across from the leading edge.
struct CompletableTitle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let isCompleted: Bool
    var isDimmed = false
    var fontSize: CGFloat = 13.5

    var body: some View {
        Text(title)
            .font(.system(size: fontSize))
            .foregroundStyle(isCompleted || isDimmed ? .secondary : .primary)
            .lineLimit(1)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.secondary)
                    .frame(height: 1)
                    .scaleEffect(x: isCompleted ? 1 : 0, anchor: .leading)
                    .accessibilityHidden(true)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(isCompleted ? 0.12 : 0), value: isCompleted)
            .accessibilityValue(isCompleted ? "Completed" : "")
    }
}
