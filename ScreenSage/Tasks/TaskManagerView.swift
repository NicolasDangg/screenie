import SwiftUI

struct TaskManagerView: View {
    @Bindable var model: AppModel
    static let initialViewMode = TaskViewMode.list
    @State private var viewMode = TaskManagerView.initialViewMode
    @State private var filter = TaskAgendaFilter.all
    /// Just-completed rows that stay in place for a moment before moving to Completed.
    @State private var lingering: Set<String> = []
    @State private var selectedDay = Date.now
    @State private var isAddingTask = false
    @State private var pendingDeletion: ScreenieTask?
    @FocusState private var entryIsFocused: Bool
    @Environment(\.openURL) private var openURL

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
                    actions: actions(toggleCompletion: toggleInList),
                    dismissSchedule: model.dismissTaskSchedule,
                    addScheduleToCalendar: model.addTaskScheduleToCalendar
                )
            } else {
                TaskCalendarView(
                    items: items,
                    selectedDay: $selectedDay,
                    errorMessage: errorMessage,
                    isParsingTask: model.isParsingTask,
                    actions: actions(toggleCompletion: model.toggleCompletion(of:))
                )
            }

            if let notice = model.taskSaveNotice {
                saveNoticeView(notice)
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
            AddTaskView(destinationName: destinationTitle) { task in
                showItems(savedTo: sources.newItemDestination)
                try await model.add(task)
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

            TextField(entryPlaceholder, text: $model.taskEntry)
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
        let destination = sources.newItemDestination
        let target = sources.destinationTarget
        return Menu {
            Picker("Save new items to", selection: $sources.newItemDestination) {
                Text("screenie").tag(NewItemDestination.screenie)
                if !sources.reminderLists.isEmpty {
                    Section("Reminders") {
                        ForEach(sources.reminderLists) { list in
                            destinationLabel(list.title, for: .reminders(list.id))
                        }
                    }
                }
                if !sources.writableEventCalendars.isEmpty {
                    Section("Calendar event") {
                        ForEach(sources.writableEventCalendars) { calendar in
                            destinationLabel(calendar.title, for: .calendar(calendar.id))
                        }
                    }
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                if sources.destinationIsUnavailable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    TaskSourceMark(kind: destination.markKind, tint: target?.color.color ?? .accentColor)
                }
                Text(destinationTitle)
            }
            .font(.system(size: 11.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(.secondary)
        // Locked while parsing: the save goes where it was sent.
        .disabled(model.isParsingTask)
        .help(sources.destinationIsUnavailable
              ? "The chosen list or calendar isn’t available. Choose another."
              : "Where new items are saved")
    }

    /// Hidden lists stay choosable, but say so: their items won't show up here.
    private func destinationLabel(_ title: String, for destination: NewItemDestination) -> some View {
        Text(sources.shows(destination) ? title : "\(title) (hidden here)").tag(destination)
    }

    private var destinationTitle: String {
        if sources.destinationIsUnavailable { return "Unavailable" }
        return sources.destinationTarget?.title ?? "screenie"
    }

    private var entryPlaceholder: String {
        if sources.newItemDestination.isEvent { return "Lunch with Sam tomorrow 12–1…" }
        return "Call mom Friday at 6…"
    }

    private func submitEntry() {
        showItems(savedTo: sources.newItemDestination)
        model.addTask(entry: model.taskEntry)
    }

    /// Clears a filter that would hide what's about to be saved.
    private func showItems(savedTo destination: NewItemDestination) {
        if !filter.includes(destination.markKind) { filter = .all }
    }

    private func saveNoticeView(_ notice: TaskSaveNotice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(notice.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let url = notice.url {
                Button("Open in \(notice.appName)") { openURL(url) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tint)
            }
            Button("Dismiss", systemImage: "xmark", action: model.clearTaskSaveNotice)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, OverlayLayout.contentInset)
        .padding(.vertical, 8)
        .transition(.opacity)
    }

    private func actions(toggleCompletion: @escaping (TaskAgendaItem) -> Void) -> TaskItemActions {
        TaskItemActions(
            toggleCompletion: toggleCompletion,
            updateDueDate: model.taskStore.updateDueDate,
            updateDetails: model.taskStore.updateDetails,
            updateReminder: model.updateReminder,
            delete: requestDelete
        )
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

extension NewItemDestination {
    var markKind: TaskAgendaKind {
        switch self {
        case .screenie: .task
        case .reminders: .reminder
        case .calendar: .event
        }
    }
}
