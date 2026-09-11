# Overlay New Chat and Thinking Indicator Design

## Scope

Make three compact changes to the chat overlay:

- Add a circular plus button at the top-right of an expanded chat. Activating it starts a new conversation through `AppModel.startNewConversation()`, including cancelling an in-flight request and restoring the default screenshot setting.
- When a follow-up request excludes screenshot and OCR context, show `Thinking...` instead of `Reading screen…` until the first response delta arrives. A soft highlight sweeps left to right across the fixed label and repeats. With Reduce Motion enabled, the label remains static.
- Use the collapsed pill end-cap radius, `OverlayLayout.collapsedHeight / 2` (18.9 pt), for the panel in collapsed, expanded-chat, and task modes.

## UI and Data Flow

`OverlayView` owns the new-chat button because it already owns panel-level controls and has access to `AppModel`. The button is visible only in an expanded chat and stays fixed while the conversation content scrolls.

`OverlayView` passes the current screenshot-inclusion state into `OverlayAnswerView`. While the request is working and no streamed response exists, `OverlayAnswerView` selects either the existing screen-reading progress label or the new context-free thinking indicator. Once the first delta arrives, the existing lightweight plain-text streaming renderer replaces the loading state.

The thinking animation uses native SwiftUI drawing and animation. It keeps the text and layout fixed, animates only its foreground highlight, and disables movement for Reduce Motion. No timer, elapsed counter, grid loader, dependency, or persisted state is added.

## Error and Cancellation Behavior

The plus button reuses `startNewConversation()`, so existing request cancellation, transient-state cleanup, and focus restoration remain the single source of truth. Existing error presentation is unchanged.

## Verification

- Add a focused regression check for selecting the correct loading presentation when screenshot/OCR context is enabled or disabled.
- Extend the layout regression check to cover the shared 18.9 pt panel radius.
- Run the focused checks, full test suite, and `git diff --check`.
- Build and install the app, then visually inspect the overlay geometry and new-chat control.
