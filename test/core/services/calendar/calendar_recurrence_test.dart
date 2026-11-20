import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_recurrence.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

void main() {
  DateTime next({
    CalendarSystemOption system = CalendarSystemOption.gregorian,
    int year = 2024,
    int month = 1,
    int day = 31,
    int interval = 1,
    required DateTime after,
  }) => CalendarRecurrence.next(
    system: system,
    anchorYear: year,
    anchorMonth: month,
    day: day,
    intervalMonths: interval,
    hour: 9,
    minute: 0,
    after: after,
  );

  test('clamps short months without changing the requested day', () {
    expect(next(after: DateTime(2024, 1, 31, 9)), DateTime(2024, 2, 29, 9));
    expect(next(after: DateTime(2024, 2, 29, 9)), DateTime(2024, 3, 31, 9));
    expect(next(year: 2025, after: DateTime(2025, 1, 31, 9)), DateTime(2025, 2, 28, 9));
  });

  test('respects interval, year boundaries and time', () {
    expect(next(day: 1, interval: 3, after: DateTime(2024, 4, 1, 8)), DateTime(2024, 4, 1, 9));
    expect(next(day: 1, interval: 3, after: DateTime(2024, 12, 31)), DateTime(2025, 1, 1, 9));
    expect(
      next(year: 2024, month: 2, day: 29, interval: 12, after: DateTime(2024, 2, 29, 9)),
      DateTime(2025, 2, 28, 9),
    );
  });

  test('uses Persian months and clamps non-leap Esfand', () {
    expect(
      next(
        system: CalendarSystemOption.persian,
        year: 1403,
        month: 12,
        day: 30,
        interval: 12,
        after: DateTime(2025, 3, 20, 9),
      ),
      DateTime(2026, 3, 20, 9),
    );
    expect(
      next(system: CalendarSystemOption.persian, year: 1403, month: 6, day: 31, after: DateTime(2024, 9, 21, 9)),
      DateTime(2024, 10, 21, 9),
    );
  });

  test('all monthly intervals stay anchored across Persian year boundaries', () {
    for (var interval = 1; interval <= 12; interval++) {
      var previous = PersianCalendar.toGregorian(1402, 11, 1).subtract(const Duration(seconds: 1));
      for (var occurrence = 0; occurrence < 30; occurrence++) {
        final result = next(
          system: CalendarSystemOption.persian,
          year: 1402,
          month: 11,
          day: 31,
          interval: interval,
          after: previous,
        );
        final actual = PersianCalendar.of(result);
        final monthIndex = 1402 * 12 + 10 + occurrence * interval;
        final year = monthIndex ~/ 12;
        final month = monthIndex % 12 + 1;
        final lastDay = PersianCalendar.daysInMonth(year, month);
        expect(actual, PersianDate(year, month, lastDay < 31 ? lastDay : 31));
        expect(result.isAfter(previous), isTrue);
        previous = result;
      }
    }
  });

  test('all intervals remain anchored across Gregorian years and leap days', () {
    for (var interval = 1; interval <= 12; interval++) {
      var previous = DateTime(2023, 11, 1);
      for (var occurrence = 0; occurrence < 30; occurrence++) {
        final result = next(year: 2023, month: 11, day: 31, interval: interval, after: previous);
        final firstDay = DateTime(2023, 11 + occurrence * interval);
        final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0).day;
        expect(result, DateTime(firstDay.year, firstDay.month, lastDay < 31 ? lastDay : 31, 9));
        expect(result.isAfter(previous), isTrue);
        previous = result;
      }
    }
  });

  test('rejects invalid intervals and fields', () {
    expect(() => next(interval: 0, after: DateTime(2024)), throwsArgumentError);
    expect(() => next(day: 32, after: DateTime(2024)), throwsArgumentError);
  });
}
