# Task Details Popover Design

## Goal

Make every task row in the list and calendar agenda clickable so the user can inspect task details and change or remove its deadline without leaving the task manager.

## Interaction

- Clicking the task's title/details area opens one native SwiftUI popover anchored to that row.
- The completion control and delete control keep their existing independent actions.
- The popover shows the task title, notes when present, completion status, creation date, completion date when present, and deadline controls.
- A deadline toggle adds or removes the deadline. Enabling it for an undated task starts at the current date and time.
- A native `DatePicker` edits both the calendar date and time.
- Edits save immediately, including when the user dismisses the popover by clicking outside it. No Done button is needed.

This follows Apple's guidance to use a popover for a small amount of related information or functionality, anchor it to the revealing element, and automatically save work when a nonmodal popover closes. It also uses SwiftUI's native `DatePicker` for date-and-time input.

## Implementation

`TaskRowView` owns the presentation state so the system can anchor the popover to the clicked row. A reusable task-details view renders the existing `ScreenieTask` fields and sends deadline changes through a closure. Both `TaskListView` and `TaskCalendarView` pass the same store-backed update action into their rows.

`TaskStore` gains one deadline update operation. It updates the task, persists atomically, rolls back on persistence failure, and then reconciles Apple Calendar:

- A changed or newly added deadline uses the existing calendar upsert path.
- Removing a deadline deletes the prior calendar event using the previous dated task and clears the stored event identifier.
- Calendar failure leaves the local edit intact and exposes an error through the existing task error UI.

No new model fields, dependencies, windows, or persistence files are needed.

## Accessibility and behavior

- The clickable task content is a real button with a descriptive accessibility label.
- Existing keyboard focus, hover, context menu, completion animation, and deletion behavior remain intact.
- SwiftUI controls provide native keyboard and VoiceOver behavior for the deadline toggle and picker.
- Only one popover can be open at a time in normal interaction, and it closes when the user clicks outside it.

## Verification

- Add one focused `TaskStore` regression test that changes a deadline, removes it, verifies persistence, and confirms the existing Calendar update/delete callbacks receive the correct task state.
- Run the focused test, the full test suite, and `git diff --check`.
- Install and visually inspect both list and calendar task rows, including adding, changing, and removing a deadline.

## References

- [Apple Human Interface Guidelines: Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers)
- [SwiftUI `popover` documentation](https://developer.apple.com/documentation/swiftui/view/popover(ispresented:attachmentanchor:arrowedge:content:))
- [SwiftUI `DatePicker` documentation](https://developer.apple.com/documentation/swiftui/datepicker)
