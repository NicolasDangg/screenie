# Adaptive AI Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Screen Sage’s card overlay with a 380 × 42 pt adaptive AI pill that expands upward for conversation, captures one screenshot plus local OCR per prompt, and persists text-only titled chat history.

**Architecture:** Keep the existing borderless `NSPanel`, global Carbon shortcut, ScreenCaptureKit capture, Vision OCR, and provider streaming path. Add small Codable conversation types and an atomic JSON history store, drive one adaptive SwiftUI root from `AppModel`, and expose History/Settings through native SwiftUI scenes and the menu bar.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Observation, ScreenCaptureKit, Vision, Foundation JSON, XCTest.

---

## File Map

- Create `ScreenSage/Conversation/ChatMessage.swift`: persisted user/assistant text message.
- Create `ScreenSage/Conversation/Conversation.swift`: titled conversation and title sanitization/fallback.
- Create `ScreenSage/Conversation/ChatHistoryStore.swift`: Application Support JSON persistence.
- Create `ScreenSage/Conversation/HistoryView.swift`: native local-history browser.
- Create `ScreenSage/App/MenuBarContentView.swift`: menu commands that can open the History scene.
- Create `ScreenSage/Overlay/PanelDragArea.swift`: AppKit-backed draggable background.
- Modify `ScreenSage/Overlay/AppModel.swift`: conversation lifecycle, multi-turn submission, ephemeral context, title generation.
- Modify `ScreenSage/Provider/ProviderRequestBuilder.swift`: text transcript plus optional latest image/OCR.
- Modify `ScreenSage/Provider/ProviderClient.swift`: shared streaming request that supports multimodal chat and text-only title generation.
- Modify `ScreenSage/Overlay/OverlayLayout.swift`: exact collapsed/expanded dimensions.
- Modify `ScreenSage/Overlay/OverlayView.swift`: compact adaptive pill and pinned composer.
- Modify `ScreenSage/Overlay/OverlayAnswerView.swift`: conversation messages, progress, and compact errors.
- Modify `ScreenSage/Overlay/OverlayPanelController.swift`: upward resize, no rectangular shadow, fresh chat per presentation.
- Modify `ScreenSage/App/AppRuntime.swift` and `ScreenSage/App/ScreenSageApp.swift`: history ownership and menu/window wiring.
- Delete `ScreenSage/Overlay/OverlayHeaderView.swift`, `ScreenSage/Overlay/PromptSuggestion.swift`, and `ScreenSage/Overlay/SuggestionBarView.swift`: controls removed from the approved interface.
- Modify `ScreenSageTests/ScreenSageTests.swift`: focused regression coverage.

### Task 1: Conversation Models and Local History

**Files:**
- Create: `ScreenSage/Conversation/ChatMessage.swift`
- Create: `ScreenSage/Conversation/Conversation.swift`
- Create: `ScreenSage/Conversation/ChatHistoryStore.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Write failing model and persistence tests**

Add tests that construct a temporary JSON URL, upsert a conversation, reload it, and assert that message text and title round-trip while the encoded file contains neither `imageData` nor `ocrText`. Add title tests that strip wrapping quotes and fall back to the first six words of the first prompt.

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' -only-testing:ScreenSageTests/ScreenSageTests/testHistoryRoundTrip -only-testing:ScreenSageTests/ScreenSageTests/testConversationTitleCleanup CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `ChatMessage`, `Conversation`, and `ChatHistoryStore` do not exist.

- [ ] **Step 3: Implement the minimal Codable types and store**

```swift
struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }
    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date
}

struct Conversation: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]
}
```

`ChatHistoryStore` loads `[Conversation]` from its injected URL, sorts newest-first, atomically writes JSON after `upsert`, and exposes a readable `lastError` instead of discarding persistence failures.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add ScreenSage/Conversation ScreenSageTests/ScreenSageTests.swift
git commit -m 'feat: add local text chat history'
```

### Task 2: Multi-Turn Provider Context and Topic Titles

