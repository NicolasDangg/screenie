# Schedule Hint Calendar Actions Design

## Goal

Let the user dismiss a generated schedule hint and add all of its suggested study blocks to Apple Calendar from the hint itself.

## Interaction

The schedule hint keeps its existing summary and suggestion rows. Its header gains a native trailing close button with the accessibility label `Dismiss schedule hint`. Its bottom gains a full-width `Add to Apple Calendar` button.

Choosing Dismiss clears only the current transient hint and its Calendar-add status. Tasks remain unchanged.

Choosing Add writes every suggestion as a timed Apple Calendar event. While saving, the button shows progress and is disabled. After success it becomes `Added to Calendar` with a checkmark and remains disabled; the hint stays visible until dismissed. A failure leaves the hint and button available for retry and appears through the existing inline task error treatment.

Requesting a hint from Calendar mode switches to List mode so the result is visible. Requesting a new hint clears the previous Calendar-add status.

## Calendar mapping and safety

Each suggestion becomes an event titled `Study: <task title>`, using its suggested start and end. Notes contain the suggestion note plus a Screenie marker derived from the suggestion's existing stable identifier.

`TaskCalendarSync` reuses its EventKit store and access handling. It looks for a matching marker near the suggestion time before creating an event, so retrying or regenerating the same suggestion does not duplicate it. All changes are staged with `commit: false` and committed together once.

## Verification

Regression tests cover dismissing a hint, mapping a suggestion to a Calendar descriptor, and AppModel's injected batch-add flow. The full test suite and `git diff --check` must pass, followed by installing and visually inspecting the signed app.
