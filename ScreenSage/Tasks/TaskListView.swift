import SwiftUI

struct TaskListView: View {
    let tasks: [ScreenieTask]
    let schedule: TaskSchedule?
    let errorMessage: String
    let isRequestingSchedule: Bool
    let toggleCompletion: (UUID) -> Void

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
                        TaskRowView(task: task) { toggleCompletion(task.id) }
                        if index < tasks.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                                .opacity(0.28)
                        }
                    }
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
                    TaskScheduleView(schedule: schedule)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }
}
