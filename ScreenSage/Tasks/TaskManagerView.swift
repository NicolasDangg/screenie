import SwiftUI

struct TaskManagerView: View {
    @Bindable var model: AppModel
    @State private var viewMode = TaskViewMode.list
    @State private var isAddingTask = false
    @State private var pendingDeletion: ScreenieTask?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Tasks")
                    .font(.headline)
                    .bold()
                Spacer()
                Button(
                    viewMode == .list ? "Show calendar" : "Show task list",
                    systemImage: viewMode == .list ? "calendar" : "list.bullet",
                    action: toggleViewMode
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                Button("Return to chat", systemImage: "sparkles", action: model.presentChat)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider().opacity(0.35)

            if viewMode == .list {
                TaskListView(
                    tasks: model.taskStore.sortedTasks,
                    schedule: model.taskSchedule,
                    errorMessage: model.taskError.isEmpty ? model.taskStore.errorMessage : model.taskError,
                    isParsingTask: model.isParsingTask,
                    isRequestingSchedule: model.isRequestingTaskSchedule,
                    isAddingScheduleToCalendar: model.isAddingTaskScheduleToCalendar,
                    didAddScheduleToCalendar: model.didAddTaskScheduleToCalendar,
                    toggleCompletion: model.taskStore.toggleCompletion,
                    requestDelete: requestDelete,
                    dismissSchedule: model.dismissTaskSchedule,
                    addScheduleToCalendar: model.addTaskScheduleToCalendar
                )
            } else {
                TaskCalendarView(
                    tasks: model.taskStore.sortedTasks,
                    errorMessage: model.taskError.isEmpty ? model.taskStore.errorMessage : model.taskError,
                    isParsingTask: model.isParsingTask,
                    isRequestingSchedule: model.isRequestingTaskSchedule,
                    toggleCompletion: model.taskStore.toggleCompletion,
                    requestDelete: requestDelete
                )
            }

            Divider().opacity(0.35)

            HStack {
                Button("Add task", systemImage: "plus", action: showAddTask)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .help("Add task")
                Spacer()
                Button("Schedule hint", systemImage: "wand.and.stars", action: showScheduleHint)
                    .buttonStyle(.plain)
                    .disabled(model.isRequestingTaskSchedule)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .frame(height: 43)
        }
        .sheet(isPresented: $isAddingTask) {
            AddTaskView { task in
                model.taskStore.add(task)
                model.taskError = ""
            }
        }
        .alert(
            "Delete task?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { task in
            Button("Delete", role: .destructive) {
                model.taskStore.delete(task.id)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { task in
            Text("If “\(task.title)” was synced, its Apple Calendar event will be removed too.")
        }
    }

    private func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    private func showAddTask() {
        isAddingTask = true
    }

    private func showScheduleHint() {
        viewMode = .list
        model.requestScheduleHint()
    }

    private func requestDelete(_ task: ScreenieTask) {
        pendingDeletion = task
    }
}
