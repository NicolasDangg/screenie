# Task manager

## Open and add tasks

- Press **Option–Command–Space** to toggle the task screen.
- Enter `/task` in Screenie’s normal input bar to open the task screen.
- Enter `/task <task>` to add and open it, for example:

  ```text
  /task phys homework unit 3 due on next tue
  ```

Supported due phrases are `today`, `tomorrow`, `next <weekday>`, a weekday name, and `yyyy-MM-dd`, introduced by `due`, `due on`, or `by`. Entries without a due phrase become undated tasks.

Tasks are saved immediately in `~/Library/Application Support/ScreenSage/tasks.json`, including their completion state and timestamps. Completed tasks remain available after relaunch and can always be restored.

## Views and controls

The header’s calendar/list button switches between the due-date-sorted list and a native month calendar. Select a calendar date to see tasks due that day. The sparkle button returns to the normal Screenie input.

In list mode, select the circle beside a task to toggle completion. The title becomes secondary gray and the strike animates left-to-right; Reduce Motion disables the spatial animation.

The footer’s **Add task** button opens the native grouped editor for title, due date/time, and notes. **Schedule hint** sends incomplete task titles and due dates, the current time zone, and the configured self-study periods to OpenRouter. It does not capture or send the screen.

## History and Apple Calendar

Open **History** from the menu-bar item, then switch from **Conversations** to **Tasks**. Active and completed tasks have separate sections; select a completed task and choose **Restore Task** to recover it.

Dated tasks automatically create or update a 30-minute event in the default writable Apple Calendar. Screenie requests full Calendar access on the first sync. Completing a task adds `✓ ` to the event title; restoring it removes the prefix. Undated tasks stay local. If Calendar access or an update fails, the task remains safely saved in Screenie and the History detail shows the sync error.

## UI mockup specification

- Panel: existing 304 × 378 pt Screenie glass panel, 20 pt expanded corner radius.
- Header: 42 pt tall, 14 pt horizontal inset, system headline, trailing list/calendar and return controls.
- Task rows: 12 pt horizontal and 8 pt vertical inset, 26 pt completion-control column, native body/caption styles, separators inset 42 pt from the leading edge.
- Footer: 43 pt tall, 14 pt horizontal inset, plain native buttons.
- Add sheet: 380 × 310 pt grouped native form with a 20 pt outer inset.
- Colors and typography: semantic system styles only; no custom font or fixed text size.

These measurements adapt the dense date hierarchy, flat rows, and restrained separators of Itsycal while retaining Screenie’s existing glass shell.

## OpenRouter JSON schema

The non-streaming Chat Completions request uses `response_format.type = json_schema`, `strict = true`, `additionalProperties = false`, and provider parameter enforcement. The decoded content is:

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

Every field is required. Screenie rejects empty summaries, empty task titles or notes, unknown schema properties, invalid ISO 8601 timestamps, and blocks whose end is not after their start.

## Network-free visual verification

`SCREENIE_MOCK_SCHEDULE` accepts the inner JSON object above for a single launch. It bypasses only schedule networking and is not a user setting:

```bash
mock='{"summary":"Two blocks fit before Tuesday.","suggestions":[{"taskTitle":"Physics","start":"2026-08-17T10:45:00Z","end":"2026-08-17T11:30:00Z","note":"Use Period 4."}]}'
open -n --env "SCREENIE_OPEN_TASKS=1" --env "SCREENIE_MOCK_SCHEDULE=$mock" /Applications/screenie.app
```

`SCREENIE_OPEN_TASKS=1` opens task mode on launch for UI automation. Neither environment hook persists.
