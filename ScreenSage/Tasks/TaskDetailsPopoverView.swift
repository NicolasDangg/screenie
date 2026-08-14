import SwiftUI

struct TaskDetailsPopoverView: View {
    let task: ScreenieTask
    let updateDueDate: (Date?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(task.title)
                .font(.headline)
                .textSelection(.enabled)

            if !task.notes.isEmpty {
                LabeledContent("Notes") {
                    Text(task.notes)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }

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
