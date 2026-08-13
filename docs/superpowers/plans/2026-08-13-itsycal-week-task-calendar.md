# Itsycal-Inspired Weekly Task Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship an Itsycal-inspired month calendar with a weekly Screenie task agenda, native week swiping, task deletion with Calendar cleanup, and reliable explicit weekday parsing.

**Architecture:** Keep task data in the existing `TaskStore`. Replace only the task calendar presentation with a custom SwiftUI month grid and a horizontally paging weekly agenda. Extend the existing EventKit actor for deletion and reuse `TaskEntryParser` to correct explicit parser suffixes.

**Tech Stack:** Swift 6, SwiftUI, AppKit, EventKit, Foundation Models, XCTest.

---

### Task 1: Correct explicit natural-language dates

**Files:**
- Modify: `ScreenSage/Tasks/FoundationModelTaskParser.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add a regression test where `physics deadline next tue`, parsed on Thursday August 13, overrides a generated Monday with Tuesday August 18 at 09:00.
- [ ] Run the focused test and confirm it fails.
- [ ] Add the minimum suffix reconciliation helper and call it after structured model conversion.
- [ ] Run the focused test and confirm it passes.

### Task 2: Delete tasks and their linked Calendar events

**Files:**
- Modify: `ScreenSage/Tasks/TaskStore.swift`
- Modify: `ScreenSage/Tasks/TaskCalendarSync.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add a test proving deletion persists and calls Calendar cleanup with the deleted task.
- [ ] Run the focused test and confirm it fails.
- [ ] Add `TaskStore.delete`, rollback on local save failure, and serialize cleanup after any in-flight sync.
- [ ] Add `TaskCalendarSync.delete`, resolving by event identifier or stable task marker.
- [ ] Run the focused store tests and confirm they pass.

### Task 3: Build the Itsycal-style month and weekly agenda

**Files:**
- Replace: `ScreenSage/Tasks/TaskCalendarView.swift`
- Modify: `ScreenSage/Tasks/TaskRowView.swift`
- Modify: `ScreenSage/Tasks/TaskListView.swift`
- Modify: `ScreenSage/Tasks/TaskManagerView.swift`
- Modify: `ScreenSage/Overlay/OverlayLayout.swift`
- Modify: `ScreenSage/Overlay/OverlayView.swift`
- Modify: `ScreenSage/Overlay/OverlayPanelController.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add one regression test for locale-aware 42-day month grids and seven-day week ranges.
- [ ] Run the focused test and confirm it fails.
- [ ] Implement the custom grid, task dots, current/selected-week styling, month/today navigation, and grouped weekly agenda.
- [ ] Use a native horizontal paging `ScrollView` for two-finger week navigation.
- [ ] Add row delete controls/context menus routed through one confirmation alert.
- [ ] Make Calendar the default task mode, use a task-only expanded height, and replace the footer text button with a compact glass `+` control.
- [ ] Run focused tests and build until clean.

### Task 4: Verify, install, and repair the known task

**Files:**
- User data: `~/Library/Application Support/ScreenSage/tasks.json`

- [ ] Run the full test suite and `git diff --check`.
- [ ] Review and commit the implementation.
- [ ] Run `./scripts/install.sh` and visually inspect the installed task UI.
- [ ] Stop Screenie, create a timestamped `tasks.json` backup, change only task `AA65862E-D6B1-42AD-A7C0-CF8667D8423C` to Tuesday August 18 at 09:00, and relaunch.
- [ ] Verify the task JSON retains its existing Calendar event identifier so EventKit updates the same event.
