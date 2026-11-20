import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_recurrence.dart';
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
    expect(next(year: 2024, month: 2, day: 29, interval: 12, after: DateTime(2024, 2, 29, 9)), DateTime(2025, 2, 28, 9));
  });

  test('uses Persian months and clamps non-leap Esfand', () {
    expect(next(system: CalendarSystemOption.persian, year: 1403, month: 12, day: 30, interval: 12,
      after: DateTime(2025, 3, 20, 9)), DateTime(2026, 3, 20, 9));
    expect(next(system: CalendarSystemOption.persian, year: 1403, month: 6, day: 31,
      after: DateTime(2024, 9, 21, 9)), DateTime(2024, 10, 21, 9));
  });

  test('rejects invalid intervals and fields', () {
    expect(() => next(interval: 0, after: DateTime(2024)), throwsArgumentError);
    expect(() => next(day: 32, after: DateTime(2024)), throwsArgumentError);
  });
}
