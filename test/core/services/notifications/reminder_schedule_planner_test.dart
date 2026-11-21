import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/services/notifications/reminder_schedule_planner.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/reminder_recurrence.dart';
import 'package:storypad/core/types/reminder_type.dart';

void main() {
  const gregorian = CalendarSystemOption.gregorian;
  const persian = CalendarSystemOption.persian;

  ReminderObject reminder({
    ReminderRecurrence recurrence = ReminderRecurrence.daily,
    bool enabled = true,
    int hour = 9,
    int minute = 0,
    List<int> weekdays = const [],
    int? intervalMonths,
    DateTime? anchorDate,
    int? anchorDay,
  }) {
    return ReminderObject(
      id: 12,
      type: ReminderType.custom,
      enabled: enabled,
      hour: hour,
      minute: minute,
      message: 'Reminder',
      weekdays: weekdays,
      recurrence: recurrence,
      intervalMonths: intervalMonths,
      anchorDate: anchorDate,
      anchorDay: anchorDay,
    );
  }

  group('daily and weekly', () {
    test('daily picks today when the time is still ahead, tomorrow otherwise', () {
      final daily = reminder();

      expect(
        ReminderSchedulePlanner.nextOccurrence(daily, system: gregorian, now: DateTime(2024, 1, 1, 8)),
        DateTime(2024, 1, 1, 9),
      );
      expect(
        ReminderSchedulePlanner.nextOccurrence(daily, system: gregorian, now: DateTime(2024, 1, 1, 9)),
        DateTime(2024, 1, 2, 9),
      );
      expect(
        ReminderSchedulePlanner.nextOccurrence(daily, system: gregorian, now: DateTime(2024, 1, 1, 10)),
        DateTime(2024, 1, 2, 9),
      );
    });

    test('weekly chooses the nearest selected weekday', () {
      final weekly = reminder(recurrence: ReminderRecurrence.weekly, weekdays: [1, 3]);

      expect(
        ReminderSchedulePlanner.nextOccurrence(weekly, system: gregorian, now: DateTime(2024, 1, 1, 10)),
        DateTime(2024, 1, 3, 9),
        reason: 'Monday 2024-01-01 has already passed its time, so Wednesday is next',
      );
      expect(
        ReminderSchedulePlanner.nextOccurrence(weekly, system: gregorian, now: DateTime(2024, 1, 1, 8)),
        DateTime(2024, 1, 1, 9),
      );
      expect(
        ReminderSchedulePlanner.nextOccurrence(weekly, system: gregorian, now: DateTime(2024, 1, 3, 10)),
        DateTime(2024, 1, 8, 9),
      );
    });
  });

  group('calendar recurrences', () {
    test('monthly clamps a short month and restores the chosen day afterwards', () {
      final monthly = reminder(
        recurrence: ReminderRecurrence.monthly,
        intervalMonths: 1,
        anchorDate: DateTime(2024, 1, 31),
        anchorDay: 31,
      );

      final occurrences = ReminderSchedulePlanner.calendarOccurrences(
        monthly,
        system: gregorian,
        now: DateTime(2024, 1, 31, 9),
        limit: 4,
      );

      expect(occurrences.map((o) => o.at).toList(), [
        DateTime(2024, 2, 29, 9),
        DateTime(2024, 3, 31, 9),
        DateTime(2024, 4, 30, 9),
        DateTime(2024, 5, 31, 9),
      ]);
      expect(occurrences.map((o) => o.slot).toList(), [0, 1, 2, 3]);
    });

    test('every N months skips the months in between', () {
      final quarterly = reminder(
        recurrence: ReminderRecurrence.monthly,
        intervalMonths: 3,
        anchorDate: DateTime(2024, 1, 31),
        anchorDay: 31,
      );

      final occurrences = ReminderSchedulePlanner.calendarOccurrences(
        quarterly,
        system: gregorian,
        now: DateTime(2024, 1, 31, 9),
        limit: 3,
      );

      expect(occurrences.map((o) => o.at).toList(), [
        DateTime(2024, 4, 30, 9),
        DateTime(2024, 7, 31, 9),
        DateTime(2024, 10, 31, 9),
      ]);
    });

    test('yearly keeps the day and clamps a leap day', () {
      final yearly = reminder(
        recurrence: ReminderRecurrence.yearly,
        intervalMonths: 12,
        anchorDate: DateTime(2024, 2, 29),
        anchorDay: 29,
      );

      final occurrences = ReminderSchedulePlanner.calendarOccurrences(
        yearly,
        system: gregorian,
        now: DateTime(2024, 2, 29, 9),
        limit: 4,
      );

      expect(occurrences.map((o) => o.at).toList(), [
        DateTime(2025, 2, 28, 9),
        DateTime(2026, 2, 28, 9),
        DateTime(2027, 2, 28, 9),
        DateTime(2028, 2, 29, 9),
      ]);
    });

    test('a Persian yearly reminder follows Esfand and clamps in a non-leap year', () {
      // 30 Esfand 1403 = 2025-03-20 (1403 is a leap year).
      final yearly = reminder(
        recurrence: ReminderRecurrence.yearly,
        intervalMonths: 12,
        anchorDate: DateTime(2025, 3, 20),
        anchorDay: 30,
      );

      final occurrences = ReminderSchedulePlanner.calendarOccurrences(
        yearly,
        system: persian,
        now: DateTime(2025, 3, 20, 9),
        limit: 2,
      );

      expect(occurrences.map((o) => o.at).toList(), [
        DateTime(2026, 3, 20, 9),
        DateTime(2027, 3, 20, 9),
      ]);
    });

    test('switching the active calendar re-anchors the same day number', () {
      final yearly = reminder(
        recurrence: ReminderRecurrence.yearly,
        intervalMonths: 12,
        anchorDate: DateTime(2024, 3, 20),
        anchorDay: 1,
      );

      expect(
        ReminderSchedulePlanner.nextOccurrence(yearly, system: persian, now: DateTime(2024, 3, 20, 9)),
        DateTime(2025, 3, 21, 9),
      );
      expect(
        ReminderSchedulePlanner.nextOccurrence(yearly, system: gregorian, now: DateTime(2024, 3, 20, 9)),
        DateTime(2025, 3, 1, 9),
      );
    });

    test('a disabled reminder and an unusable anchor schedule nothing', () {
      final disabled = reminder(
        recurrence: ReminderRecurrence.monthly,
        intervalMonths: 1,
        anchorDate: DateTime(2024, 1, 31),
        anchorDay: 31,
        enabled: false,
      );
      final missingAnchor = reminder(recurrence: ReminderRecurrence.monthly, intervalMonths: 1);

      expect(
        ReminderSchedulePlanner.calendarOccurrences(disabled, system: gregorian, now: DateTime(2024, 1, 31, 9)),
        isEmpty,
      );
      expect(ReminderSchedulePlanner.nextOccurrence(disabled, system: gregorian, now: DateTime(2024)), isNull);
      expect(
        ReminderSchedulePlanner.calendarOccurrences(missingAnchor, system: gregorian, now: DateTime(2024, 1, 31, 9)),
        isEmpty,
      );
    });
  });

  group('legacy records', () {
    test('a record without a recurrence keeps its weekday schedule', () {
      final legacyWeekly = ReminderObject(
        id: 3,
        type: ReminderType.custom,
        hour: 9,
        minute: 0,
        message: 'Legacy',
        weekdays: const [2],
      );

      expect(legacyWeekly.recurrence, isNull);
      expect(legacyWeekly.effectiveRecurrence, ReminderRecurrence.weekly);
      expect(
        ReminderSchedulePlanner.nextOccurrence(legacyWeekly, system: gregorian, now: DateTime(2024, 1, 1, 10)),
        DateTime(2024, 1, 2, 9),
      );
    });
  });
}
