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
    private var syncTasks: [UUID: Task<Void, Never>] = [:]

    init(
        fileURL: URL? = TaskStore.defaultFileURL,
        calendarDelete: (@MainActor (ScreenieTask) async throws -> Void)? = { task in
            try await TaskCalendarSync.shared.delete(task)
        },
        calendarSync: (@MainActor (ScreenieTask) async throws -> String?)? = { task in
            return try await TaskCalendarSync.shared.upsert(task)
        }
    ) {
        self.fileURL = fileURL
        self.calendarDelete = calendarDelete
        self.calendarSync = calendarSync
        load()
        tasks.filter { $0.dueDate != nil }.forEach { synchronize($0.id) }
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

    func add(_ task: ScreenieTask) {
        tasks.append(task)
        guard save() else {
            tasks.removeAll { $0.id == task.id }
            return
        }
        synchronize(task.id)
    }

    func toggleCompletion(of id: UUID) {
        toggleCompletion(of: id, at: .now)
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

    private func synchronize(_ id: UUID) {
        guard let calendarSync,
              let task = tasks.first(where: { $0.id == id }),
              task.dueDate != nil else { return }

        let previousSync = syncTasks[id]
        syncTasks[id] = Task { [weak self] in
            await previousSync?.value
            guard let self else { return }
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
