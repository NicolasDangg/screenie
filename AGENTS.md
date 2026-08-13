# screenie — Agent Context

## Product intent

screenie is a personal macOS 26 SwiftUI overlay for asking an AI about a static item on screen. It is deliberately small: one floating input bar expands upward to show the conversation, while settings and history live behind the menu-bar item.

Keep these product decisions unless the user explicitly changes them:

- Capture exactly one screenshot when a prompt is submitted; never continuously stream or poll the screen.
- Run Apple Vision OCR on that screenshot and send both the image and extracted text with the prompt.
- Do not add meeting transcription, audio recording, or screenshare-hiding/evasion behavior.
- Persist only prompts, AI responses, generated topic titles, timestamps, and task fields required for recovery and Calendar sync. Never persist screenshots, OCR text, schedule hints, or AI request payloads.
- Starting a newly presented overlay starts a new conversation; completed conversations remain in local history.
- Conversation titles contain only the topic, never the foreground application name.
- The app is for one local user. API keys are intentionally stored in `UserDefaults`, not Keychain, to avoid password prompts.

“Local-only” describes app persistence. Real AI requests still transmit the current screenshot, OCR text, prompt, and conversation context to the configured API provider.

## Current behavior

- Product name and installed bundle: `screenie.app`
- Swift module, Xcode target, project, bundle identifier, and history directory retain the older `ScreenSage` name. Do not rename these casually because it can break signing, permissions, tests, or existing history.
- Bundle identifier: `local.nicolas.ScreenSage`
- Deployment target: macOS 26.0
- Global shortcut: Option–Space
- The signed app registers itself with `SMAppService.mainApp`, launches at login with only its menu-bar item, and keeps the overlay hidden until invoked.
- Default provider: OpenRouter
- Default model: `openai/gpt-5.6-luna`
- OpenAI API is also supported. ChatGPT subscriptions are not used as API authentication.
- Overlay dimensions are centralized in `ScreenSage/Overlay/OverlayLayout.swift`.
- The overlay is a transparent, borderless floating `NSPanel` hosting SwiftUI. It can join all Spaces, appear with full-screen apps, and be dragged by its background.
- The overlay saves its x/y origin on hide and restores it on later toggles and launches when that origin remains on a connected display.
- The live glass effect comes from `NSVisualEffectView` in `LiveBackdropView`, with an adaptive SwiftUI border in `OverlayView`.
- Assistant output uses bundled `LaTeXSwiftUI` 2.x for local Markdown plus inline/display math rendering; user prompts retain native `AttributedString` Markdown.
- `/task` and Option–Command–Space open a persistent task manager. `/task <entry>` uses Apple Foundation Models locally for structured natural-language parsing, with the deterministic parser as an availability/failure fallback; it does not use App Intents or a remote provider. Dated tasks synchronize to Apple Calendar through EventKit, and completed tasks remain restorable from History.

## Request flow

1. `AppRuntime` owns shared settings, history, the overlay model, panel controller, and global hotkey.
2. `OverlayView` submits text to `AppModel.submit()`.
3. `ScreenContextCapture` checks Screen Recording access and captures the display under the pointer with ScreenCaptureKit. It excludes screenie's own application, cursor, and audio.
4. The image is scaled to at most 2400 px wide and encoded as JPEG at 0.78 quality.
5. `VisionOCR` performs accurate, language-corrected, automatically detected OCR.
6. `ProviderRequestBuilder` combines conversation messages, OCR text, and screenshot for the selected provider.
7. `ProviderClient` streams SSE deltas; `AppModel` displays them and then persists the completed text conversation.
8. The first completed answer gets a local fallback title, followed by a nonessential AI-generated 2–6 word topic title.

## Important files

- `ScreenSage/App/`: app lifecycle, menu-bar UI, and global shortcut.
- `ScreenSage/Overlay/AppModel.swift`: conversation lifecycle and submit flow.
- `ScreenSage/Overlay/OverlayPanelController.swift`: panel visibility, positioning, sizing, and animation.
- `ScreenSage/Overlay/OverlayView.swift`: glass shell and input bar.
- `ScreenSage/Overlay/OverlayAnswerView.swift`: response and Markdown rendering.
- `ScreenSage/Capture/`: one-shot ScreenCaptureKit capture and Vision OCR.
- `ScreenSage/Provider/`: OpenAI/OpenRouter payloads, networking, and SSE decoding.
- `ScreenSage/Conversation/`: message models and JSON history persistence.
- `ScreenSage/Tasks/`: task parsing, JSON persistence, task UI, schedule hints, and EventKit synchronization.
- `ScreenSage/Settings/`: provider/API-key preferences and permission status UI.
- `ScreenSageTests/ScreenSageTests.swift`: regression checks.
- `scripts/install.sh`: signed Release build, replacement of `/Applications/screenie.app`, and relaunch.

## Persistence and permissions

- History: `~/Library/Application Support/ScreenSage/history.json`
- Tasks: `~/Library/Application Support/ScreenSage/tasks.json`
- Provider/model/API keys: local `UserDefaults` preferences.
- Screen Recording is required for real requests.
- Full Calendar access is requested when the first dated task needs synchronization. Calendar failure never removes the local task.
- Accessibility and Input Monitoring are shown as optional; the Carbon global shortcut does not depend on them.
- Permission status comes from the native preflight APIs. Settings buttons deep-link to the appropriate Privacy & Security pane.
- Screen Recording grants can require restarting screenie before capture works.
- Preserve the stable signing identity and bundle identifier so macOS TCC continues to recognize the installed app.

## Build, test, and install

Run all tests:

```bash
xcodebuild test \
  -project ScreenSage.xcodeproj \
  -scheme ScreenSage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Build, replace the existing app in `/Applications`, and relaunch:

```bash
./scripts/install.sh
```

Work directly on `main` unless the user explicitly asks for a worktree. Preserve unrelated user changes in a dirty tree. Use `apply_patch` for source edits and add the smallest relevant regression test for nontrivial logic.

## Mock-response mode

Mock mode is off by default. At launch, `SCREENIE_MOCK_RESPONSE` makes every submission return that exact text synchronously. This branch bypasses API-key validation, screenshot capture, Vision OCR, title generation, and provider networking, making it safe for visual response testing.

Enable it for one launch:

```bash
pkill -x screenie
mock=$'**Mock response**\n\nThis bypasses capture and networking.'
open -n --env "SCREENIE_MOCK_RESPONSE=$mock" /Applications/screenie.app
```

Return to normal mode:

```bash
pkill -x screenie
open /Applications/screenie.app
```

Do not turn mock mode into a permanent user setting unless requested; its current purpose is isolated UI testing.

## Change guardrails

- Prefer native SwiftUI, AppKit, ScreenCaptureKit, Vision, EventKit, Foundation, and Carbon APIs. There are no third-party dependencies.
- Keep the UI compact and avoid adding suggestion chips, mode pickers, voice controls, or decorative leading icons unless requested.
- Keep the input bar at the bottom when expanded; answers grow above it.
- Preserve text selection, keyboard focus on presentation, Escape-to-close, draggable behavior, fade visibility animation, adaptive glass, and the single-instance expectation.
- Never log or commit API keys, screenshot data, OCR text, or private conversation history.
- Before claiming completion, run the relevant focused test, the full test suite when practical, `git diff --check`, and visually inspect UI changes in the installed app when layout is affected.
