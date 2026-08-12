# Permission Status Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add live macOS permission statuses and direct System Settings links to ScreenSage Settings.

**Architecture:** A small `AppPermission` enum owns labels, requirement level, status checks, and privacy-pane URLs. `PermissionSettingsView` renders native SwiftUI rows and refreshes them when the app becomes active. `SettingsView` embeds the section without changing provider settings.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Core Graphics, ApplicationServices, XCTest.

---

### Task 1: Permission metadata

**Files:**
- Create: `ScreenSage/Settings/AppPermission.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add a failing test asserting the three permissions, their required/optional labels, and their `Privacy_ScreenCapture`, `Privacy_Accessibility`, and `Privacy_ListenEvent` URL anchors.
- [ ] Run `xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testPermissionSettingsMetadata` and confirm it fails because `AppPermission` does not exist.
- [ ] Add `AppPermission` with cases `screenRecording`, `accessibility`, and `inputMonitoring`; expose `title`, `requirement`, `settingsURL`, and `isGranted` using the native preflight functions.
- [ ] Rerun the focused test and confirm it passes.

### Task 2: Settings interface

**Files:**
- Create: `ScreenSage/Settings/PermissionSettingsView.swift`
- Modify: `ScreenSage/Settings/SettingsView.swift`

- [ ] Render a Permissions section with one accessible row per `AppPermission`, showing Enabled or Disabled plus Required or Optional.
- [ ] Add `Button("Open Settings", action:)` to open each permission URL with `NSWorkspace.shared.open`.
- [ ] Refresh status in `.task` and when `scenePhase` changes to `.active`.

### Task 3: Verification

**Files:**
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Run the full `xcodebuild test` command and confirm all tests pass.
- [ ] Open Settings, visually verify all three rows, and click one button to confirm System Settings opens the matching pane.
- [ ] Run `git diff --check`, commit to `main`, restart ScreenSage, and verify only one instance remains.
