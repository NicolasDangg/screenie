# Screen Sage Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a personal macOS 26 SwiftUI overlay that captures one screenshot, performs local Vision OCR, and asks an OpenAI or OpenRouter vision model.

**Architecture:** A menu-bar SwiftUI app owns an AppKit `NSPanel` and a Carbon global hotkey. The request path creates one in-memory ScreenCaptureKit image, runs Vision OCR locally, then streams a provider response through `URLSession`; credentials remain in Keychain and no screen content is persisted.

**Tech Stack:** Swift 6.2, SwiftUI Liquid Glass, AppKit, ScreenCaptureKit, Vision, Security/Keychain, Carbon, XCTest, Xcode 26.3.

---

## File map

- `ScreenSage.xcodeproj/project.pbxproj`: macOS app and unit-test targets.
- `ScreenSage/App/ScreenSageApp.swift`: app scenes and app delegate wiring.
- `ScreenSage/App/GlobalHotKey.swift`: `⌥⌘Space` registration.
- `ScreenSage/Overlay/OverlayPanelController.swift`: floating panel lifecycle and placement.
- `ScreenSage/Overlay/OverlayView.swift`: Liquid Glass overlay, suggestions, prompt, and response.
- `ScreenSage/Overlay/AppModel.swift`: request state and one-shot orchestration.
- `ScreenSage/Capture/ScreenContextCapture.swift`: one-shot ScreenCaptureKit capture and JPEG conversion.
- `ScreenSage/Capture/VisionOCR.swift`: local Vision text recognition.
- `ScreenSage/Provider/ProviderClient.swift`: OpenAI/OpenRouter requests and SSE decoding.
- `ScreenSage/Settings/AppSettings.swift`: local preferences and Keychain access.
- `ScreenSage/Settings/SettingsView.swift`: provider, model, and API-key controls.
- `ScreenSageTests/ScreenSageTests.swift`: prompt, payload, and stream-decoding checks.

### Task 1: Create the project and prove the core test is red

- [ ] Create the Xcode project with macOS 26 app and test targets, generated Info.plist metadata, `LSUIElement = YES`, and `NSScreenCaptureUsageDescription`.
- [ ] Add `ScreenSageTests.swift` first with tests for suggestion text, provider payload shape, and SSE deltas. The wished-for API is:

```swift
XCTAssertEqual(PromptSuggestion.explain.prompt, "Explain this question")
XCTAssertEqual(ProviderRequestBuilder.openAI(...)["store"] as? Bool, false)
XCTAssertEqual(SSEDecoder.delta(from: openAIEvent, provider: .openAI), "Hello")
```

- [ ] Run:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the production types do not exist.

### Task 2: Implement local settings and provider encoding

- [ ] Add `AppSettings`, `KeychainStore`, `AIProvider`, `PromptSuggestion`, `ProviderRequestBuilder`, and `SSEDecoder` using Foundation, Security, and `URLSession` only.
- [ ] Keep the API key in Keychain; persist only provider and model strings in UserDefaults.
- [ ] Build OpenAI Responses payloads with `store: false` and OpenRouter chat-completions payloads with a base64 image URL.
- [ ] Parse only response text deltas from each provider's SSE format and reject non-2xx HTTP responses with the response body when available.
- [ ] Re-run the Task 1 command. Expected: the core unit tests pass.

### Task 3: Implement exactly-one-capture screen context

- [ ] Add `ScreenContextCapture.capture()` that resolves the display under the pointer, excludes this app from its own capture filter, calls `SCScreenshotManager.captureImage` once, and returns one in-memory JPEG plus OCR text.
- [ ] Add `VisionOCR.recognize(in:)` using one accurate `VNRecognizeTextRequest`; empty OCR is a valid result.
- [ ] Cap capture width at 2,400 pixels and JPEG quality at 0.78. Do not create a stream, timer, recording, cache, or screenshot file.
- [ ] Compile with:

```bash
xcodebuild build -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

### Task 4: Implement the overlay and request flow

- [ ] Add a borderless key-capable `NSPanel`, floating level, all-Spaces/full-screen auxiliary behavior, and pointer-display placement.
- [ ] Register `⌥⌘Space` with Carbon and open the panel with `Explain this question` focused.
- [ ] Build the SwiftUI overlay with a near-opaque base plus native `.glassEffect`, a `GlassEffectContainer`, four suggestion buttons, a multiline composer, Return-to-send, Shift-Return newline, progress/error states, and incrementally appended answer text.
- [ ] Add a menu-bar menu and settings scene. The settings scene selects OpenAI/OpenRouter, model, and saves the key to Keychain.
- [ ] Re-run all tests and the app build. Expected: both commands succeed.

### Task 5: Review, run, and verify in Xcode

- [ ] Review current SwiftUI files against the modern API, data-flow, accessibility, performance, Swift, and hygiene guidance; fix genuine issues only.
- [ ] Run fresh tests and build with Xcode 26.3.
- [ ] Open `ScreenSage.xcodeproj` in Xcode using Computer Use, run the `ScreenSage` scheme, invoke the overlay from the menu bar or shortcut, and inspect the actual rendered panel.
- [ ] Do not enter or transmit an API key during verification. Confirm the missing-key state routes to Settings and that the app does not capture until Send is pressed.
- [ ] Commit the implementation on `main`, as explicitly requested by the user.

