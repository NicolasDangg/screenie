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

/// What the task views can do to an item, shared by the list and week views.
struct TaskItemActions {
    var toggleCompletion: (TaskAgendaItem) -> Void
    var updateDueDate: (UUID, Date?) -> Void
    var updateDetails: (UUID, _ title: String, _ notes: String) -> Void
    var updateReminder: (AppleReminderItem, _ title: String, _ notes: String, _ dueDate: Date?, _ hasTime: Bool) -> Void
    var delete: (ScreenieTask) -> Void
}

/// Details for screenie tasks and reminders. Clicking a reminder or event opens it in its own app,
/// so the reminder editor is reached from the context menu.
struct TaskItemDetailsPopover: ViewModifier {
    let item: TaskAgendaItem
    @Binding var isPresented: Bool
    let actions: TaskItemActions

    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented) {
            switch item.source {
            case let .task(task):
                TaskDetailsPopoverView(
                    task: task,
                    updateDueDate: { actions.updateDueDate(task.id, $0) },
                    updateDetails: { actions.updateDetails(task.id, $0, $1) }
                )
            case let .reminder(reminder):
                ReminderDetailsPopoverView(reminder: reminder) {
                    actions.updateReminder(reminder, $0, $1, $2, $3)
                }
            case .event:
                EmptyView()
            }
        }
    }
}

/// The context menu shared by list rows and week blocks.
struct TaskItemContextMenu: View {
    @Environment(\.openURL) private var openURL
    let item: TaskAgendaItem
    let showDetails: () -> Void
    let actions: TaskItemActions

    var body: some View {
        if item.kind != .event {
            Button(item.kind == .task ? "Details…" : "Edit…", systemImage: "pencil", action: showDetails)
        }
        if let url = item.appURL {
            Button("Open in \(item.appName)", systemImage: "arrow.up.forward.app") { openURL(url) }
        }
        if let task = item.task {
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(task) }
        }
    }
}

struct TaskRowView: View {
    @Environment(\.openURL) private var openURL
    let item: TaskAgendaItem
    let timeLabel: String
    var isHighlighted = false
    let actions: TaskItemActions

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
        .modifier(TaskItemDetailsPopover(item: item, isPresented: $isShowingDetails, actions: actions))
        .contextMenu {
            TaskItemContextMenu(item: item, showDetails: { isShowingDetails = true }, actions: actions)
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
                action: { actions.toggleCompletion(item) }
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
        } else if let url = item.appURL {
            Button { openURL(url) } label: {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(item.title) in \(item.appName)")
            .help("Open in \(item.appName)")
        } else {
            title
        }
    }
}
