# Itsycal-Inspired Weekly Task Calendar Design

## Goal

Replace the compact graphical `DatePicker` task calendar with an Itsycal-inspired month grid and weekly task agenda, add safe task deletion, and correct explicit natural-language date suffixes before persistence and Apple Calendar sync.

## Source and scope

Itsycal's MIT-licensed source and current product screenshot are the interaction and layout reference. Screenie will reimplement the relevant behavior with native SwiftUI/AppKit rather than importing Itsycal code or a dependency.

Included:

- a custom seven-column, six-row month grid with month title, previous/today/next controls, adjacent-month dates, today outline, hover/selection treatment, and up to three task dots per day;
- a weekly agenda below the grid, grouped by day in Itsycal's date-header/event-row style;
- the current week on first presentation and horizontal trackpad paging by week;
- a compact glass `+` button matching the macOS Calendar toolbar idiom;
- confirmed deletion from both list and calendar rows, followed by best-effort removal of Screenie's linked Apple Calendar event;
- deterministic correction of explicit date suffixes such as `next tue` after Foundation Models parsing.

Not included:

- displaying arbitrary Apple Calendar events inside Screenie;
- Itsycal settings, resizing controls, calendar-set selection, event editing, or location/video fields;
- a new persistence layer or third-party package.

## Layout and behavior

The task panel uses a taller task-only height while chat keeps its existing expanded size. The task manager opens in Calendar mode; the existing all-tasks list remains available from the header toggle.

The month grid uses the user's current Calendar and locale. Its 42 dates begin at the system's configured first weekday. Dates outside the displayed month are tertiary; today receives an accent outline; every date in the agenda's selected week receives a subtle accent background. Task dots use the accent color for active tasks and a secondary color for completed tasks.

The agenda includes every dated task in the selected week, including completed tasks, and groups only days containing tasks. Group headers use relative labels for Today and Tomorrow, otherwise the localized weekday, with the localized short date aligned opposite. Empty weeks show one quiet empty state. Undated tasks remain in List mode.

Selecting a grid date selects its entire week. Previous and next header controls move one month and select the week containing the first day of that month. The center Today control restores the current month and week. A horizontal two-finger trackpad gesture over the weekly agenda uses native scroll paging and changes one week per page; crossing a month boundary updates the month grid.

## Deletion and Calendar cleanup

Rows expose a trailing trash control on hover and a Delete context-menu action. Both route through one confirmation alert. On confirmation, `TaskStore` removes and atomically saves the local task first; a failed save rolls the deletion back. After a successful local save, it waits for any in-flight sync for that task and asks `TaskCalendarSync` to remove the event by stored identifier or stable task marker. Calendar cleanup failure does not resurrect the local task and is shown inline.

Completed-task history remains unchanged and restorable. Explicit deletion is permanent after confirmation.

## Natural-language date correction

Foundation Models remains responsible for flexible title, time, and notes extraction. Before returning its task, the parser checks the last two words and then the final word as explicit deterministic date suffixes through `TaskEntryParser`, anchored at 09:00 local time. A recognized suffix replaces only the generated due date. If no suffix is recognized, the model date is preserved.

This makes `physics deadline next tue` resolve to Tuesday August 18, 2026 from Thursday August 13, even when the on-device model emits Monday August 17.

## Verification

Regression coverage will verify explicit suffix reconciliation, locale-aware week/month date generation, and deletion persistence/Calendar cleanup. The full test suite and `git diff --check` must pass. The signed app will be installed and visually checked, then the one known incorrectly dated Physics task will be backed up and corrected in place so its stable Calendar link updates rather than duplicating.
