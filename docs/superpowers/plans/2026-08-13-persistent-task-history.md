# Persistent Task History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Persist Screenie tasks, make completed tasks restorable from History, and keep dated tasks synchronized with Apple Calendar.

**Architecture:** Extend the existing observable `TaskStore` with the same atomic JSON pattern already used by `ChatHistoryStore`. Share that store with a Tasks section in the existing History window. Use native EventKit directly for one-way task-to-calendar reconciliation; local task saves remain authoritative when Calendar access fails.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Foundation JSON, EventKit, XCTest.

---

### Task 1: Persist tasks and completion history

**Files:**
- Modify: `ScreenSage/Tasks/ScreenieTask.swift`
- Modify: `ScreenSage/Tasks/TaskStore.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add focused tests for add/reload, complete/reload, restore/reload, completed ordering, corrupt JSON, and excluded private/transient fields.
- [ ] Run the focused tests and confirm they fail for the missing persistence behavior.
- [ ] Make `ScreenieTask` codable with creation/completion timestamps and a Calendar event identifier.
- [ ] Reuse the history store's atomic JSON save/load pattern at `~/Library/Application Support/ScreenSage/tasks.json`.
- [ ] Save every add/complete/restore mutation and expose readable load/save errors.
- [ ] Run the focused tests and confirm they pass.

### Task 2: Synchronize dated tasks with Apple Calendar

**Files:**
- Create: `ScreenSage/Tasks/TaskCalendarSync.swift`
- Modify: `ScreenSage/Tasks/TaskStore.swift`
- Modify: `ScreenSage/ScreenSage-Info.plist`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add a focused test for Calendar event title, 30-minute duration, notes marker, and completed title prefix.
- [ ] Run the test and confirm it fails because Calendar mapping does not exist.
- [ ] Add a small EventKit sync actor that requests full event access and upserts into the default writable calendar.
- [ ] Trigger reconciliation after add, complete, restore, and load; persist returned event identifiers without losing local data on failure.
- [ ] Add the Calendar full-access usage description.
- [ ] Run the focused tests and confirm they pass without touching the real calendar.

### Task 3: Add Tasks to History

**Files:**
- Locate and modify the existing History SwiftUI view.
- Modify: `ScreenSage/App/ScreenSageApp.swift`
- Create only the minimum task-history SwiftUI views required by the existing structure.

- [ ] Add a compact Conversations/Tasks segmented switch to the existing History window.
- [ ] Show Active and Completed task sections, with active due-date order and completed newest-first order.
- [ ] Show task metadata in the detail pane and provide Complete/Restore using the shared `TaskStore`.
- [ ] Build the app and resolve SwiftUI/accessibility issues.

### Task 4: Documentation and verification

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/task-manager.md`

- [ ] Document durable task history, recovery, Calendar behavior, and Calendar permission.
- [ ] Update the repository persistence guardrail to permit only the requested task fields.
- [ ] Run focused tests, then the full `xcodebuild test` command.
- [ ] Run `git diff --check` and review the diff for unrelated changes and persisted private/transient data.
- [ ] Run `./scripts/install.sh` and visually inspect History → Tasks in the installed app.
- [ ] Leave the app in a normal, non-mock launch state.
