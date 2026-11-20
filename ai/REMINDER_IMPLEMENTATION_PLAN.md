# Plan: Complete custom calendar reminders

## 1. Reminder configuration

- Add weekly, monthly, every-N-months and yearly recurrence to the custom reminder creation and editing screen.
- Let the user select a date and time. For every-N-months recurrence, offer intervals from 1 through 12 months.
- Show a clear schedule summary and retain editing, disabling and deletion.

## 2. Persistence and calculation

- Persist the recurrence type, anchor date, selected day and interval with the reminder, while preserving compatibility with existing reminders.
- Calculate occurrences in the application's active calendar, Persian or Gregorian.
- If the chosen day does not exist in a month, clamp that occurrence to the last day of the month without changing the original day used for subsequent occurrences.
- Recalculate and reschedule reminders when the application calendar changes.

## 3. Actual notification scheduling

- Connect persisted reminder settings to notification scheduling, not just date calculation.
- Arrange renewal of future occurrences without requiring the app to be open.
- Handle device reboot, timezone changes, editing, deletion and disabling.
- Check operating-system permissions and restrictions, and clearly communicate when notifications are blocked.

## 4. Verification and delivery

- Add automated tests for persistence and restoration, Persian and Gregorian calculations, short months and leap years, calendar changes, editing and cancellation.
- Run CI checks and build Android where possible; explicitly record anything that cannot be run in the available environment.
- Provide the user with concrete device or emulator test steps, including testing while the app is closed and after reboot. The user has offered to perform device tests.
- Document changes and commit and push to the active branch. Declare the work complete only when the path from creating a reminder to receiving its notification has been implemented, not merely when calculation utilities or tests exist.

## Current status

The calendar calculation and standalone schedule model exist, but monthly and yearly schedules are not yet connected to the editor, persistence or notification scheduling. The feature is not complete or ready for end-to-end device testing.
