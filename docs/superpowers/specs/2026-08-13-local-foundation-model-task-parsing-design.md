# Local Foundation Model Task Parsing Design

## Goal

Use Apple's on-device Foundation Models framework to understand natural-language entries submitted as `/task <entry>`, without adding App Intents, Siri UI, network requests, screenshots, or OCR.

## Design

`AppModel` keeps recognizing `/task` before the normal AI request flow. `/task` alone opens the task manager. When text follows the command, `AppModel` starts an asynchronous local parse and shows a compact progress indicator in the existing task list.

A small task parser uses `SystemLanguageModel.default` and guided generation to request three fields: a nonempty title, an optional ISO 8601 due date, and notes only when explicitly present in the user's entry. Its instructions include the current local date, time, and time zone so relative phrases such as “tomorrow afternoon” and “in two hours” resolve consistently.

The generated result is validated before it becomes a `ScreenieTask`. If Apple Intelligence is disabled, unsupported, still downloading, or generation fails, parsing falls back to the existing deterministic `TaskEntryParser`. Cancellation remains cancellation rather than creating a fallback task.

Successful tasks continue through `TaskStore.add`, preserving the current atomic JSON persistence, recovery history, sorting, and EventKit Calendar synchronization. Parse errors appear in the existing inline task error area.

## Scope

- Change only `/task <entry>` natural-language creation.
- Keep the manual add form structured and unchanged.
- Keep the deterministic parser as an offline compatibility fallback.
- Do not expose Screenie through Siri or Shortcuts and do not add App Intents.
- Do not call OpenRouter or OpenAI for task parsing.

## Testing

- Verify generated fields are converted into a validated `ScreenieTask` and malformed model dates are rejected.
- Inject an asynchronous parser into `AppModel` tests to verify loading, successful creation, and inline errors without invoking the real system model.
- Retain the existing deterministic parser tests to cover the fallback behavior.
- Run the focused tests, full macOS test suite, signed install, and a visual check of the task progress state.
