import SwiftUI

struct TaskHistoryView: View {
    @Bindable var store: TaskStore
    @State private var selection: ScreenieTask.ID?

    private var selectedTask: ScreenieTask? {
        store.tasks.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Active") {
                    ForEach(store.activeTasks) { task in
                        Label(task.title, systemImage: "circle")
                            .lineLimit(1)
                            .tag(task.id)
                    }
                }

                Section("Completed") {
                    ForEach(store.completedTasks) { task in
                        Label(task.title, systemImage: "checkmark.circle.fill")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .tag(task.id)
                    }
                }
            }
            .navigationTitle("Tasks")
        } detail: {
            if let task = selectedTask {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(task.title)
                            .font(.title2)
                            .bold()
                            .textSelection(.enabled)

                        Label(
                            task.isCompleted ? "Completed" : "Active",
                            systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                        Divider()

                        LabeledContent("Due") {
                            if let dueDate = task.dueDate {
                                Text(dueDate, format: .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                            } else {
                                Text("No due date")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Created") {
                            Text(task.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        }

                        if let completedAt = task.completedAt {
                            LabeledContent("Completed") {
                                Text(completedAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            }
                        }

                        if !task.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .foregroundStyle(.secondary)
                                Text(task.notes)
                                    .textSelection(.enabled)
                            }
                        }

                        Button(
                            task.isCompleted ? "Restore Task" : "Mark Complete",
                            systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark",
                            action: toggleSelectedTask
                        )
                        .buttonStyle(.borderedProminent)

                        if !store.lastError.isEmpty {
                            Text(store.lastError)
                                .foregroundStyle(.red)
                        }
                        if !store.calendarError(for: task.id).isEmpty {
                            Text(store.calendarError(for: task.id))
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .navigationTitle(task.title)
            } else {
                ContentUnavailableView(
                    store.tasks.isEmpty ? "No Saved Tasks" : "Select a Task",
                    systemImage: "checklist",
                    description: Text(
                        store.lastError.isEmpty
                            ? "Completed tasks remain here so you can restore them."
                            : store.lastError
                    )
                )
            }
        }
        .onAppear(perform: ensureSelection)
        .onChange(of: store.tasks) { ensureSelection() }
    }

    private func ensureSelection() {
        guard selectedTask == nil else { return }
        selection = store.activeTasks.first?.id ?? store.completedTasks.first?.id
    }

    private func toggleSelectedTask() {
        guard let selection else { return }
        store.toggleCompletion(of: selection)
    }
}
