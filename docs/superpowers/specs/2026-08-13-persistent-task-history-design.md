# Persistent Task History Design

## Scope

Screenie will persist every task, including completed tasks, so completion is always reversible after relaunch. The existing History window will gain a Tasks view alongside Conversations, and dated tasks will synchronize automatically with Apple Calendar.

This explicitly updates the earlier persistence rule: task title, notes, due date, creation date, completion state, completion timestamp, and Apple Calendar event identifier may now be stored locally. Screenshots, OCR text, schedule hints, and AI request payloads remain nonpersistent.

## Storage

`ScreenieTask` becomes `Codable` and adds `createdAt`, `completedAt`, and an optional `calendarEventIdentifier`. `TaskStore` follows `ChatHistoryStore`'s existing atomic JSON pattern and stores records at:

```text
~/Library/Application Support/ScreenSage/tasks.json
```

Adding a task writes the file. Completing a task sets `completedAt` and writes; restoring it clears `completedAt` and writes. Records are never deleted merely because they are completed. A malformed file leaves the store empty and exposes a readable `lastError` without overwriting the bad file until the user next changes task data.

## Apple Calendar sync

The native EventKit framework synchronizes every dated task into the user's default writable calendar. Screenie asks for full Calendar access on the first required sync.

- A task event starts at its due date and lasts 30 minutes.
- The event title matches the task title; completed tasks use a `✓ ` prefix and restoring removes it.
- Task notes are copied into the event with a short “Managed by screenie” marker.
- Adding, completing, restoring, and app relaunch all reconcile the event.
- Undated tasks remain local because Calendar events require a date.
- If the stored event identifier no longer resolves because the event was removed externally, Screenie creates a replacement.
- Permission denial or EventKit failure leaves the local task untouched and exposes a readable calendar sync error.

The Info.plist receives the required full-calendar-access usage description. No external calendar library or separate calendar is introduced.

## History UI

The History window receives a compact segmented Conversations/Tasks switch above its content. Conversations retain the current split-view behavior.

The Tasks section uses a split view:

- Sidebar sections show Active and Completed tasks.
- Completed tasks are ordered by most recent completion; active tasks retain due-date order.
- The detail pane shows title, status, due date, notes, and timestamps.
- A button marks an active task complete or restores a completed task.
- No deletion control is added because recovery, not task disposal, is the requested behavior.

The task overlay and History window share the same `TaskStore` instance from `AppRuntime`, so changes appear in both immediately and use one save path.

## Verification

Tests will prove add/reload persistence, completion/reload persistence, restoration/reload persistence, completion timestamp ordering, corrupt-file errors, calendar event mapping, sync invocation, and absence of screenshot/OCR/schedule data in the JSON. The full suite, signed installation, `git diff --check`, and Computer Use inspection of History → Tasks will verify integration and layout without inserting test events into the user's real calendar.
