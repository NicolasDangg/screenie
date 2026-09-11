# Overlay New Chat and Thinking Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compact new-chat control, context-aware breathing loading text, and consistent pill-end panel corners.

**Architecture:** Keep panel actions and geometry in `OverlayView` and `OverlayLayout`. Pass the existing screenshot-inclusion state into `OverlayAnswerView`, where a native SwiftUI timeline animates only the context-free loading label; reuse `AppModel.startNewConversation()` for all reset and cancellation behavior.

**Tech Stack:** Swift 6, SwiftUI, Observation, XCTest, Xcode 26

---

### Task 1: Lock the loading and geometry behavior with focused regressions

**Files:**
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Extend the layout regression and add loading-label coverage**

Update `testOverlayUsesAdaptiveBarDimensions()` and add `testOverlayLoadingLabelMatchesScreenContext()`:

```swift
func testOverlayUsesAdaptiveBarDimensions() {
    XCTAssertEqual(OverlayLayout.width, 304)
    XCTAssertEqual(OverlayLayout.collapsedHeight, 37.8)
    XCTAssertEqual(OverlayLayout.expandedHeight, 378)
    XCTAssertEqual(OverlayLayout.taskHeight, 480)
    XCTAssertEqual(OverlayLayout.controlDiameter, 25.2)
    XCTAssertEqual(OverlayLayout.cornerRadius, OverlayLayout.collapsedHeight / 2)
}

func testOverlayLoadingLabelMatchesScreenContext() {
    XCTAssertEqual(
        OverlayAnswerView.loadingLabel(includesScreenContext: true),
        "Reading screen…"
    )
    XCTAssertEqual(
        OverlayAnswerView.loadingLabel(includesScreenContext: false),
        "Thinking..."
    )
}
```

Add `includesScreenContext: true` to the existing `OverlayAnswerView` construction in `testStreamingResponseAvoidsLaTeXRendererUntilCompletion()`:

```swift
let body = OverlayAnswerView(
    messages: [],
    streamingResponse: #"Still streaming \(x^2\)"#,
    errorMessage: "",
    isWorking: true,
    includesScreenContext: true
).body
```

- [ ] **Step 2: Run the two focused checks and verify they fail for the missing API**

Run:

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ScreenSageTests/ScreenSageTests/testOverlayUsesAdaptiveBarDimensions \
  -only-testing:ScreenSageTests/ScreenSageTests/testOverlayLoadingLabelMatchesScreenContext
```

Expected: build failure because `OverlayLayout.controlDiameter`, `OverlayLayout.cornerRadius`, `OverlayAnswerView.includesScreenContext`, and `OverlayAnswerView.loadingLabel` do not exist yet.

### Task 2: Implement the compact native UI changes

**Files:**
- Modify: `ScreenSage/Overlay/OverlayLayout.swift`
- Modify: `ScreenSage/Overlay/OverlayAnswerView.swift`
- Modify: `ScreenSage/Overlay/OverlayView.swift`
- Test: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Centralize the existing control diameter and pill-end radius**

Change `OverlayLayout` to:

```swift
enum OverlayLayout {
    static let width = 304.0
    static let collapsedHeight = 37.8
    static let expandedHeight = 378.0
    static let taskHeight = 480.0
    static let controlDiameter = 25.2
    static let cornerRadius = collapsedHeight / 2
}
```

- [ ] **Step 2: Add context-aware loading presentation and the breathing label**

Add `includesScreenContext`, the label selector, and the context-free loading branch to `OverlayAnswerView`:

```swift
struct OverlayAnswerView: View {
    let messages: [ChatMessage]
    let streamingResponse: String
    let errorMessage: String
    let isWorking: Bool
    let includesScreenContext: Bool

    static func loadingLabel(includesScreenContext: Bool) -> String {
        includesScreenContext ? "Reading screen…" : "Thinking..."
    }

