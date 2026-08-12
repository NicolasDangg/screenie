# Live Overlay Backdrop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the floating ScreenSage backdrop continuously reflect whichever desktop or app is behind it.

**Architecture:** Add one `NSViewRepresentable` that creates an `NSVisualEffectView` configured for active behind-window HUD blending. Use it as the existing overlay's clipped background and remove the cached SwiftUI glass modifier.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest.

---

### Task 1: Native live backdrop

**Files:**
- Create: `ScreenSage/Overlay/LiveBackdropView.swift`
- Modify: `ScreenSage/Overlay/OverlayView.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Add `testLiveBackdropUsesActiveBehindWindowBlending`, creating a visual effect view through `LiveBackdropView.makeVisualEffectView()` and asserting `.behindWindow`, `.hudWindow`, and `.active`.
- [ ] Run `xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testLiveBackdropUsesActiveBehindWindowBlending` and confirm it fails because `LiveBackdropView` does not exist.
- [ ] Implement `LiveBackdropView: NSViewRepresentable`; have `makeNSView` return `Self.makeVisualEffectView()` and leave `updateNSView` empty.
- [ ] In `OverlayView`, add `LiveBackdropView()` as the background clipped to the existing adaptive rounded rectangle and remove `glassEffect`.
- [ ] Rerun the focused test and confirm it passes.

### Task 2: Verification

**Files:**
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] Run the full `xcodebuild test` command and confirm all tests pass.
- [ ] Launch ScreenSage, show the overlay over Xcode, switch to System Settings, and confirm the live material changes while the panel remains visible.
- [ ] Run `git diff --check`, commit to `main`, restart ScreenSage, and verify only one process remains.
