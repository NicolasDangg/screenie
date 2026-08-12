# screenie Overlay Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Launch screenie quietly at login, toggle it with Option–Space, and restore its last hidden overlay position.

**Architecture:** Keep the existing Carbon hotkey and `NSPanel`. Register the signed main app with `SMAppService`, remove startup presentation, and persist only two panel-origin coordinates in `UserDefaults`; no new service layer or dependency is needed.

**Tech Stack:** Swift 6, AppKit, Carbon, ServiceManagement, UserDefaults, XCTest, macOS 26.

---

### Task 1: Lock shortcut, agent-app, and position-storage behavior

**Files:**
- Modify: `ScreenSageTests/ScreenSageTests.swift`
- Modify: `ScreenSage/App/GlobalHotKey.swift`
- Modify: `ScreenSage/Overlay/OverlayPanelController.swift`

- [ ] **Step 1: Add failing focused checks**

```swift
func testGlobalShortcutIsOptionSpace() {
    XCTAssertEqual(GlobalHotKey.keyCode, UInt32(kVK_Space))
    XCTAssertEqual(GlobalHotKey.modifiers, UInt32(optionKey))
}

func testAppStaysMenuBarOnly() {
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, true)
}

func testOverlayPositionRoundTrip() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let origin = NSPoint(x: -420.5, y: 180.25)
    OverlayPanelController.saveOrigin(origin, in: defaults)
    XCTAssertEqual(OverlayPanelController.savedOrigin(in: defaults), origin)
}
```

- [ ] **Step 2: Run the focused checks and verify failure**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -only-testing:ScreenSageTests/ScreenSageTests/testGlobalShortcutIsOptionSpace \
  -only-testing:ScreenSageTests/ScreenSageTests/testAppStaysMenuBarOnly \
  -only-testing:ScreenSageTests/ScreenSageTests/testOverlayPositionRoundTrip
```

Expected: build failure because the hotkey constants and position functions do not exist.

- [ ] **Step 3: Expose and use the Option–Space constants**

In `GlobalHotKey` add:

```swift
static let keyCode = UInt32(kVK_Space)
static let modifiers = UInt32(optionKey)
```

Use those values in `RegisterEventHotKey` instead of inline Space and Command–Option values.

- [ ] **Step 4: Add the two-coordinate position helpers**

In `OverlayPanelController` add a private `UserDefaults` property, accept `defaults: UserDefaults = .standard` in the initializer, and add:

```swift
private enum PositionKeys {
    static let x = "overlayPosition.x"
    static let y = "overlayPosition.y"
}

static func saveOrigin(_ origin: NSPoint, in defaults: UserDefaults) {
    defaults.set(origin.x, forKey: PositionKeys.x)
    defaults.set(origin.y, forKey: PositionKeys.y)
}

static func savedOrigin(in defaults: UserDefaults) -> NSPoint? {
    guard defaults.object(forKey: PositionKeys.x) != nil,
          defaults.object(forKey: PositionKeys.y) != nil else { return nil }
    return NSPoint(
        x: defaults.double(forKey: PositionKeys.x),
        y: defaults.double(forKey: PositionKeys.y)
    )
}
```

- [ ] **Step 5: Run the focused checks and verify success**

Run the command from Step 2.

Expected: all three focused checks pass.

### Task 2: Launch quietly at login and restore panel origin

**Files:**
- Modify: `ScreenSage/App/AppRuntime.swift`
- Modify: `ScreenSage/Overlay/OverlayPanelController.swift`
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Add a failing quiet-start check**

```swift
@MainActor
func testAppRuntimeStartsWithOverlayHidden() {
    AppRuntime.shared.start()
    XCTAssertFalse(AppRuntime.shared.isOverlayPresented)
}
```

- [ ] **Step 2: Run the check and verify failure**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testAppRuntimeStartsWithOverlayHidden
```

Expected: build failure because `isOverlayPresented` does not exist, or assertion failure because startup currently presents the overlay.

- [ ] **Step 3: Register login launch without presenting the overlay**

In `AppRuntime.swift`, import `ServiceManagement`, remove `showOverlay()` from `start()`, register the main app only when needed, and expose read-only presentation state:

```swift
var isOverlayPresented: Bool { panelController.isPresented }

func start() {
    hotKey = GlobalHotKey { [weak self] in self?.toggleOverlay() }
    if SMAppService.mainApp.status == .notRegistered {
        try? SMAppService.mainApp.register()
    }
}
```

- [ ] **Step 4: Restore a valid saved origin and save it on hide**

During first positioning, construct the collapsed panel frame at the saved origin and restore it only when it intersects one of `NSScreen.screens.map(\.visibleFrame)`. Otherwise retain the current pointer-display fallback. At the start of `hide()`, call:

```swift
Self.saveOrigin(panel.frame.origin, in: defaults)
```

- [ ] **Step 5: Run the quiet-start and focused lifecycle checks**

Run the Task 2 Step 2 command, followed by the Task 1 Step 2 command.

Expected: all focused checks pass.

### Task 3: Document, install, and verify the real app

**Files:**
- Modify: `AGENTS.md`
- Verify: `/Applications/screenie.app`

- [ ] **Step 1: Update codebase context**

Change the documented shortcut to Option–Space and add that screenie registers as a login item, launches menu-bar-only with the overlay hidden, and persists the overlay origin on hide.

- [ ] **Step 2: Run complete automated verification**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: all tests pass and the diff check prints nothing.

- [ ] **Step 3: Install the signed Release build**

```bash
./scripts/install.sh
```

Expected: `BUILD SUCCEEDED`, one running screenie process, and no overlay at launch.

- [ ] **Step 4: Verify installed behavior**

Confirm `/Applications/screenie.app/Contents/Info.plist` contains `LSUIElement = true`; inspect the login-item database for `local.nicolas.ScreenSage`; toggle with Option–Space; drag the overlay; hide it; show it again; and confirm the origin is unchanged.

- [ ] **Step 5: Commit implementation**

```bash
git add AGENTS.md ScreenSage/App/AppRuntime.swift ScreenSage/App/GlobalHotKey.swift ScreenSage/Overlay/OverlayPanelController.swift ScreenSageTests/ScreenSageTests.swift
git commit -m "feat: persist overlay lifecycle"
```
