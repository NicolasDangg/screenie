# Explicit Task Date Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure an explicit task suffix such as `next tue` determines the persisted due date even when Foundation Models emits a different weekday.

**Architecture:** Reuse `TaskEntryParser` as the deterministic resolver by testing the final two words and then the final word as a fabricated `due` phrase anchored at 09:00 local time. Apply that result after structured model conversion; otherwise preserve the model date unchanged.

**Tech Stack:** Swift 6, Foundation Models, Foundation Calendar, XCTest.

---

### Task 1: Reconcile explicit date suffixes

**Files:**
- Modify: `ScreenSage/Tasks/FoundationModelTaskParser.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Add the failing regression test**

Add a test that supplies source entry `physics deadline next tue`, a generated Monday due date, and Thursday August 13 as `now`, then expects Tuesday August 18 at 09:00. Also assert that an entry without a recognized suffix preserves the generated date.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testFoundationModelParserHonorsExplicitTaskDateSuffix
```

Expected: compilation fails because the reconciliation helper does not exist.

- [ ] **Step 3: Implement the minimum reconciliation helper**

Add this internal helper to `FoundationModelTaskParser` and call it on the task produced by `makeTask`:

```swift
static func reconcileDueDate(
    in task: ScreenieTask,
    entry: String,
    now: Date,
    calendar: Calendar
) -> ScreenieTask
```

The helper sets an anchor to 09:00, tries the last two words and then the last word through `TaskEntryParser.parse("Task due \(candidate)")`, and replaces `dueDate` only when that parser returns one.

- [ ] **Step 4: Run focused and full tests**

Run the focused command from Step 2, then the repository's full `xcodebuild test` command. Both must exit zero.

### Task 2: Install and repair the existing task

**Files:**
- User data: `~/Library/Application Support/ScreenSage/tasks.json`

- [ ] Run `git diff --check`, review the diff, and commit the source/test fix.
- [ ] Run `./scripts/install.sh` to install the signed Release build.
- [ ] Stop Screenie and create a timestamped backup of `tasks.json`.
- [ ] Change only task `AA65862E-D6B1-42AD-A7C0-CF8667D8423C` from Monday August 17 at 09:00 to Tuesday August 18 at 09:00.
- [ ] Relaunch Screenie normally and verify the JSON date plus the existing Calendar event identifier are retained so EventKit reconciles the event in place.