    // Existing body and completed/streaming response rendering remain unchanged.
}
```

Replace the current loading branch with:

```swift
} else if isWorking {
    let label = Self.loadingLabel(includesScreenContext: includesScreenContext)
    if includesScreenContext {
        ProgressView(label)
            .controlSize(.small)
    } else {
        ThinkingIndicator(label: label)
    }
}
```

Add this private native indicator below `OverlayAnswerView`:

```swift
private struct ThinkingIndicator: View {
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Text(label)
                    .foregroundStyle(.secondary)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.4) / 1.4
                    let start = phase * 2 - 1

                    Text(label)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.secondary, .primary, .secondary],
                                startPoint: UnitPoint(x: start, y: 0.5),
                                endPoint: UnitPoint(x: start + 1, y: 0.5)
                            )
                        )
                }
            }
        }
        .font(.callout.weight(.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
    }
}
```

- [ ] **Step 3: Add the fixed new-chat button and apply the shared geometry**

Wrap the expanded answer view in a top-trailing `ZStack`, pass the screenshot setting through, and reuse `AppModel.startNewConversation()`:

```swift
if isExpanded {
    ZStack(alignment: .topTrailing) {
        OverlayAnswerView(
            messages: model.conversation.messages,
            streamingResponse: model.streamingResponse,
            errorMessage: model.errorMessage,
            isWorking: model.isWorking,
            includesScreenContext: model.includeScreenshotForNextMessage
        )
        .padding(.top, OverlayLayout.controlDiameter + 8)

        Button("New Chat", systemImage: "plus", action: model.startNewConversation)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: OverlayLayout.controlDiameter, height: OverlayLayout.controlDiameter)
            .background(.primary.opacity(0.08), in: .circle)
            .overlay {
                Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.8)
            }
            .help("New Chat")
            .padding(.top, 8)
            .padding(.trailing, 14.1)
    }
    Divider().opacity(0.35)
}
```

Replace both hard-coded control frames with the shared diameter:

```swift
.frame(width: OverlayLayout.controlDiameter, height: OverlayLayout.controlDiameter)
```

Replace the conditional panel radii in both the clip and border with:

```swift
cornerRadius: OverlayLayout.cornerRadius
```

- [ ] **Step 4: Run the focused checks and verify they pass**

Run the command from Task 1, Step 2.

Expected: `** TEST SUCCEEDED **` with both selected tests passing.

- [ ] **Step 5: Run the full suite and whitespace check**

Run:

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: all tests pass and `git diff --check` prints no errors.

- [ ] **Step 6: Commit only this feature’s source and test changes**

```bash
git add \
  ScreenSage/Overlay/OverlayLayout.swift \
  ScreenSage/Overlay/OverlayAnswerView.swift \
  ScreenSage/Overlay/OverlayView.swift \
  ScreenSageTests/ScreenSageTests.swift
git commit -m "feat: refine overlay chat controls"
```

### Task 3: Install and visually verify the real overlay

**Files:**
- Verify: `/Applications/screenie.app`

- [ ] **Step 1: Build, replace, and relaunch the signed app**

Run:

```bash
./scripts/install.sh
```

Expected: the Release build succeeds, `/Applications/screenie.app` is replaced, and one `screenie` process is running.

- [ ] **Step 2: Inspect the three affected states**

Launch once with `SCREENIE_MOCK_RESPONSE` for the completed-chat layout, then return to normal mode:

```bash
pkill -x screenie
mock=$'**Mock response**\n\nNew chat control inspection.'
open -n --env "SCREENIE_MOCK_RESPONSE=$mock" /Applications/screenie.app
```

Use Option–Space, submit a prompt, and verify that the plus button is fixed at the expanded panel’s top-right, clears the chat when activated, does not cover response text, and the panel uses the 18.9 pt pill-end radius. Then relaunch normally:

```bash
pkill -x screenie
open /Applications/screenie.app
```

With an existing conversation, disable screenshot/OCR for a follow-up and verify that the fixed `Thinking...` text receives a soft left-to-right breathing highlight until streaming text arrives. Re-enable screen context and verify the existing `Reading screen…` progress display remains unchanged.
