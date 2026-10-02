import SwiftUI

struct TaskDetailsPopoverView: View {
    let task: ScreenieTask
    let updateDueDate: (Date?) -> Void
    let updateDetails: (_ title: String, _ notes: String) -> Void

    @State private var title: String
    @State private var notes: String

    init(
        task: ScreenieTask,
        updateDueDate: @escaping (Date?) -> Void,
        updateDetails: @escaping (_ title: String, _ notes: String) -> Void
    ) {
        self.task = task
        self.updateDueDate = updateDueDate
        self.updateDetails = updateDetails
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TaskTitleNotesFields(title: $title, notes: $notes, commit: commit)

            Divider()

            Toggle("Deadline", isOn: hasDueDate)
            if task.dueDate != nil {
                DatePicker(
                    "Due",
                    selection: dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Divider()

            LabeledContent("Status", value: task.isCompleted ? "Completed" : "Incomplete")
            LabeledContent("Created") {
                Text(task.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
            }
            if let completedAt = task.completedAt {
                LabeledContent("Completed") {
                    Text(completedAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onDisappear(perform: commit)
    }

    private func commit() {
        updateDetails(title, notes)
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { task.dueDate != nil },
            set: { updateDueDate($0 ? task.dueDate ?? .now : nil) }
        )
    }

    private var dueDate: Binding<Date> {
        Binding(
            get: { task.dueDate ?? .now },
            set: { updateDueDate($0) }
        )
    }
}

/// Edits an Apple reminder's title, notes, and due date. Changes are saved when the popover closes.
struct ReminderDetailsPopoverView: View {
    @Environment(\.openURL) private var openURL
    let reminder: AppleReminderItem
    let save: (_ title: String, _ notes: String, _ dueDate: Date?, _ hasTime: Bool) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var hasTime: Bool
    @State private var dueDate: Date

    init(
        reminder: AppleReminderItem,
        save: @escaping (_ title: String, _ notes: String, _ dueDate: Date?, _ hasTime: Bool) -> Void
    ) {
        self.reminder = reminder
        self.save = save
        _title = State(initialValue: reminder.title)
        _notes = State(initialValue: reminder.notes)
        _hasDueDate = State(initialValue: reminder.dueDate != nil)
        _hasTime = State(initialValue: reminder.hasTime)
        _dueDate = State(initialValue: reminder.dueDate ?? Calendar.current.startOfDay(for: .now))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TaskTitleNotesFields(title: $title, notes: $notes, commit: {})

            Divider()

            Toggle("Due date", isOn: $hasDueDate)
            if hasDueDate {
                Toggle("Time", isOn: $hasTime)
                DatePicker(
                    "Due",
                    selection: $dueDate,
                    displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date]
                )
            }

            Divider()

            HStack {
                LabeledContent("List", value: reminder.list.title)
                Spacer()
                if let url = reminder.appURL {
                    Button("Open in Reminders") { openURL(url) }
                        .controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onDisappear(perform: commit)
    }

    private func commit() {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDate = hasDueDate ? dueDate : nil
        let unchanged = title == reminder.title
            && notes == reminder.notes
            && newDate == reminder.dueDate
            && (newDate == nil || hasTime == reminder.hasTime)
        guard !title.isEmpty, !unchanged else { return }
        save(title, notes, newDate, hasTime)
    }
}

private struct TaskTitleNotesFields: View {
    @Binding var title: String
    @Binding var notes: String
    let commit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.headline)
                .onSubmit(commit)
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1...4)
                .onSubmit(commit)
        }
    }
}
