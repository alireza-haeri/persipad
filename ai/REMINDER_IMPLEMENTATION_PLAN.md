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

## Status — 2026-11-20, session 22 (`arena/95cdc5fd-persipad`)

Implemented end to end. Evidence and the run id are in `CHANGES.md` §Session 22 and
`PROGRESS.md`; the technical decisions are `D-068`.

| Plan item | Where it now lives |
|---|---|
| Weekly / monthly / every-N-months / yearly in the editor | `lib/views/reminders/edit_custom_reminder/` (`Repeat`, `Interval`, `Starting date`) |
| Persistence without breaking old reminders | `ReminderObject.recurrence` / `intervalMonths` / `anchorDate` / `anchorDay`; old records infer daily/weekly from `weekdays` |
| Occurrences in the active calendar, clamping short months | `lib/core/services/calendar/calendar_recurrence.dart`, `lib/core/objects/calendar_reminder_schedule.dart` |
| Reschedule when the calendar changes | `DevicePreferencesProvider.setCalendarSystem` → `LocalNotificationService.rescheduleAll` |
| Real notification scheduling + renewal | `lib/core/services/notifications/reminder_schedule_planner.dart` + `local_notification_service.dart` (24 concrete alarms per calendar reminder, replenished on start/resume/edit) |
| Reboot / time zone / edit / delete / disable | boot receiver already declared; zone change detected on resume; every write goes through `_writeReminders` → `rescheduleAll` |
| Permissions and blocked notifications | `LocalNotificationService.notificationsBlocked()` + the banner on the reminders screen + the existing denial dialog |
| Tests | `test/core/services/calendar/calendar_recurrence_test.dart`, `test/core/objects/calendar_reminder_schedule_test.dart`, `test/core/services/notifications/reminder_schedule_planner_test.dart`, `reschedule_queue_test.dart`, `reminder_object_test.dart`, `test/views/reminders/edit_custom_reminder/edit_custom_reminder_view_model_test.dart` |
| Device test steps | `PROGRESS.md` §Session 22 → "What only you can check" |

**Still not done by design:** delivery is *inexact* (no `SCHEDULE_EXACT_ALARM`), so the OS may
delay a reminder by minutes under Doze, and the calendar window is finite (24 future dates)
so an app that is never opened for years stops renewing it. Both are stated to the user in
the plan's own words rather than hidden.
