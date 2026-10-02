import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    private(set) var tasks: [ScreenieTask] = []
    private(set) var lastError = ""
    private var calendarErrors: [UUID: String] = [:]
    private let fileURL: URL?
    private let calendarDelete: (@MainActor (ScreenieTask) async throws -> Void)?
    private let calendarSync: (@MainActor (ScreenieTask) async throws -> String?)?
    private let calendarLookup: (@MainActor (ScreenieTask) async -> LinkedCalendarEventLookup)?
    private let syncsToCalendar: @MainActor () -> Bool
    private var syncTasks: [UUID: Task<Void, Never>] = [:]
    private var syncTokens: [UUID: UUID] = [:]
    private var reconcileTask: Task<Void, Never>?
    private var changeObserver: NSObjectProtocol?

    init(
        fileURL: URL? = TaskStore.defaultFileURL,
        calendarDelete: (@MainActor (ScreenieTask) async throws -> Void)? = { task in
            try await TaskCalendarSync.shared.delete(task)
        },
        calendarSync: (@MainActor (ScreenieTask) async throws -> String?)? = { task in
            return try await TaskCalendarSync.shared.upsert(task)
        },
        calendarLookup: (@MainActor (ScreenieTask) async -> LinkedCalendarEventLookup)? = { task in
            await TaskCalendarSync.shared.linkedEvent(for: task)
        },
        syncsToCalendar: @escaping @MainActor () -> Bool = { AppleTaskSources.syncsTasksToCalendar() }
    ) {
        self.fileURL = fileURL
        self.calendarDelete = calendarDelete
        self.calendarSync = calendarSync
        self.calendarLookup = calendarSync == nil ? nil : calendarLookup
        self.syncsToCalendar = syncsToCalendar
        load()
        // Launch only reads Calendar: pushing every task here would overwrite edits made in Calendar
        // and recreate copies the user deleted. Pushes happen when the task itself changes.
        guard self.calendarLookup != nil else { return }
        scheduleCalendarReconcile()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCalendarReconcile() }
        }
    }

    var sortedTasks: [ScreenieTask] {
        tasks.sorted {
            switch ($0.dueDate, $1.dueDate) {
            case let (lhs?, rhs?):
                lhs == rhs ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : lhs < rhs
            case (.some, nil):
                true
            case (nil, .some):
                false
            case (nil, nil):
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }

    var activeTasks: [ScreenieTask] {
        sortedTasks.filter { !$0.isCompleted }
    }

    var completedTasks: [ScreenieTask] {
        tasks.filter(\.isCompleted).sorted {
            ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
        }
    }

    var calendarError: String {
        calendarErrors.values.first ?? ""
    }

    var errorMessage: String {
        lastError.isEmpty ? calendarError : lastError
    }

    func calendarError(for id: UUID) -> String {
        calendarErrors[id] ?? ""
    }

    @discardableResult
    func add(_ task: ScreenieTask) -> Bool {
        tasks.append(task)
        guard save() else {
            tasks.removeAll { $0.id == task.id }
            return false
        }
        synchronize(task.id)
        return true
    }

    func updateDetails(of id: UUID, title: String, notes: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let previousTask = tasks[index]
        guard previousTask.title != title || previousTask.notes != notes else { return }
        tasks[index].title = title
        tasks[index].notes = notes
        guard save() else {
            tasks[index] = previousTask
            return
        }
        synchronize(id)
    }

    /// Pulls edits made to linked Calendar copies into their tasks, and unlinks copies deleted in Calendar
    /// (the task stays). Tasks changed locally while this runs are left alone; their own push wins.
    func reconcileWithCalendar() async {
        guard let calendarLookup, syncsToCalendar() else { return }
        for pending in Array(syncTasks.values) { await pending.value }
        let linked = tasks.filter { $0.calendarEventIdentifier != nil && $0.dueDate != nil }
        var changed = false
        for snapshot in linked {
            let lookup = await calendarLookup(snapshot)
            guard !Task.isCancelled else { return }
            guard let index = tasks.firstIndex(where: { $0.id == snapshot.id }),
                  tasks[index] == snapshot,
                  syncTasks[snapshot.id] == nil else { continue }
            switch lookup {
            case let .found(event):
                let updated = TaskCalendarEvent.applying(event, to: snapshot)
                if updated != snapshot {
                    tasks[index] = updated
                    changed = true
                }
            case .missing:
                tasks[index].calendarEventIdentifier = nil
                changed = true
            case .unknown:
                break
            }
        }
        if changed { save() }
    }

    private func scheduleCalendarReconcile() {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            // EventKit posts several change notifications per edit; settle before reading.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.reconcileWithCalendar()
        }
    }

    func toggleCompletion(of id: UUID) {
        toggleCompletion(of: id, at: .now)
    }

    func updateDueDate(of id: UUID, to dueDate: Date?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let previousTask = tasks[index]
        guard previousTask.dueDate != dueDate else { return }

        tasks[index].dueDate = dueDate
        if dueDate == nil {
            tasks[index].calendarEventIdentifier = nil
        }
        guard save() else {
            tasks[index] = previousTask
            return
        }

        if dueDate == nil {
            removeCalendarEvent(for: previousTask)
        } else {
            synchronize(id)
        }
    }

    func toggleCompletion(of id: UUID, at date: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let previousTask = tasks[index]
        tasks[index].isCompleted.toggle()
        tasks[index].completedAt = tasks[index].isCompleted ? date : nil
        guard save() else {
            tasks[index] = previousTask
            return
        }
        synchronize(id)
    }

    func delete(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks.remove(at: index)
        guard save() else {
            tasks.insert(task, at: index)
            return
        }

        calendarErrors[id] = nil
        let previousSync = syncTasks[id]
        previousSync?.cancel()
        guard let calendarDelete else {
            syncTasks[id] = nil
            return
        }
        syncTasks[id] = Task { [weak self] in
            await previousSync?.value
            guard let self else { return }
            do {
                try await calendarDelete(task)
            } catch {
                lastError = "Task deleted, but its Apple Calendar event could not be removed: \(error.localizedDescription)"
            }
            syncTasks[id] = nil
        }
    }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            tasks = try JSONDecoder().decode([ScreenieTask].self, from: Data(contentsOf: fileURL))
        } catch {
            lastError = "Could not load tasks: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func save() -> Bool {
        guard let fileURL else { return true }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(tasks).write(to: fileURL, options: .atomic)
            lastError = ""
            return true
        } catch {
            lastError = "Could not save tasks: \(error.localizedDescription)"
            return false
        }
    }

    private func removeCalendarEvent(for task: ScreenieTask) {
        let id = task.id
        calendarErrors[id] = nil
        let previousSync = syncTasks[id]
        previousSync?.cancel()
        guard let calendarDelete else {
            syncTasks[id] = nil
            return
        }

        syncTasks[id] = Task { [weak self] in
            await previousSync?.value
            guard let self else { return }
            do {
                try await calendarDelete(task)
                calendarErrors[id] = nil
            } catch {
                calendarErrors[id] = "Could not remove Apple Calendar event: \(error.localizedDescription)"
            }
            syncTasks[id] = nil
        }
    }

    private func synchronize(_ id: UUID) {
        guard let calendarSync,
              let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].dueDate != nil else { return }
        guard syncsToCalendar() else {
            // The Calendar copy stops tracking this task, so drop the link rather than later
            // pulling the stale copy back over the newer local edit.
            if tasks[index].calendarEventIdentifier != nil {
                tasks[index].calendarEventIdentifier = nil
                save()
            }
            return
        }

        let previousSync = syncTasks[id]
        let token = UUID()
        syncTokens[id] = token
        syncTasks[id] = Task { [weak self] in
            await previousSync?.value
            guard let self else { return }
            defer {
                if syncTokens[id] == token {
                    syncTasks[id] = nil
                    syncTokens[id] = nil
                }
            }
            do {
                guard let task = tasks.first(where: { $0.id == id }) else { return }
                let eventIdentifier = try await calendarSync(task)
                try Task.checkCancellation()
                if let index = tasks.firstIndex(where: { $0.id == id }),
                   tasks[index].calendarEventIdentifier != eventIdentifier {
                    let previousIdentifier = tasks[index].calendarEventIdentifier
                    tasks[index].calendarEventIdentifier = eventIdentifier
                    guard save() else {
                        tasks[index].calendarEventIdentifier = previousIdentifier
                        calendarErrors[id] = "Apple Calendar synced, but its link could not be saved."
                        return
                    }
                }
                calendarErrors[id] = nil
            } catch is CancellationError {
                return
            } catch {
                calendarErrors[id] = "Could not sync Apple Calendar: \(error.localizedDescription)"
            }
        }
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "ScreenSage/tasks.json")
    }
}
