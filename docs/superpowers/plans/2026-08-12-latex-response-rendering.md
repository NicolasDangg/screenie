# LaTeX Response Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render common inline and display LaTeX delimiters in assistant responses while preserving the existing prompt, history, and Markdown behavior.

**Architecture:** Add the local Swift Package dependency `LaTeXSwiftUI` 2.x and wrap its `LaTeX` view in one focused `AssistantResponseText` component. Use that component only for assistant and streaming text; user messages keep the current native `AttributedString` renderer.

**Tech Stack:** Swift 6, SwiftUI, XCTest, LaTeXSwiftUI 2.x, MathJaxSwift bundled through Swift Package Manager

---

### Task 1: Add a failing response-renderer integration test

**Files:**
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Write the failing test**

Add this test to `ScreenSageTests`:

```swift
@MainActor
func testAssistantResponseBuildsAllCommonLaTeXDelimiters() {
    let source = #"Inline $x^2$ and \(y^2\). Display $$\frac{1}{2}$$ and \[E=mc^2\]. Literal \$5; unmatched $source."#
    let response = AssistantResponseText(text: source)

    XCTAssertEqual(response.text, source)
    _ = response.body
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' -only-testing:ScreenSageTests/ScreenSageTests/testAssistantResponseBuildsAllCommonLaTeXDelimiters
```

Expected: build failure because `AssistantResponseText` does not exist.

### Task 2: Add the local LaTeX renderer and connect assistant output

**Files:**
- Modify: `ScreenSage.xcodeproj/project.pbxproj`
- Create: `ScreenSage/Overlay/AssistantResponseText.swift`
- Modify: `ScreenSage/Overlay/OverlayAnswerView.swift`
- Generated: `ScreenSage.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **Step 1: Add LaTeXSwiftUI through Swift Package Manager**

Add `https://github.com/colinc86/LaTeXSwiftUI.git` with the `upToNextMajorVersion` requirement starting at `2.0.0`, then link its `LaTeXSwiftUI` product to the `ScreenSage` app target. Let Xcode resolve and record the transitive local renderer dependencies in `Package.resolved`.

- [ ] **Step 2: Create the assistant renderer**

Create `ScreenSage/Overlay/AssistantResponseText.swift`:

```swift
import LaTeXSwiftUI
import SwiftUI

struct AssistantResponseText: View {
    let text: String

    var body: some View {
        LaTeX(text)
            .parsingMode(.onlyEquations)
            .blockMode(.blockViews)
            .errorMode(.original)
            .processEscapes()
            .renderingStyle(.original)
    }
}
```

This uses the package's local mixed-text parser, preserves malformed input with `.errorMode(.original)`, keeps source visible during asynchronous rendering, and horizontally scrolls oversized display equations through `.blockViews`.

- [ ] **Step 3: Route only assistant output through the renderer**

In `OverlayAnswerView`, replace each message's direct `renderedText` call with a role-aware `Group`:

```swift
Group {
    if message.role == .assistant {
        AssistantResponseText(text: message.text)
    } else {
        renderedText(message.text)
    }
}
```

Replace the streaming response's `renderedText(streamingResponse)` with:

```swift
AssistantResponseText(text: streamingResponse)
```

Keep all existing selection, padding, background, alignment, progress, and error modifiers unchanged.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the Task 1 command again.

Expected: `TEST SUCCEEDED` and the focused test passes.

- [ ] **Step 5: Run the complete test suite**

Run:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS'
```

Expected: `TEST SUCCEEDED` with no failing tests.

- [ ] **Step 6: Commit the implementation**

```bash
git add ScreenSage.xcodeproj ScreenSage/Overlay/AssistantResponseText.swift ScreenSage/Overlay/OverlayAnswerView.swift ScreenSageTests/ScreenSageTests.swift
git commit -m "feat: render LaTeX in assistant responses"
```

### Task 3: Verify the packaged app visually

**Files:**
- No source changes expected

- [ ] **Step 1: Build and install the Release app**

Run:

```bash
./scripts/install.sh
```

Expected: `BUILD SUCCEEDED`, followed by one running `/Applications/screenie.app` process.

- [ ] **Step 2: Launch a removable math mock response**

Quit the installed process and launch it with a temporary response:

```bash
mock='The quadratic formula solves **every** equation $ax^2+bx+c=0$.\n\n$$x=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}$$\n\nInline forms also work: \\(E=mc^2\\).'
pkill -x screenie 2>/dev/null || true
open -n --env "SCREENIE_MOCK_RESPONSE=$mock" /Applications/screenie.app
```

Toggle with Option–Space, enter `Explain this equation`, and press Return. Verify bold Markdown remains styled, inline formulas align with prose, the display fraction is centered and legible, and the panel width is unchanged.

- [ ] **Step 3: Restore normal launch mode**

Quit the mock process and reopen without the environment variable:

```bash
pkill -x screenie 2>/dev/null || true
open /Applications/screenie.app
```

Expected: mock mode is off and exactly one normal screenie process remains.
