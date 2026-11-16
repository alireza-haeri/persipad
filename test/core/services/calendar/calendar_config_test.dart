import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/types/first_day_of_week_option.dart';

void main() {
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  group('CalendarConfig defaults', () {
    test('weekends default to Saturday and Sunday', () {
      expect(CalendarConfig.weekendDays, [DateTime.saturday, DateTime.sunday]);
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 14)), isTrue); // Saturday
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 15)), isTrue); // Sunday
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 13)), isFalse); // Friday
    });

    test('first day of week defaults to Monday', () {
      expect(CalendarConfig.firstDayOfWeek, FirstDayOfWeekOption.monday);
      expect(CalendarConfig.orderedWeekdays, [1, 2, 3, 4, 5, 6, 7]);
    });
  });

  group('CalendarConfig.apply', () {
    test('a Saturday-first week starts on Saturday and ends on Friday', () {
      CalendarConfig.apply(firstDayOfWeek: FirstDayOfWeekOption.saturday);

      expect(CalendarConfig.orderedWeekdays, [
        DateTime.saturday,
        DateTime.sunday,
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ]);
    });

    test('leaving weekendDays null keeps the default weekends', () {
      CalendarConfig.apply(firstDayOfWeek: FirstDayOfWeekOption.saturday);
      expect(CalendarConfig.weekendDays, CalendarConfig.defaultWeekendDays);
    });

    test('an Iranian weekend (Thursday + Friday) is honoured', () {
      CalendarConfig.apply(
        firstDayOfWeek: FirstDayOfWeekOption.saturday,
        weekendDays: [DateTime.friday, DateTime.thursday],
      );

      expect(CalendarConfig.weekendDays, [DateTime.thursday, DateTime.friday]);
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 12)), isTrue); // Thursday
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 13)), isTrue); // Friday
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 14)), isFalse); // Saturday
    });

    test('an empty set means "no weekend days" instead of the default', () {
      CalendarConfig.apply(weekendDays: []);

      expect(CalendarConfig.weekendDays, isEmpty);
      expect(CalendarConfig.isWeekend(DateTime(2026, 11, 14)), isFalse);
    });
  });

  group('CalendarConfig.normalizeWeekendDays', () {
    test('deduplicates and sorts Monday-first', () {
      expect(
        CalendarConfig.normalizeWeekendDays([DateTime.sunday, DateTime.saturday, DateTime.sunday]),
        [DateTime.saturday, DateTime.sunday],
      );
    });

    test('drops weekdays outside Monday..Sunday', () {
      expect(CalendarConfig.normalizeWeekendDays([0, 8, -1, DateTime.friday]), [DateTime.friday]);
    });

    test('null means never configured and resolves to the default pair', () {
      expect(CalendarConfig.normalizeWeekendDays(null), CalendarConfig.defaultWeekendDays);
    });
  });

  group('FirstDayOfWeekOption', () {
    test('exposes DateTime weekday numbers', () {
      expect(FirstDayOfWeekOption.monday.value, DateTime.monday);
      expect(FirstDayOfWeekOption.saturday.value, DateTime.saturday);
      expect(FirstDayOfWeekOption.sunday.value, DateTime.sunday);
      expect(FirstDayOfWeekOption.friday.value, DateTime.friday);
    });

    test('every option round-trips through fromValue', () {
      for (final option in FirstDayOfWeekOption.values) {
        expect(FirstDayOfWeekOption.fromValue(option.value), option);
      }
    });
  });
}
