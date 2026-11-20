import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/types/reminder_recurrence.dart';
import 'package:storypad/core/types/reminder_type.dart';

void main() {
  group('ReminderObject', () {
    test('JSON round-trip preserves all fields', () {
      final reminder = ReminderObject(
        id: 12,
        type: ReminderType.custom,
        enabled: true,
        hour: 8,
        minute: 30,
        weekdays: [1, 3, 5],
        message: 'Review ideas',
        templateId: 7,
        tagIds: [2, 4],
      );

      final restored = ReminderObject.fromJson(reminder.toJson());

      expect(restored.id, 12);
      expect(restored.type, ReminderType.custom);
      expect(restored.enabled, true);
      expect(restored.hour, 8);
      expect(restored.minute, 30);
      expect(restored.weekdays, [1, 3, 5]);
      expect(restored.message, 'Review ideas');
      expect(restored.templateId, 7);
      expect(restored.tagIds, [2, 4]);
    });

    test('unknown reminder type falls back to custom', () {
      final json = {'id': 1, 'type': 'somethingNew', 'enabled': true};
      expect(ReminderObject.fromJson(json).type, ReminderType.custom);
    });

    test('isEveryDay is true when no weekdays selected', () {
      final reminder = ReminderObject(id: 1, type: ReminderType.daily);
      expect(reminder.isEveryDay, true);
      expect(reminder.scheduleSlots, [0]);
    });

    test('scheduleSlots returns sorted unique weekdays', () {
      final reminder = ReminderObject(id: 1, type: ReminderType.daily, weekdays: [5, 1, 1, 3]);
      expect(reminder.isEveryDay, false);
      expect(reminder.scheduleSlots, [1, 3, 5]);
    });

    test('normalizeWeekdays collapses both "all 7 selected" and "none selected" to every-day', () {
      expect(ReminderObject.normalizeWeekdays([]), []);
      expect(ReminderObject.normalizeWeekdays(ReminderObject.allWeekdays), []);
      expect(ReminderObject.normalizeWeekdays([1, 2, 3, 4, 5, 6, 7, 7]), []);
      expect(ReminderObject.normalizeWeekdays([5, 1, 1, 3]), [1, 3, 5]);
    });

    test('calendar recurrence fields survive a JSON round-trip', () {
      final reminder = ReminderObject(
        id: 12,
        type: ReminderType.custom,
        hour: 7,
        minute: 15,
        message: 'Pay rent',
        recurrence: ReminderRecurrence.monthly,
        intervalMonths: 3,
        anchorDate: DateTime(2026, 1, 31),
        anchorDay: 31,
      );

      final restored = ReminderObject.fromJson(reminder.toJson());

      expect(restored.recurrence, ReminderRecurrence.monthly);
      expect(restored.intervalMonths, 3);
      expect(restored.anchorDate, DateTime(2026, 1, 31));
      expect(restored.anchorDay, 31);
      expect(restored.isCalendarRecurring, true);
      expect(restored.effectiveIntervalMonths, 3);
      expect(restored.effectiveAnchorDay, 31);
    });

    test('a record without a recurrence keeps its weekday schedule', () {
      final json = {
        'id': 1,
        'type': 'custom',
        'enabled': true,
        'hour': 9,
        'minute': 0,
        'weekdays': [1, 3],
        'message': 'Legacy',
      };

      final restored = ReminderObject.fromJson(json);
      expect(restored.recurrence, isNull);
      expect(restored.effectiveRecurrence, ReminderRecurrence.weekly);
      expect(restored.isCalendarRecurring, false);
      expect(restored.effectiveAnchorDay, isNull);
    });

    test('yearly always reports a 12-month interval', () {
      final yearly = ReminderObject(
        id: 6,
        type: ReminderType.custom,
        recurrence: ReminderRecurrence.yearly,
        anchorDate: DateTime(2024, 2, 29),
        anchorDay: 29,
      );

      expect(yearly.effectiveIntervalMonths, 12);
      expect(yearly.isCalendarRecurring, true);
    });

    test('builtin factory uses type-based id and disabled default', () {
      final daily = ReminderObject.builtin(ReminderType.daily);
      final onThisDay = ReminderObject.builtin(ReminderType.onThisDay);

      expect(daily.type, ReminderType.daily);
      expect(daily.enabled, false);
      expect(daily.id, ReminderType.daily.index + 1);
      expect(daily.hour, 21);

      expect(onThisDay.type, ReminderType.onThisDay);
      expect(onThisDay.enabled, false);
      expect(onThisDay.id, ReminderType.onThisDay.index + 1);
      expect(onThisDay.hour, 9);
    });
  });
}
