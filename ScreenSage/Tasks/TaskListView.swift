import SwiftUI

struct TaskListView: View {
    let tasks: [ScreenieTask]
    let schedule: TaskSchedule?
    let errorMessage: String
    let isParsingTask: Bool
    let isRequestingSchedule: Bool
    let isAddingScheduleToCalendar: Bool
    let didAddScheduleToCalendar: Bool
    let toggleCompletion: (UUID) -> Void
    let updateDueDate: (UUID, Date?) -> Void
    let requestDelete: (ScreenieTask) -> Void
    let dismissSchedule: () -> Void
    let addScheduleToCalendar: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks",
                        systemImage: "checklist",
                        description: Text("Add one below or type /task followed by a task.")
                    )
                    .frame(minHeight: 210)
                } else {
                    ForEach(tasks.enumerated(), id: \.element.id) { index, task in
                        TaskRowView(
                            task: task,
                            toggleCompletion: { toggleCompletion(task.id) },
                            updateDueDate: { updateDueDate(task.id, $0) },
                            delete: { requestDelete(task) }
                        )
                        if index < tasks.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                                .opacity(0.28)
                        }
                    }
                }

                if isParsingTask {
                    ProgressView("Understanding task…")
                        .controlSize(.small)
                        .padding()
                }

                if isRequestingSchedule {
                    ProgressView("Finding study time…")
                        .controlSize(.small)
                        .padding()
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }

                if let schedule {
                    Divider().opacity(0.35)
                    TaskScheduleView(
                        schedule: schedule,
                        isAddingToCalendar: isAddingScheduleToCalendar,
                        wasAddedToCalendar: didAddScheduleToCalendar,
                        dismiss: dismissSchedule,
                        addToCalendar: addScheduleToCalendar
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }
}
