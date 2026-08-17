# Screenshot Toggle and Chat Resume Grace Period

## Goal

Let users omit screenshots from subsequent messages to reduce token usage while preserving the current conversation briefly when the overlay is hidden.

## UI

Add a circular checkbox-style button immediately to the left of the existing input field. It remains inside the current composer row and does not change the overlay width.

- Checked state: blue filled circle with a checkmark; the next eligible message captures the current display and runs Vision OCR.
- Unchecked state: outlined circle; the next eligible message sends text and conversation context without a screenshot or OCR.
- The button has a VoiceOver label that describes both the current state and the next action.
- The button is disabled while the first message has not completed, because the first message must always include a screenshot and OCR.
- The button remains disabled while a request is in progress.

The first message is always forced to include a one-shot screenshot and OCR, regardless of the control state.

## Conversation and capture flow

1. A newly created conversation starts with screenshot inclusion enabled.
2. The first submission always calls `ScreenContextCapture.capture()` once and sends both returned values to the provider.
3. After the first completed assistant response, the checkbox controls the next submission:
   - checked: capture one fresh screenshot, run OCR on it, and send both;
   - unchecked: skip capture and OCR, and pass empty/no image context to `ProviderClient`.
4. Screenshots and OCR remain request-scoped values. They are not cached, rendered into history, or written to disk.
5. A new conversation resets the control to checked.

## Overlay lifecycle grace period

Hiding the overlay suspends the in-memory conversation instead of clearing it immediately.

- On hide, cancel any active request, persist a completed conversation through the existing history store, and start a 60-second expiry task.
- If the overlay is shown again before expiry, resume the same conversation and preserve the screenshot-toggle state.
- If the 60-second task fires while the overlay remains hidden, clear the conversation and reset the toggle.
- Showing the overlay after expiry starts a new conversation.
- Explicit “New Chat” continues to persist the current completed conversation and clear immediately; it does not use the grace period.
- Re-hiding a resumed conversation starts a new 60-second grace window.

The timer is in-memory only. Existing text-only history persistence remains unchanged.

## State ownership

`AppModel` owns:

- `includeScreenshotForNextMessage`, defaulting to `true`;
- whether the first assistant response has completed;
- the suspended-conversation expiry task and its conversation identity guard;
- capture selection during `submit()`.

`OverlayView` only renders the button and invokes the model’s toggle action. `OverlayPanelController` calls model lifecycle methods on hide/show; it does not own conversation state.

Conceptual request selection:

```swift
let includeScreenshot = !hasCompletedFirstResponse || includeScreenshotForNextMessage
let context = includeScreenshot ? try await ScreenContextCapture.capture() : nil

providerClient.stream(
    ...,
    ocrText: context?.ocrText ?? "",
    imageData: context?.imageData
)
```

Conceptual resume behavior:

```swift
func prepareForPresentation() {
    if suspendedConversationIsExpired {
        startNewConversation()
    } else {
        cancelSuspensionExpiry()
    }
}
```

## Error handling

Capture and provider errors retain the existing draft/error behavior. A failed first request remains subject to the first-message capture rule on retry. Timer cancellation on resume or explicit new chat prevents an expired task from clearing a newer conversation.

## Verification

- Unit-test that the first request selection always includes capture and that checked/unchecked subsequent selections map to image/OCR versus text-only payloads.
- Unit-test that hiding suspends a conversation, reopening before expiry resumes it, and expiry causes a new conversation with the toggle checked.
- Use a short injected grace duration in tests; production remains exactly 60 seconds.
- Keep existing provider-payload, history-privacy, and overlay-layout tests passing.
- Manually verify the circular control appears to the left of the input bar, toggles visibly, and that the overlay resumes within one minute but starts fresh afterward.

## Scope exclusions

No screenshot cache, continuous capture, OCR persistence, history schema change, provider protocol change, or unrelated overlay redesign.
