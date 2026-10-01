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
    let item: TaskAgendaItem
    let timeLabel: String
    var isHighlighted = false
    let toggleCompletion: () -> Void
    let updateDueDate: (UUID, Date?) -> Void
    let delete: (ScreenieTask) -> Void

    @State private var isHovered = false
    @State private var isShowingDetails = false

    var body: some View {
        HStack(spacing: 7) {
            leadingControl
                .frame(width: 24, height: 24)

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
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
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
            TaskCheckbox(
                isOn: item.isCompleted,
                tint: item.tint,
                ringColor: item.kind == .reminder ? item.tint : .secondary,
                action: toggleCompletion
            )
        }
    }

    @ViewBuilder private var titleView: some View {
        let title = CompletableTitle(
            title: item.title,
            isCompleted: item.isCompleted,
            isDimmed: item.kind == .event
        )

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
