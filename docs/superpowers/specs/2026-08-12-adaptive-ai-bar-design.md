# Adaptive AI Bar Design

## Goal

Replace the current overlay card with a compact Gemini-inspired input pill that can be summoned anywhere, automatically adds a one-shot screenshot and local Vision OCR to every submitted prompt, expands upward for an ongoing conversation, and saves text-only chat history locally.

## Interface

- The collapsed overlay is a `380 × 42 pt` borderless floating pill.
- It contains only an 18 pt Screen Sage mark, a single-line “Ask about your screen” field, and a 28 pt send arrow that is enabled when the prompt is non-empty.
- There is no header, suggestion bar, plus button, voice button, model picker, shortcut label, or close button.
- `⌥⌘Space` toggles the overlay. Escape hides it. Showing the overlay focuses the field.
- The pill is draggable from its unused background and padding.
- Submitting expands the same panel upward, preserving its width and bottom edge, to a maximum height of `420 pt`.
- Conversation messages and compact progress/error feedback scroll above the composer. The composer remains pinned to the bottom.
- The panel uses one clipped native Liquid Glass rounded surface. The transparent `NSPanel` has no rectangular window shadow, preventing square corner artifacts.

## Conversation Flow

1. Showing the overlay creates a fresh in-memory conversation.
2. Return or the send arrow trims and submits the prompt.
3. ScreenCaptureKit captures one screenshot and Vision performs OCR locally.
4. The current conversation text, latest prompt, OCR text, and screenshot are sent to the configured AI provider.
5. Screenshot bytes and OCR text remain local variables only and are released after the request completes. They are never written to history.
6. The streamed assistant response appears above the composer. Further prompts repeat the one-shot capture flow and include prior text messages for context.
7. After the first assistant response, one additional text-only provider request generates a concise topic title. The title must not include the active application name.
8. Hiding the overlay persists conversations containing at least one completed exchange, then clears the overlay. The next show always starts a new chat.

## Local History

- Store one JSON file in the app’s Application Support directory.
- Persist only conversation ID, topic title, creation/update timestamps, and user/assistant message text.
- Never persist screenshots, OCR output, API keys, or provider payloads.
- Save atomically after a conversation is completed or updated.
- History is newest-first and accessible from the menu bar.

## Menu Bar and Settings

The menu bar provides:

- New Chat
- History
- Settings…
- Quit Screen Sage

`⌘,` continues to open the native Settings scene. Provider, model, and Keychain-backed API key configuration remain in Settings and never appear in the compact bar.

## Error Handling

- Missing API keys, capture failures, provider failures, and title failures do not crash or discard the draft conversation.
- Request errors render compactly above the composer.
- A title-generation failure falls back to a short title derived from the first prompt; it does not fail the conversation.
- Cancelling or hiding the overlay stops the active request before clearing state.

## Verification

- Unit-test the exact compact and expanded dimensions.
- Unit-test local history round-tripping and confirm its encoded JSON contains no screenshot/OCR fields.
- Unit-test provider payloads for prior text context plus the latest image/OCR context.
- Unit-test conversation reset and title fallback behavior.
- Build and run the native app in Xcode, then inspect the collapsed and expanded panel with Computer Use.
