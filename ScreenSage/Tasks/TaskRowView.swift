import SwiftUI

extension SourceColor {
    var color: Color { Color(red: red, green: green, blue: blue) }
}

extension TaskAgendaItem {
    var tint: Color { color?.color ?? .accentColor }
}

/// The little shape that tells sources apart: filled dot for screenie, ring for Reminders, square for Calendar.
struct TaskSourceMark: View {
    let kind: TaskAgendaKind
    let tint: Color
    var size = 7.0

    var body: some View {
        switch kind {
        case .task:
            Circle().fill(tint).frame(width: size, height: size)
        case .reminder:
            Circle().strokeBorder(tint, lineWidth: 1.5).frame(width: size, height: size)
        case .event:
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: size, height: size)
        }
    }
}

struct TaskRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: TaskAgendaItem
    let timeLabel: String
    var isHighlighted = false
    let toggleCompletion: () -> Void
    let updateDueDate: (UUID, Date?) -> Void
    let delete: (ScreenieTask) -> Void

    @State private var isHovered = false
    @State private var isShowingDetails = false

    var body: some View {
        HStack(spacing: 10) {
            leadingControl
                .frame(width: 18, height: 18)

            titleView
                .frame(maxWidth: .infinity, alignment: .leading)

            if !timeLabel.isEmpty {
                Text(timeLabel)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 5) {
                TaskSourceMark(kind: item.kind, tint: item.tint)
                Text(item.sourceName)
                    .lineLimit(1)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .frame(width: 92, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isHighlighted || isHovered {
                RoundedRectangle(cornerRadius: 9).fill(.primary.opacity(isHovered ? 0.07 : 0.05))
            }
        }
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .contextMenu {
            if let task = item.task {
                Button("Delete", systemImage: "trash", role: .destructive) { delete(task) }
            }
        }
    }

    @ViewBuilder private var leadingControl: some View {
        if item.kind == .event {
            Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundStyle(item.tint)
                .accessibilityHidden(true)
        } else {
            Button(action: toggleCompletion) {
                if item.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .strokeBorder(item.kind == .reminder ? item.tint : Color.secondary, lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "Mark incomplete" : "Mark complete")
        }
    }

    @ViewBuilder private var titleView: some View {
        let title = Text(item.title)
            .font(.system(size: 13.5))
            .foregroundStyle(item.isCompleted || item.kind == .event ? .secondary : .primary)
            .strikethrough(item.isCompleted)
            .lineLimit(1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: item.isCompleted)

        if let task = item.task {
            Button { isShowingDetails = true } label: {
                VStack(alignment: .leading, spacing: 1) {
                    title
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.system(size: 12))
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
                TaskDetailsPopoverView(task: task) { updateDueDate(task.id, $0) }
            }
        } else {
            title
        }
    }
}
