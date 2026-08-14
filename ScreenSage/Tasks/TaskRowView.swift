import SwiftUI

struct TaskRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let task: ScreenieTask
    var isAgenda = false
    let toggleCompletion: () -> Void
    let updateDueDate: (Date?) -> Void
    var delete: (() -> Void)?

    @State private var isHovered = false
    @State private var isShowingDetails = false

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

            Button {
                isShowingDetails = true
            } label: {
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
                        Text(
                            dueDate,
                            format: isAgenda
                                ? .dateTime.hour().minute()
                                : .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
                        )
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
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show details for \(task.title)")
            .popover(isPresented: $isShowingDetails) {
                TaskDetailsPopoverView(task: task, updateDueDate: updateDueDate)
            }

            if let delete {
                Button("Delete task", systemImage: "trash", action: delete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .opacity(isHovered ? 1 : 0.35)
                    .help("Delete task")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isAgenda ? 6 : 8)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .contextMenu {
            if let delete {
                Button("Delete", systemImage: "trash", role: .destructive, action: delete)
            }
        }
    }
}
