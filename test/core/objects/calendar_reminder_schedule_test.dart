import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/calendar_reminder_schedule.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

void main() {
  test('round trips without changing the chosen day after a short month', () {
    final original = CalendarReminderSchedule(anchor: DateTime(2024, 1, 31), day: 31, intervalMonths: 1);
    final restored = CalendarReminderSchedule.tryFromJson(original.toJson())!;
    expect(restored.next(system: CalendarSystemOption.gregorian, after: DateTime(2024, 1, 31, 9), hour: 9, minute: 0),
        DateTime(2024, 2, 29, 9));
    expect(restored.next(system: CalendarSystemOption.gregorian, after: DateTime(2024, 2, 29, 9), hour: 9, minute: 0),
        DateTime(2024, 3, 31, 9));
  });

  test('follows the active calendar and preserves the numeric day', () {
    final schedule = CalendarReminderSchedule(anchor: DateTime(2024, 3, 20), day: 1, intervalMonths: 12);
    expect(schedule.next(system: CalendarSystemOption.persian, after: DateTime(2024, 3, 20, 9), hour: 9, minute: 0),
        DateTime(2025, 3, 21, 9));
    expect(schedule.next(system: CalendarSystemOption.gregorian, after: DateTime(2024, 3, 20, 9), hour: 9, minute: 0),
        DateTime(2025, 3, 1, 9));
  });

  test('rejects missing, invalid and impossible stored values', () {
    expect(CalendarReminderSchedule.tryFromJson(null), isNull);
    expect(CalendarReminderSchedule.tryFromJson({}), isNull);
    expect(CalendarReminderSchedule.tryFromJson({
      'anchor_year': 2025, 'anchor_month': 2, 'anchor_day': 30, 'day': 1, 'interval_months': 1,
    }), isNull);
    expect(CalendarReminderSchedule.tryFromJson({
      'anchor_year': 2025, 'anchor_month': 2, 'anchor_day': 28, 'day': 1, 'interval_months': 0,
    }), isNull);
    expect(() => CalendarReminderSchedule(anchor: DateTime(2025), day: 32, intervalMonths: 1), throwsArgumentError);
  });
}
