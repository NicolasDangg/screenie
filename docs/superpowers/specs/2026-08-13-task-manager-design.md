# Screenie Task Manager Design

## Scope

Screenie gains an in-memory task manager inside its existing floating panel. `/task` opens it, `/task <entry>` adds a naturally phrased task, and Option–Command–Space toggles it directly. Option–Space continues to open the normal screen-question overlay.

Tasks are intentionally not persisted: the repository contract permits persistence only for conversation text metadata. Screenshots, OCR, tasks, and generated schedule hints remain outside local history.

## Interaction design

The task screen reuses the current 304-point glass panel and expanded height. Its compact presentation follows the supplied Itsycal references:

- A small header contains the “Tasks” title, a list/calendar toggle, and a return-to-chat button.
- List mode shows due-date-sorted rows separated by low-contrast horizontal rules. Undated tasks follow dated tasks.
- Each row begins with a circular completion button. Completing a task changes its title to the secondary system color and animates a strike from left to right. Reduce Motion changes the state without spatial animation.
- Calendar mode uses the native graphical macOS date picker and shows tasks for the selected day beneath it.
- The footer contains “Add task” and “Schedule hint” actions.
- “Add task” presents a native modal with title, due date/time, and notes, matching the grouped native controls in the supplied event-editor reference.
- Escape closes the panel; the panel remains draggable and retains its position.

No custom font, decorative iconography, suggestion chips, or external UI package is added.

## Command and parsing behavior

- `/task` switches the visible overlay to task mode.
- `/task phys homework unit 3 due on next tue` creates “phys homework unit 3” with the next Tuesday as its due date, then opens task mode.
- The parser supports `today`, `tomorrow`, `next <weekday>`, bare weekday names, and ISO `yyyy-MM-dd` dates after `due`, `due on`, or `by`.
- An entry without a due phrase is accepted as an undated task.
- An unrecognized explicit due phrase is rejected with an inline task-screen error rather than silently discarding text.

## Architecture and data flow

`AppModel` owns a `TaskStore` for the app session and a presentation mode (`chat` or `tasks`). Command handling routes through `AppModel.submit()`, before API-key or screen-capture validation. `OverlayView` selects the existing chat UI or `TaskManagerView`; `OverlayPanelController` continues to own all positioning and animation.

`AppRuntime` registers a second Carbon hotkey using the existing `GlobalHotKey` wrapper. Its action asks `OverlayPanelController` to show, hide, or switch to task mode.

Schedule hints use the saved OpenRouter key, regardless of which chat provider is currently selected. The request contains incomplete task titles/due dates plus the fixed self-study periods. It does not capture or transmit the screen. OpenRouter strict structured output is requested with a JSON Schema; the completed response is decoded and validated before display.

## OpenRouter response schema

```json
{
  "summary": "Short schedule overview",
  "suggestions": [
    {
      "taskTitle": "phys homework unit 3",
      "start": "2026-08-17T10:45:00+07:00",
      "end": "2026-08-17T11:30:00+07:00",
      "note": "Complete the first half during Period 4."
    }
  ]
}
```

All fields are required, unknown properties are rejected, dates use ISO 8601, task titles and notes must be nonempty, and each end must be after its start.

## Errors and testing

The task screen presents parser, missing-key, empty-task-list, provider, and invalid-JSON errors inline. An in-flight hint shows native progress UI and prevents duplicate requests.

Focused tests cover natural-language parsing, due-date ordering, completion toggling, `/task` routing, the second shortcut, OpenRouter request schema, successful decoding, invalid block rejection, and task non-persistence. Full project tests, `git diff --check`, a signed install, and Computer Use inspection cover integration and visual behavior.