**Files:**
- Modify: `ScreenSage/Provider/ProviderRequestBuilder.swift`
- Modify: `ScreenSage/Provider/ProviderClient.swift`
- Modify: `ScreenSage/Overlay/AppModel.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Write failing payload and reset tests**

Test that a request containing earlier user/assistant messages includes their text, includes latest OCR and a JPEG data URL when image data exists, and omits any image URL for a title request. Test that `startNewConversation()` clears prompt, messages, streamed response, errors, and the previous title.

- [ ] **Step 2: Run the focused tests and verify RED**

Run the two new tests with `xcodebuild test ... -only-testing:` and expect failures because the message-based builder and lifecycle API are absent.

- [ ] **Step 3: Generalize the provider request minimally**

```swift
static func requestBody(
    provider: AIProvider,
    model: String,
    messages: [ChatMessage],
    ocrText: String = "",
    imageData: Data? = nil
) -> [String: Any]
```

Serialize prior text as a compact `User:`/`Assistant:` transcript. Add OCR and the image only to the latest request. Keep OpenAI `store: false` and streaming enabled.

- [ ] **Step 4: Rework `AppModel` around one current conversation**

`submit()` appends the user message, clears the field, captures one `ScreenContext`, streams the answer, appends the assistant message, and then lets the local `ScreenContext` leave scope. After the first answer, derive a fallback title immediately and make one text-only streaming request asking for a two-to-six-word topic title; clean quotes and line breaks before saving. Subsequent prompts include stored text messages but capture a new screen context.

- [ ] **Step 5: Run focused and full tests**

Expected: new tests and existing provider/SSE tests pass.

- [ ] **Step 6: Commit**

```bash
git add ScreenSage/Provider ScreenSage/Overlay/AppModel.swift ScreenSageTests/ScreenSageTests.swift
git commit -m 'feat: add multi-turn screen conversations'
```

### Task 3: Adaptive Gemini-Style Overlay

**Files:**
- Create: `ScreenSage/Overlay/PanelDragArea.swift`
- Modify: `ScreenSage/Overlay/OverlayLayout.swift`
- Modify: `ScreenSage/Overlay/OverlayView.swift`
- Modify: `ScreenSage/Overlay/OverlayAnswerView.swift`
- Modify: `ScreenSage/Overlay/OverlayPanelController.swift`
- Delete: `ScreenSage/Overlay/OverlayHeaderView.swift`
- Delete: `ScreenSage/Overlay/PromptSuggestion.swift`
- Delete: `ScreenSage/Overlay/SuggestionBarView.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Replace the interrupted height test with a failing adaptive-layout test**

```swift
func testOverlayUsesAdaptiveBarDimensions() {
    XCTAssertEqual(OverlayLayout.width, 380)
    XCTAssertEqual(OverlayLayout.collapsedHeight, 42)
    XCTAssertEqual(OverlayLayout.expandedHeight, 420)
}
```

- [ ] **Step 2: Run the test and verify RED**

Expected: compilation fails because collapsed and expanded heights do not exist.

- [ ] **Step 3: Implement the adaptive root**

Build one clipped rounded surface. In collapsed state render only the 18 pt app mark, plain single-line field, and 28 pt send arrow. When the model is working, has messages, or has an error, render `OverlayAnswerView` above the same pinned composer and use the expanded height. Add `.onExitCommand(perform: close)` and a `PanelDragArea` behind noninteractive padding.

- [ ] **Step 4: Resize the `NSPanel` upward and remove the square artifact**

Initialize at `380 × 42`. Keep the frame origin fixed while animating only its height to `420`, so content grows above the composer. Set `panel.hasShadow = false`, keep `backgroundColor = .clear`, and clip the entire SwiftUI surface to its rounded shape.

- [ ] **Step 5: Run tests and build**

Expected: adaptive dimension test passes and `xcodebuild build` succeeds.

- [ ] **Step 6: Commit**

```bash
git add -A ScreenSage/Overlay ScreenSageTests/ScreenSageTests.swift
git commit -m 'feat: replace overlay with adaptive AI bar'
```

### Task 4: History Window and Menu Bar Flow

**Files:**
- Create: `ScreenSage/Conversation/HistoryView.swift`
- Create: `ScreenSage/App/MenuBarContentView.swift`
- Modify: `ScreenSage/App/AppRuntime.swift`
- Modify: `ScreenSage/App/ScreenSageApp.swift`
- Modify: `ScreenSage/Settings/SettingsView.swift`

- [ ] **Step 1: Wire shared history ownership**

Create one `ChatHistoryStore` in `AppRuntime`, inject it into `AppModel`, and make `OverlayPanelController.hide()` finish and save the active text conversation before clearing it. Showing after a hide always calls `startNewConversation()`.

- [ ] **Step 2: Add native History and menu scenes**

Add a `Window("History", id: "history")` containing a `NavigationSplitView`: newest-first conversation titles/dates on the left and user/assistant text on the right. Add `MenuBarContentView` with New Chat, History, Settings, and Quit. Keep Settings accessible with the standard `⌘,` command.

- [ ] **Step 3: Update privacy copy**

State that screenshots and OCR are transient request context, while prompt/response text is stored locally in Application Support.

- [ ] **Step 4: Build and manually verify menu actions**

Expected: History and Settings open as normal macOS windows; New Chat presents a reset pill.

- [ ] **Step 5: Commit**

```bash
git add ScreenSage/App ScreenSage/Conversation/HistoryView.swift ScreenSage/Settings/SettingsView.swift
git commit -m 'feat: expose local chat history'
```

### Task 5: Final Verification in Xcode

- [ ] **Step 1: Run the full suite**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass.

- [ ] **Step 2: Run a clean build and hygiene checks**

```bash
xcodebuild build -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: build succeeds and the diff check prints nothing.

- [ ] **Step 3: Run in Xcode with Computer Use**

Verify the actual panel is `380 × 42`, contains no suggestion/header controls, has no square background corners, expands upward after submission, and keeps the composer at the bottom. Verify the shortcut/close paths start a fresh chat and History contains text only.

- [ ] **Step 4: Leave the verified app running**

Run `git status --short` and expect a clean worktree on `main`, with Screen Sage visible from the Xcode run.

