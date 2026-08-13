import SwiftUI

struct TaskRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let task: ScreenieTask
    let toggleCompletion: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(
                task.isCompleted ? "Mark incomplete" : "Mark complete",
                systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle",
                action: toggleCompletion
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
            .font(.body)
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(.secondary)
                            .frame(height: 1)
                            .scaleEffect(x: task.isCompleted ? 1 : 0, anchor: .leading)
                            .opacity(task.isCompleted ? 1 : 0)
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: task.isCompleted)

                if let dueDate = task.dueDate {
                    Text(dueDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No due date")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}
