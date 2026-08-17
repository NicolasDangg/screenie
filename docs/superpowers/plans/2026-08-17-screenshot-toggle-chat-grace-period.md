# Screenshot Toggle and Chat Grace Period Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a circular screenshot-inclusion toggle for post-first messages and resume a hidden conversation for 60 seconds before the next presentation starts a new chat.

**Architecture:** Keep screenshot selection and the in-memory hide/resume timer in the existing `AppModel`; keep layout rendering in `OverlayView` and panel lifecycle calls in `OverlayPanelController`. The first assistant response gates the toggle, while the first request always selects screenshot capture. Store no new screenshot/OCR data.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSPanel`, ScreenCaptureKit, Vision, Foundation, XCTest.

---

## File map

- Modify `ScreenSage/Overlay/AppModel.swift`: screenshot selection, toggle state, suspend/resume timer, and optional capture in `submit()`.
- Modify `ScreenSage/Overlay/OverlayView.swift`: circular accessible checkbox button to the left of the existing text field.
- Modify `ScreenSage/Overlay/OverlayPanelController.swift`: suspend on hide, prepare/resume on show, and preserve explicit New Chat behavior.
- Modify `ScreenSageTests/ScreenSageTests.swift`: screenshot-selection and 60-second lifecycle regression tests.
- Do not modify `ScreenSage/Capture`, `ScreenSage/Provider`, history models, or persistence formats.

### Task 1: Write failing behavior tests

**Files:**
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [x] **Step 1: Add screenshot-selection and toggle-state tests**

Add these tests near the existing `testMockResponseBypassesProviderAndScreenCapture` test:

```swift
func testScreenshotSelectionAlwaysIncludesFirstRequest() {
    XCTAssertTrue(AppModel.shouldIncludeScreenshot(
        hasCompletedFirstResponse: false,
        includeScreenshotForNextMessage: false
    ))
    XCTAssertTrue(AppModel.shouldIncludeScreenshot(
        hasCompletedFirstResponse: true,
        includeScreenshotForNextMessage: true
    ))
    XCTAssertFalse(AppModel.shouldIncludeScreenshot(
        hasCompletedFirstResponse: true,
        includeScreenshotForNextMessage: false
    ))
}

@MainActor
func testScreenshotToggleIsLockedUntilFirstResponseAndResetsForNewChat() {
    let model = AppModel(
        settings: AppSettings(),
        taskStore: TaskStore(fileURL: nil, calendarSync: nil),
        mockResponse: "Answer"
    )

    XCTAssertTrue(model.includeScreenshotForNextMessage)
    model.toggleScreenshotForNextMessage()
    XCTAssertTrue(model.includeScreenshotForNextMessage)

    model.prompt = "First question"
    model.submit()
    XCTAssertTrue(model.canToggleScreenshot)

    model.toggleScreenshotForNextMessage()
    XCTAssertFalse(model.includeScreenshotForNextMessage)
    model.startNewConversation()
    XCTAssertTrue(model.includeScreenshotForNextMessage)
}
```

- [x] **Step 2: Add the hide/resume/expiry regression test**

Add this asynchronous test near the existing overlay panel tests:

```swift
@MainActor
func testHiddenConversationResumesWithinGraceAndExpiresAfterGrace() async {
    let model = AppModel(
        settings: AppSettings(),
        taskStore: TaskStore(fileURL: nil, calendarSync: nil),
        mockResponse: "Answer",
        conversationGracePeriod: 2
    )
    let controller = OverlayPanelController(model: model)

    controller.show()
    model.prompt = "Keep this chat"
    model.submit()
    let suspendedID = model.conversation.id
    model.toggleScreenshotForNextMessage()
    controller.hide()

    controller.show()
    XCTAssertEqual(model.conversation.id, suspendedID)
    XCTAssertFalse(model.includeScreenshotForNextMessage)

    controller.hide()
    try? await Task.sleep(for: .seconds(2.1))
    controller.show()
    XCTAssertNotEqual(model.conversation.id, suspendedID)
    XCTAssertTrue(model.includeScreenshotForNextMessage)
}
```

- [x] **Step 3: Run the tests to verify they fail for the missing feature**

Run:

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `AppModel.shouldIncludeScreenshot`, the screenshot-toggle state/actions, the grace-period initializer argument, and the lifecycle behavior do not exist yet.

### Task 2: Implement screenshot selection and conversation grace state

**Files:**
- Modify: `ScreenSage/Overlay/AppModel.swift`

- [x] **Step 1: Add the minimal model state and pure selection rule**

Add the following model members:

```swift
var includeScreenshotForNextMessage = true

