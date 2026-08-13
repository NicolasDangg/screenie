# Schedule Hint Calendar Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dismiss and batch Apple Calendar actions to generated task schedule hints.

**Architecture:** Keep schedule hints transient in `AppModel`. Extend the existing EventKit actor with an idempotent batch-add method and expose that flow through `TaskScheduleView`; reuse the existing task error surface for failures.

**Tech Stack:** Swift 6, SwiftUI, EventKit, Observation, XCTest.

---

### Task 1: Define and test Calendar mapping

**Files:**
- Modify: `ScreenSage/Tasks/TaskCalendarSync.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add `testTaskScheduleCalendarEventMapping`, constructing one suggestion and expecting title `Study: Physics`, unchanged dates, its note, and a stable Screenie marker.
- [ ] Run the focused test and verify compilation fails because `TaskScheduleCalendarEvent` does not exist.
- [ ] Add the small descriptor and `TaskCalendarSync.add(_:)`; reuse `hasAccess` and `matchingEvent`, stage EventKit saves with `commit: false`, then commit once.
- [ ] Run the focused test and verify it passes.

### Task 2: Add tested AppModel actions

**Files:**
- Modify: `ScreenSage/Overlay/AppModel.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add one test proving `dismissTaskSchedule()` clears the hint and one async test proving `addTaskScheduleToCalendar()` calls an injected Calendar closure and records success.
- [ ] Run both focused tests and verify compilation fails for the missing API.
- [ ] Add the injected closure, progress/success state, dismissal, cancellation, stale-result guard, and retryable error handling.
- [ ] Run both focused tests and verify they pass.

### Task 3: Wire the native controls

**Files:**
- Modify: `ScreenSage/Tasks/TaskScheduleView.swift`
- Modify: `ScreenSage/Tasks/TaskListView.swift`
- Modify: `ScreenSage/Tasks/TaskManagerView.swift`

- [ ] Add a trailing plain close button to the hint header and a bottom bordered-prominent Calendar button with progress and success labels.
- [ ] Pass AppModel actions and state through `TaskListView`.
- [ ] Wrap Schedule hint requests in `TaskManagerView` so Calendar mode switches to List before requesting.
- [ ] Build the app and resolve compiler diagnostics.

### Task 4: Verify and install

**Files:**
- No additional source files.

- [ ] Run the full `xcodebuild test` suite and `git diff --check`.
- [ ] Commit the implementation.
- [ ] Run `./scripts/install.sh` and visually inspect the signed hint controls.
