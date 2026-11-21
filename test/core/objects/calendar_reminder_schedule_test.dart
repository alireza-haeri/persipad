import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/calendar_reminder_schedule.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/reminder_recurrence.dart';
import 'package:storypad/core/types/reminder_type.dart';

void main() {
  ReminderObject reminder({
    ReminderRecurrence recurrence = ReminderRecurrence.monthly,
    int intervalMonths = 1,
    DateTime? anchorDate,
    int? anchorDay,
    List<int> weekdays = const [],
    bool enabled = true,
  }) {
    return ReminderObject(
      id: 12,
      type: ReminderType.custom,
      enabled: enabled,
      hour: 9,
      minute: 0,
      message: 'Reminder',
      recurrence: recurrence,
      intervalMonths: intervalMonths,
      anchorDate: anchorDate,
      anchorDay: anchorDay,
      weekdays: weekdays,
    );
  }

  test('reads a schedule out of a monthly reminder', () {
    final schedule = CalendarReminderSchedule.fromReminder(
      reminder(anchorDate: DateTime(2024, 1, 31), anchorDay: 31, intervalMonths: 3),
    )!;

    expect(schedule.anchor, DateTime(2024, 1, 31));
    expect(schedule.day, 31);
    expect(schedule.intervalMonths, 3);
  });

  test('yearly reminders use a 12-month interval', () {
    final schedule = CalendarReminderSchedule.fromReminder(
      reminder(recurrence: ReminderRecurrence.yearly, anchorDate: DateTime(2024, 2, 29), anchorDay: 29),
    )!;

    expect(schedule.intervalMonths, 12);
  });

  test('returns null for weekday schedules and unusable anchors', () {
    expect(
      CalendarReminderSchedule.fromReminder(
        reminder(recurrence: ReminderRecurrence.weekly, weekdays: [1], anchorDate: DateTime(2024, 1, 1), anchorDay: 1),
      ),
      isNull,
    );
    expect(CalendarReminderSchedule.fromReminder(reminder()), isNull);
  });

  test('clamps a short month without changing the chosen day', () {
    final schedule = CalendarReminderSchedule.fromReminder(
      reminder(anchorDate: DateTime(2024, 1, 31), anchorDay: 31),
    )!;

    final occurrences = schedule.upcoming(
      system: CalendarSystemOption.gregorian,
      after: DateTime(2024, 1, 31, 9),
      hour: 9,
      minute: 0,
      count: 3,
    );

    expect(occurrences, [DateTime(2024, 2, 29, 9), DateTime(2024, 3, 31, 9), DateTime(2024, 4, 30, 9)]);
    expect(schedule.day, 31, reason: 'the intended day must survive a clamped occurrence');
  });

  test('follows the active calendar and preserves the numeric day', () {
    final schedule = CalendarReminderSchedule(anchor: DateTime(2024, 3, 20), day: 1, intervalMonths: 12);

    expect(
      schedule.next(system: CalendarSystemOption.persian, after: DateTime(2024, 3, 20, 9), hour: 9, minute: 0),
      DateTime(2025, 3, 21, 9),
    );
    expect(
      schedule.next(system: CalendarSystemOption.gregorian, after: DateTime(2024, 3, 20, 9), hour: 9, minute: 0),
      DateTime(2025, 3, 1, 9),
    );
  });

  test('describeAnchor renders the intended day in the display calendar', () {
    // 30 Esfand 1403 (a leap year) is 2025-03-20.
    final schedule = CalendarReminderSchedule(anchor: DateTime(2025, 3, 20), day: 30, intervalMonths: 12);
    expect(schedule.describeAnchor(system: CalendarSystemOption.persian), DateTime(2025, 3, 20));

    // 1 Esfand 1404 is 2026-02-20; day 30 clamps to 29 Esfand = 2026-03-20.
    final clamped = CalendarReminderSchedule(anchor: DateTime(2026, 2, 20), day: 30, intervalMonths: 12);
    expect(clamped.describeAnchor(system: CalendarSystemOption.persian), DateTime(2026, 3, 20));
  });

  test('rejects an impossible schedule', () {
    expect(() => CalendarReminderSchedule(anchor: DateTime(2025), day: 32, intervalMonths: 1), throwsArgumentError);
    expect(() => CalendarReminderSchedule(anchor: DateTime(2025), day: 1, intervalMonths: 13), throwsArgumentError);
  });
}