var hasCompletedFirstResponse: Bool {
    conversation.messages.contains { $0.role == .assistant }
}

var canToggleScreenshot: Bool {
    hasCompletedFirstResponse && !isWorking
}

nonisolated static func shouldIncludeScreenshot(
    hasCompletedFirstResponse: Bool,
    includeScreenshotForNextMessage: Bool
) -> Bool {
    !hasCompletedFirstResponse || includeScreenshotForNextMessage
}
```

Add `conversationGracePeriod: TimeInterval = 60` as the final `init` parameter and store it in a private property. Add private `conversationExpiryTask` and `conversationExpiresAt` properties.

- [x] **Step 2: Add toggle and lifecycle methods**

Implement these methods in `AppModel`:

```swift
func toggleScreenshotForNextMessage() {
    guard canToggleScreenshot else { return }
    includeScreenshotForNextMessage.toggle()
}

func prepareForPresentation() {
    guard let expiresAt = conversationExpiresAt else { return }
    guard expiresAt > .now else {
        startNewConversation()
        return
    }
    conversationExpiryTask?.cancel()
    conversationExpiryTask = nil
    conversationExpiresAt = nil
}
```

Add `suspendConversation()` that cancels the active request, stops the working/streaming UI state, persists a completed conversation using the existing history store, and schedules a task for `conversationGracePeriod`. Capture the current conversation ID and expiry date in the task. When the task wakes, clear only if both still match, then call `startNewConversation()`.

Cancel and clear the expiry task/date and reset `includeScreenshotForNextMessage` to `true` inside `startNewConversation()`.

- [x] **Step 3: Select optional context in `submit()`**

Before appending the submitted user message, calculate:

```swift
let shouldIncludeScreenshot = Self.shouldIncludeScreenshot(
    hasCompletedFirstResponse: hasCompletedFirstResponse,
    includeScreenshotForNextMessage: includeScreenshotForNextMessage
)
```

Inside the request task, replace unconditional capture with:

```swift
let context = shouldIncludeScreenshot
    ? try await ScreenContextCapture.capture()
    : nil
