# Local Foundation Model Task Parsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse `/task <entry>` with Apple's on-device Foundation Models framework and preserve the current deterministic parser as a fallback.

**Architecture:** Add one focused parser that requests guided structured output from `SystemLanguageModel.default`, validates it into `ScreenieTask`, and falls back to `TaskEntryParser` when the local model is unavailable or fails. Inject the async parse function into `AppModel` so command behavior is deterministic in tests, and reuse the existing task error and persistence paths.

**Tech Stack:** Swift 6, Foundation Models, Foundation, Observation, SwiftUI, XCTest.

---

### Task 1: Define and test structured task conversion

**Files:**
- Create: `ScreenSage/Tasks/FoundationModelTaskParser.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Write failing tests for validated model output**

Add tests that call `FoundationModelTaskParser.makeTask` with trimmed title/notes and an offset ISO 8601 due date, then assert the resulting `ScreenieTask` fields. Add rejection checks for an empty title and malformed date.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testFoundationModelOutputBuildsValidatedTask
```

Expected: compilation fails because `FoundationModelTaskParser` does not exist.

- [ ] **Step 3: Implement the minimum local parser**

Create a `@Generable` output with `title`, optional `dueDateISO8601`, and `notes`. Add `makeTask` validation using Foundation's ISO 8601 parsing. Add an async `parse` method that checks `SystemLanguageModel.default.availability`, supplies current date/time/time-zone instructions to `LanguageModelSession`, and requests guided output. Rethrow cancellation; on other failures or unavailability, call the existing `TaskEntryParser`.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the focused command from Step 2 and expect one passing test with zero failures.

### Task 2: Route `/task` through the async local parser

**Files:**
- Modify: `ScreenSage/Overlay/AppModel.swift`
- Modify: `ScreenSage/Tasks/TaskManagerView.swift`
- Modify: `ScreenSage/Tasks/TaskListView.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Write failing async command tests**

Inject a parser closure into `AppModel`, submit `/task plan revision in two hours`, and verify the model enters task mode, reports parsing progress, and adds the returned task after completion. Inject a throwing parser in the existing inline-error test and verify no task is added.

- [ ] **Step 2: Run the command tests and verify RED**

Run:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testTaskCommandAddsAsyncNaturalLanguageTask -only-testing:ScreenSageTests/ScreenSageTests/testTaskCommandShowsInvalidDueDateInline
```

Expected: compilation fails because `AppModel` has no async task parser injection or parsing state.

- [ ] **Step 3: Implement async command routing and progress**

Add an injected `@Sendable (String) async throws -> ScreenieTask` closure with a default that calls `FoundationModelTaskParser.parse`. Change `handleTaskCommand` to launch one task, update `isParsingTask`, add successful results through `TaskStore.add`, and place localized errors in `taskError`. Pass the parsing state to `TaskListView` and render `ProgressView("Understanding task…")`.

- [ ] **Step 4: Run the command tests and verify GREEN**

Run the focused command from Step 2 and expect both tests to pass with zero failures.

### Task 3: Document and verify the complete flow

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/task-manager.md`

- [ ] Update the task documentation to state that `/task <entry>` uses Apple Foundation Models locally, falls back to deterministic parsing, and never uses the configured API provider.
- [ ] Run all tests with the repository's documented `xcodebuild test` command.
- [ ] Run `git diff --check` and review the diff for App Intents, network task parsing, new dependencies, or persisted model prompts.
- [ ] Run `./scripts/install.sh`, launch the installed app normally, and visually verify the existing task screen plus parsing progress behavior without leaving test task data behind.
- [ ] Commit the implementation as one focused feature commit.
