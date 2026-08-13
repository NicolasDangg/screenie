# Screenie Task Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-memory, toggleable task manager with natural-language entry, list/calendar UI, completion animation, manual entry, and validated OpenRouter schedule hints.

**Architecture:** Extend the existing panel with a chat/task presentation mode rather than creating a second window stack. Keep task state in a small observable store owned by `AppModel`; reuse the existing provider endpoint and settings while adding a strict, non-streaming OpenRouter JSON request for scheduling.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Carbon, Foundation, Observation, XCTest, OpenRouter Chat Completions JSON Schema.

---

### Task 1: Task domain and natural-language parser

**Files:**
- Create: `ScreenSage/Tasks/ScreenieTask.swift`
- Create: `ScreenSage/Tasks/TaskEntryParser.swift`
- Create: `ScreenSage/Tasks/TaskStore.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add tests that parse the sample `phys homework unit 3 due on next tue`, relative dates, ISO dates, undated titles, and invalid explicit due phrases.
- [ ] Run the focused tests and confirm compilation fails because task types do not exist.
- [ ] Add `ScreenieTask`, `TaskEntryParser`, and an in-memory `TaskStore` with due-date ordering and completion toggling.
- [ ] Run the focused tests and confirm they pass.

The public parser shape is:

```swift
struct TaskEntryParser {
    static func parse(
        _ entry: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> ScreenieTask
}
```

### Task 2: Command routing and keyboard shortcut

**Files:**
- Modify: `ScreenSage/Overlay/AppModel.swift`
- Modify: `ScreenSage/App/GlobalHotKey.swift`
- Modify: `ScreenSage/App/AppRuntime.swift`
- Modify: `ScreenSage/Overlay/OverlayPanelController.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add tests proving `/task` opens task mode without capture, `/task <entry>` adds a task, invalid due text is visible, and Option–Command–Space uses the expected Carbon modifiers.
- [ ] Run those tests and confirm expected failures.
- [ ] Add `AppPresentationMode`, command routing before API validation, configurable hotkey IDs/modifiers, and `toggleTaskScreen()` panel/runtime wiring.
- [ ] Run focused tests and confirm they pass.

### Task 3: Strict OpenRouter schedule payload and decoding

**Files:**
- Create: `ScreenSage/Tasks/TaskSchedule.swift`
- Modify: `ScreenSage/Provider/ProviderRequestBuilder.swift`
- Modify: `ScreenSage/Provider/ProviderClient.swift`
- Modify: `ScreenSage/Settings/AppSettings.swift`
- Modify: `ScreenSage/Overlay/AppModel.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add tests for the fixed self-study periods, task-only request context, strict JSON Schema, valid outer OpenRouter response decoding, and rejection of invalid time ranges.
- [ ] Run those tests and confirm expected failures.
- [ ] Add the schedule models, schema/request builder, non-streaming OpenRouter request, saved OpenRouter-key lookup, and `AppModel.requestScheduleHint()`.
- [ ] Include an environment-provided mock schedule JSON path solely for network-free visual verification.
- [ ] Run focused tests and confirm they pass.

The response payload must be:

```json
{
  "summary": "Short schedule overview",
  "suggestions": [
    {
      "taskTitle": "Task title",
      "start": "2026-08-17T10:45:00+07:00",
      "end": "2026-08-17T11:30:00+07:00",
      "note": "Why this block fits"
    }
  ]
}
```

### Task 4: Task list, calendar, modal, and completion animation

**Files:**
- Create: `ScreenSage/Tasks/TaskManagerView.swift`
- Create: `ScreenSage/Tasks/TaskListView.swift`
- Create: `ScreenSage/Tasks/TaskRowView.swift`
- Create: `ScreenSage/Tasks/TaskCalendarView.swift`
- Create: `ScreenSage/Tasks/AddTaskView.swift`
- Create: `ScreenSage/Tasks/TaskScheduleView.swift`
- Modify: `ScreenSage/Overlay/OverlayView.swift`
- Modify: `ScreenSage/Overlay/OverlayLayout.swift`

- [ ] Replace the chat body only when the model is in task mode; preserve the existing chat view byte-for-byte where possible.
- [ ] Add the compact header, due-sorted rows with separators, accessible circular completion controls, left-to-right strike animation, and Reduce Motion handling.
- [ ] Add the native graphical date picker with tasks filtered to its selected day.
- [ ] Add the grouped native add-task sheet and footer actions.
- [ ] Render validated schedule summary/blocks beneath the task list and show inline loading/errors.
- [ ] Build the app to catch SwiftUI integration errors.

### Task 5: Documentation and verification

**Files:**
- Create: `docs/task-manager.md`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Document `/task`, Option–Command–Space, in-memory behavior, mock verification, UI measurements, and the JSON schema.
- [ ] Run all tests with the repository command.
- [ ] Run `git diff --check` and inspect the full diff for unrelated changes or sensitive content.
- [ ] Run `./scripts/install.sh`.
- [ ] Launch with sample task and schedule mock data, then use Computer Use to inspect list mode, completion styling, calendar mode, and the add-task modal.
- [ ] Return to a normal launch and perform a requirement-by-requirement completion audit.
