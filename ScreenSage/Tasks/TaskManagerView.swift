import SwiftUI

struct TaskManagerView: View {
    @Bindable var model: AppModel
    @State private var viewMode = TaskViewMode.list
    @State private var isAddingTask = false
    @State private var selectedDate = Date.now

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
                    toggleCompletion: model.taskStore.toggleCompletion
                )
            } else {
                TaskCalendarView(
                    selectedDate: $selectedDate,
                    tasks: model.taskStore.sortedTasks,
                    toggleCompletion: model.taskStore.toggleCompletion
                )
            }

            Divider().opacity(0.35)

            HStack {
                Button("Add task", systemImage: "plus", action: showAddTask)
                    .buttonStyle(.plain)
                Spacer()
                Button("Schedule hint", systemImage: "wand.and.stars", action: model.requestScheduleHint)
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
    }

    private func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    private func showAddTask() {
        isAddingTask = true
    }
}
