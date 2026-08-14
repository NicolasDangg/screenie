# Task Details Popover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make list and calendar task rows open an anchored details popover where the deadline can be added, changed, or removed.

**Architecture:** Keep popover presentation local to each `TaskRowView` so SwiftUI anchors it to the clicked row. Route deadline edits through one transactional `TaskStore` method that persists locally, reuses the existing Calendar upsert path for dated tasks, and deletes the prior Calendar event when a deadline is removed.

**Tech Stack:** Swift 6, SwiftUI, Observation, EventKit, XCTest.

---

### Task 1: Persist and synchronize deadline edits

**Files:**
- Modify: `ScreenSageTests/ScreenSageTests.swift:434`
- Modify: `ScreenSage/Tasks/TaskStore.swift:77`

- [ ] **Step 1: Write the failing store test**

Add one async test after the existing task-deletion test. It proves that a changed deadline is persisted and synchronized, then proves that clearing it persists `nil`, clears the Calendar identifier, and deletes the event using the last dated task.

```swift
@MainActor
func testTaskStoreChangesAndRemovesDeadline() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appending(path: "tasks.json")
    let originalDate = date(2026, 8, 18, 10)
    let changedDate = date(2026, 8, 20, 14)
    let task = ScreenieTask(title: "Physics", dueDate: originalDate)
    var synchronizedTasks: [ScreenieTask] = []
    var deletedTask: ScreenieTask?
    let store = TaskStore(
        fileURL: fileURL,
        calendarDelete: { deletedTask = $0 },
        calendarSync: { synchronizedTask in
            synchronizedTasks.append(synchronizedTask)
            return "event-123"
        }
    )

    store.add(task)
    await waitUntil { store.tasks.first?.calendarEventIdentifier == "event-123" }

    store.updateDueDate(of: task.id, to: changedDate)
    await waitUntil { synchronizedTasks.last?.dueDate == changedDate }
    XCTAssertEqual(store.tasks.first?.dueDate, changedDate)
    XCTAssertEqual(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first?.dueDate, changedDate)

    store.updateDueDate(of: task.id, to: nil)
    await waitUntil { deletedTask != nil }

    XCTAssertEqual(deletedTask?.dueDate, changedDate)
    XCTAssertEqual(deletedTask?.calendarEventIdentifier, "event-123")
    XCTAssertNil(store.tasks.first?.dueDate)
    XCTAssertNil(store.tasks.first?.calendarEventIdentifier)
    let persisted = try XCTUnwrap(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first)
    XCTAssertNil(persisted.dueDate)
    XCTAssertNil(persisted.calendarEventIdentifier)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testTaskStoreChangesAndRemovesDeadline
```

Expected: compilation fails because `TaskStore` has no `updateDueDate(of:to:)` method.

- [ ] **Step 3: Add the minimal transactional store method**

Add this public method beside `toggleCompletion`:

```swift
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
```

Add this private helper before `synchronize(_:)`:

```swift
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
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2 again. Expected: `** TEST SUCCEEDED **` with the focused test passing.

- [ ] **Step 5: Commit the store behavior**

```bash
git add ScreenSage/Tasks/TaskStore.swift ScreenSageTests/ScreenSageTests.swift
git commit -m "feat: support task deadline edits"
```

### Task 2: Add the anchored task-details popover

**Files:**
- Create: `ScreenSage/Tasks/TaskDetailsPopoverView.swift`
- Modify: `ScreenSage/Tasks/TaskRowView.swift:3`
- Modify: `ScreenSage/Tasks/TaskListView.swift:3`
- Modify: `ScreenSage/Tasks/TaskCalendarView.swift:3`
- Modify: `ScreenSage/Tasks/TaskManagerView.swift:32`

- [ ] **Step 1: Create the native details view**

Create `TaskDetailsPopoverView` with derived bindings that immediately send deadline changes to the store-backed closure:

```swift
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
```

- [ ] **Step 2: Make the task content the popover trigger**

In `TaskRowView`, add `let updateDueDate: (Date?) -> Void` and `@State private var isShowingDetails = false`. Wrap the existing title/date/notes `VStack` in a plain button and attach the popover to that button:

```swift
Button("Show details for \(task.title)") {
    isShowingDetails = true
} label: {
    VStack(alignment: .leading, spacing: 2) {
        Text(task.title)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.secondary)
                    .frame(height: 1)
                    .scaleEffect(x: task.isCompleted ? 1 : 0, anchor: .leading)
                    .opacity(task.isCompleted ? 1 : 0)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: task.isCompleted)

        if let dueDate = task.dueDate {
            Text(
                dueDate,
                format: isAgenda
                    ? .dateTime.hour().minute()
                    : .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Text("No due date")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }

        if !task.notes.isEmpty {
            Text(task.notes)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
}
.buttonStyle(.plain)
.popover(isPresented: $isShowingDetails) {
    TaskDetailsPopoverView(task: task, updateDueDate: updateDueDate)
}
```

The checkbox, delete button, hover behavior, and context menu stay outside this button.

- [ ] **Step 3: Route the deadline callback through both views**

Add `let updateDueDate: (UUID, Date?) -> Void` to `TaskListView` and `TaskCalendarView`, including the calendar initializer. Pass it into each row:

```swift
updateDueDate: { updateDueDate(task.id, $0) }
```

Pass the store method from both branches in `TaskManagerView`:

```swift
updateDueDate: model.taskStore.updateDueDate
```

- [ ] **Step 4: Build the UI and resolve compiler diagnostics**

Run:

```bash
xcodebuild build -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit the popover UI**

```bash
git add ScreenSage/Tasks/TaskDetailsPopoverView.swift ScreenSage/Tasks/TaskRowView.swift ScreenSage/Tasks/TaskListView.swift ScreenSage/Tasks/TaskCalendarView.swift ScreenSage/Tasks/TaskManagerView.swift
git commit -m "feat: show editable task details popover"
```

### Task 3: Verify and install

**Files:**
- No additional source files.

- [ ] **Step 1: Run the complete automated verification**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: `** TEST SUCCEEDED **` and no `git diff --check` output.

- [ ] **Step 2: Install the signed app**

```bash
./scripts/install.sh
```

Expected: the Release build installs to `/Applications/screenie.app` and relaunches.

- [ ] **Step 3: Visually inspect the interaction**

Open the task manager and verify:

1. List and calendar agenda task text opens a popover anchored to the clicked row.
2. Checkbox and delete controls retain their existing behavior.
3. Title, notes, status, and timestamps render correctly.
4. Adding, changing, and removing a deadline update the row immediately.
5. Clicking outside dismisses the popover without losing the deadline edit.