```

Pass `context?.ocrText ?? ""` and `context?.imageData` to `providerClient.stream`. Leave the existing mock-response branch before capture unchanged so mock mode continues to bypass capture and networking.

- [x] **Step 4: Run focused tests**

Run:

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  -only-testing:ScreenSageTests/ScreenSageTests/testScreenshotSelectionAlwaysIncludesFirstRequest \
  -only-testing:ScreenSageTests/ScreenSageTests/testScreenshotToggleIsLockedUntilFirstResponseAndResetsForNewChat \
  -only-testing:ScreenSageTests/ScreenSageTests/testHiddenConversationResumesWithinGraceAndExpiresAfterGrace \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all three new tests pass.

### Task 3: Add the control and connect panel lifecycle

**Files:**
- Modify: `ScreenSage/Overlay/OverlayView.swift`
- Modify: `ScreenSage/Overlay/OverlayPanelController.swift`

- [x] **Step 1: Add the circular checkbox button**

Insert the button before the existing `TextField` in the composer `HStack`. Use the existing `25.2` point control size, a blue filled circle/checkmark when enabled, an outlined circle when disabled, and a plain button style. Keep the current send button and input spacing unchanged.

Use an accessible text label while rendering the control as an icon-only circle:

```swift
Button(action: model.toggleScreenshotForNextMessage) {
    ZStack {
        Circle()
            .fill(model.includeScreenshotForNextMessage ? .blue : .clear)
        Circle()
            .strokeBorder(.primary.opacity(0.34), lineWidth: 0.8)
        if model.includeScreenshotForNextMessage {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
        }
    }
}
.buttonStyle(.plain)
.frame(width: 25.2, height: 25.2)
.foregroundStyle(model.includeScreenshotForNextMessage ? .white : .primary)
.opacity(model.canToggleScreenshot ? 1 : 0.45)
.disabled(!model.canToggleScreenshot)
.accessibilityLabel(
    model.includeScreenshotForNextMessage ? "Screenshot included" : "Screenshot excluded"
)
.accessibilityValue(model.includeScreenshotForNextMessage ? "On" : "Off")
.accessibilityHint("Toggles whether the next message includes a new screenshot and OCR")
```

The conditional image hides the checkmark when unchecked while the explicit accessibility label remains available to assistive technologies. The button remains visible but disabled for the first request and while streaming.

- [x] **Step 2: Resume or start the correct conversation on panel show**

In `OverlayPanelController.show()`, replace `model.startNewConversation()` with `model.prepareForPresentation()`. Set the panel height from `model.isExpanded` rather than always collapsing it, so a resumed conversation reopens expanded while a new chat remains collapsed.

- [x] **Step 3: Suspend instead of clearing on hide**

In `OverlayPanelController.hide()`, replace `model.finishConversation()` with `model.suspendConversation()`.

Update `startNewChat()` to finish before either path, ensuring explicit New Chat cancels any grace timer and never resumes the suspended conversation:

```swift
func startNewChat() {
    model.finishConversation()
    if isPresented {
        setExpanded(false)
    } else {
        show()
    }
}
```

- [x] **Step 4: Build and run the UI-focused tests**

Run:

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  -only-testing:ScreenSageTests/ScreenSageTests/testOverlayUsesAdaptiveBarDimensions \
  -only-testing:ScreenSageTests/ScreenSageTests/testOverlayPanelTogglesPresentedState \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both existing UI/lifecycle tests and the new feature tests pass.

### Task 4: Full verification and handoff

**Files:**
- Verify: `ScreenSage/Overlay/AppModel.swift`
- Verify: `ScreenSage/Overlay/OverlayView.swift`
- Verify: `ScreenSage/Overlay/OverlayPanelController.swift`
- Verify: `ScreenSageTests/ScreenSageTests.swift`

- [x] **Step 1: Run the complete test suite**

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with zero failures.

- [x] **Step 2: Build the app without signing**

```bash
xcodebuild build \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [x] **Step 3: Check the diff and preserve unrelated work**

```bash
git diff --check
git status --short
git diff -- ScreenSage/Overlay/AppModel.swift ScreenSage/Overlay/OverlayView.swift ScreenSage/Overlay/OverlayPanelController.swift ScreenSageTests/ScreenSageTests.swift
```

Confirm the diff contains only screenshot-toggle/grace-period behavior plus its tests; do not stage the pre-existing `AssistantResponseText.swift` changes unless they were already staged by the user.

- [x] **Step 4: Visually inspect the installed app**

Run `./scripts/install.sh`, launch once with `SCREENIE_MOCK_RESPONSE` set, and verify manually:

1. The circular checkbox is directly left of the input field.
2. It is visibly checked but disabled before the first response.
3. It becomes toggleable after the first response.
4. Checked subsequent submission uses capture/OCR; unchecked subsequent submission does not.
5. Hiding and reopening within 60 seconds restores the same chat; reopening after expiry starts a checked, empty chat.

- [x] **Step 5: Commit the implementation**

```bash
git add ScreenSage/Overlay/AppModel.swift ScreenSage/Overlay/OverlayView.swift ScreenSage/Overlay/OverlayPanelController.swift ScreenSageTests/ScreenSageTests.swift
git commit -m "feat: toggle screenshots and resume hidden chats"
```
