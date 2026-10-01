import SwiftUI

struct TaskManagerView: View {
    @Bindable var model: AppModel
    @State private var viewMode = TaskViewMode.list
    @State private var filter = TaskAgendaFilter.all
    /// Just-completed rows that stay in place for a moment before moving to Completed.
    @State private var lingering: Set<String> = []
    @State private var selectedDay = Date.now
    @State private var isAddingTask = false
    @State private var pendingDeletion: ScreenieTask?
    @FocusState private var entryIsFocused: Bool

    private var sources: AppleTaskSources { model.taskSources }

    private var items: [TaskAgendaItem] {
        TaskAgenda.items(tasks: model.taskStore.tasks, reminders: sources.reminders, events: sources.events)
    }

    private var errorMessage: String {
        [model.taskError, model.taskStore.errorMessage, sources.errorMessage].first { !$0.isEmpty } ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)

            if viewMode == .list {
                TaskListView(
                    sections: TaskAgenda.listSections(
                        items,
                        filter: filter,
                        lingering: lingering,
                        now: .now,
                        calendar: .autoupdatingCurrent
                    ),
                    filter: $filter,
                    schedule: model.taskSchedule,
                    errorMessage: errorMessage,
                    isParsingTask: model.isParsingTask,
                    isRequestingSchedule: model.isRequestingTaskSchedule,
                    isAddingScheduleToCalendar: model.isAddingTaskScheduleToCalendar,
                    didAddScheduleToCalendar: model.didAddTaskScheduleToCalendar,
                    needsConnection: sources.needsConnection,
                    connect: { Task { await sources.requestAccess() } },
                    toggleCompletion: toggleInList,
                    updateDueDate: model.taskStore.updateDueDate,
                    requestDelete: requestDelete,
                    dismissSchedule: model.dismissTaskSchedule,
                    addScheduleToCalendar: model.addTaskScheduleToCalendar
                )
            } else {
                TaskCalendarView(
                    items: items,
                    selectedDay: $selectedDay,
                    errorMessage: errorMessage,
                    isParsingTask: model.isParsingTask,
                    toggleCompletion: model.toggleCompletion(of:),
                    updateDueDate: model.taskStore.updateDueDate,
                    requestDelete: requestDelete
                )
            }

            Divider().opacity(0.35)
            composer
        }
        .task {
            entryIsFocused = true
            await sources.refresh()
        }
        .onChange(of: model.presentationID) {
            entryIsFocused = true
            sources.scheduleRefresh()
        }
        .onChange(of: selectedDay, initial: true) { _, day in
            let week = TaskAgenda.weekDates(containing: day, calendar: .autoupdatingCurrent)
            guard let start = week.first, let last = week.last,
                  let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: last) else { return }
            sources.showEvents(in: DateInterval(start: start, end: end))
        }
        .sheet(isPresented: $isAddingTask) {
            AddTaskView { task in
                Task {
                    do {
                        try await model.add(task)
                        model.taskError = ""
                    } catch {
                        model.taskError = error.localizedDescription
                    }
                }
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

    private var header: some View {
        HStack(spacing: 10) {
            Text("Tasks")
                .font(.system(size: 13, weight: .bold))
            subtitle
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("View", selection: $viewMode) {
                Text("List").tag(TaskViewMode.list)
                Text("Week").tag(TaskViewMode.calendar)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            Button("Return to chat", systemImage: "sparkles", action: model.presentChat)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
                .help("Return to chat")
        }
        .padding(.leading, OverlayLayout.contentInset)
        .padding(.trailing, 12)
        .frame(height: 44)
    }

    @ViewBuilder private var subtitle: some View {
        if viewMode == .calendar {
            let week = TaskAgenda.weekDates(containing: selectedDay, calendar: .autoupdatingCurrent)
            if let first = week.first, let last = week.last {
                Text((first..<last).formatted(.interval.month(.abbreviated).day()))
            }
        } else if sources.hasConnectedSource, let lastRefreshed = sources.lastRefreshed {
            Button { sources.scheduleRefresh() } label: {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Label {
                        Text(lastRefreshed > context.date.addingTimeInterval(-60)
                             ? "Synced just now"
                             : "Synced \(lastRefreshed.formatted(.relative(presentation: .named)))")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Refresh Reminders and Calendar")
        } else {
            let open = model.taskStore.activeTasks.count
            Text("\(open) open")
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Button("Add task with details", systemImage: "plus") { isAddingTask = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add task with details")

            TextField("Call mom Friday at 6…", text: $model.taskEntry)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($entryIsFocused)
                .onSubmit(submitEntry)
                .disabled(model.isParsingTask)
                .accessibilityLabel("New task")

            if model.isParsingTask {
                ProgressView().controlSize(.small)
            }

            destinationMenu

            Button("Suggest a schedule", systemImage: "wand.and.stars", action: showScheduleHint)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.06), in: .rect(cornerRadius: 8))
                .contentShape(.rect)
                .disabled(model.isRequestingTaskSchedule)
                .help("Suggest a schedule")
        }
        .padding(.leading, OverlayLayout.contentInset)
        .padding(.trailing, 12)
        .frame(height: 52)
    }

    private var destinationMenu: some View {
        @Bindable var sources = sources
        let list = sources.newTaskReminderList
        return Menu {
            Picker("Save new tasks to", selection: $sources.newTaskReminderListID) {
                Text("screenie").tag(String?.none)
                if !sources.reminderLists.isEmpty {
                    Section("Reminders") {
                        ForEach(sources.reminderLists) { list in
                            Text(list.title).tag(Optional(list.id))
                        }
                    }
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                TaskSourceMark(
                    kind: list == nil ? .task : .reminder,
                    tint: list?.color.color ?? .accentColor
                )
                Text(list?.title ?? "screenie")
            }
            .font(.system(size: 11.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Where new tasks are saved")
    }

    private func submitEntry() {
        model.addTask(entry: model.taskEntry)
    }

    private func showScheduleHint() {
        viewMode = .list
        model.requestScheduleHint()
    }

    private func toggleInList(_ item: TaskAgendaItem) {
        if !item.isCompleted {
            lingering.insert(item.id)
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                lingering.remove(item.id)
            }
        }
        model.toggleCompletion(of: item)
    }

    private func requestDelete(_ task: ScreenieTask) {
        pendingDeletion = task
    }
}
