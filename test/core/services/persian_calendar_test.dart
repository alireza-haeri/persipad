import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';

void main() {
  group('PersianCalendar.fromGregorian', () {
    // Published conversion vectors (jalaali-js test data and the 1979 revolution
    // date, which every Persian calendar agrees on).
    test('matches known conversion vectors', () {
      expect(PersianCalendar.fromGregorian(2016, 4, 10), const PersianDate(1395, 1, 22));
      expect(PersianCalendar.fromGregorian(2000, 1, 1), const PersianDate(1378, 10, 11));
      expect(PersianCalendar.fromGregorian(1979, 2, 11), const PersianDate(1357, 11, 22));
      expect(PersianCalendar.fromGregorian(2021, 3, 20), const PersianDate(1399, 12, 30));
    });

    test('Nowruz lands on 1 Farvardin', () {
      // 1403 and 1404 new years, as published by the Iranian calendar.
      expect(PersianCalendar.fromGregorian(2024, 3, 20), const PersianDate(1403, 1, 1));
      expect(PersianCalendar.fromGregorian(2025, 3, 21), const PersianDate(1404, 1, 1));
    });
  });

  group('PersianCalendar.toGregorian', () {
    test('is the inverse of fromGregorian at known dates', () {
      expect(PersianCalendar.toGregorian(1395, 1, 22), DateTime(2016, 4, 10));
      expect(PersianCalendar.toGregorian(1378, 10, 11), DateTime(2000, 1, 1));
      expect(PersianCalendar.toGregorian(1403, 1, 1), DateTime(2024, 3, 20));
    });

    test('round-trips every day from 1990 to 2035', () {
      // One bad day anywhere in the range would silently shift every later date,
      // which is exactly the kind of bug that is invisible until a user notices a
      // wrong weekday. Step via `DateTime(y, m, d + 1)` rather than
      // `Duration(days: 1)` so local DST transitions (e.g. Iran 1991-05-03 ->
      // 1991-05-04 01:00) do not shift local midnight by an hour.
      var date = DateTime(1990, 1, 1);
      final end = DateTime(2036, 1, 1);

      while (date.isBefore(end)) {
        final persian = PersianCalendar.of(date);
        final back = PersianCalendar.toGregorian(persian.year, persian.month, persian.day);
        expect(back, date, reason: 'round trip failed for $date (got $persian -> $back)');
        date = DateTime(date.year, date.month, date.day + 1);
      }
    });
  });

  group('PersianCalendar leap years and month lengths', () {
    test('known leap years', () {
      expect(PersianCalendar.isLeapYear(1399), isTrue);
      expect(PersianCalendar.isLeapYear(1403), isTrue);
      expect(PersianCalendar.daysInMonth(1399, 12), 30);
      expect(PersianCalendar.daysInMonth(1403, 12), 30);
      expect(PersianCalendar.daysInMonth(1402, 12), 29);
    });

    test('first six months have 31 days, next five have 30', () {
      for (var month = 1; month <= 6; month++) {
        expect(PersianCalendar.daysInMonth(1405, month), 31);
      }
      for (var month = 7; month <= 11; month++) {
        expect(PersianCalendar.daysInMonth(1405, month), 30);
      }
    });

    test('every year is 365 or 366 days long and matches its months', () {
      for (var year = 1390; year <= 1420; year++) {
        final start = PersianCalendar.toGregorian(year, 1, 1);
        final next = PersianCalendar.toGregorian(year + 1, 1, 1);
        final total = DateTime.utc(
          next.year,
          next.month,
          next.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

        var monthTotal = 0;
        for (var month = 1; month <= 12; month++) {
          monthTotal += PersianCalendar.daysInMonth(year, month);
        }

        expect(total, monthTotal, reason: 'year $year: $total days vs months summing $monthTotal');
        expect(total == 365 || total == 366, isTrue, reason: 'year $year had $total days');
      }
    });
  });

  group('PersianCalendar formatting', () {
    test('weekdays are indexed from Saturday', () {
      expect(PersianCalendar.weekdayIndexOf(DateTime(2026, 11, 14)), 0); // Saturday
      expect(PersianCalendar.weekdayIndexOf(DateTime(2026, 11, 15)), 1); // Sunday
      expect(PersianCalendar.weekdayIndexOf(DateTime(2026, 11, 20)), 6); // Friday
      expect(PersianCalendar.weekdayName(DateTime(2026, 11, 14)), 'شنبه');
      expect(PersianCalendar.weekdayName(DateTime(2026, 11, 20)), 'جمعه');
    });

    test('month names cover all twelve months', () {
      expect(PersianCalendar.monthNames.length, 12);
      expect(PersianCalendar.monthName(1), 'فروردین');
      expect(PersianCalendar.monthName(12), 'اسفند');
      // Out-of-range input must not throw: it is fed by UI state.
      expect(PersianCalendar.monthName(0), 'فروردین');
      expect(PersianCalendar.monthName(13), 'اسفند');
    });

    test('converts digits for display', () {
      expect(PersianCalendar.toPersianDigits('1405/8/24'), '۱۴۰۵/۸/۲۴');
      expect(PersianCalendar.toPersianDigits('abc'), 'abc');
      expect(PersianCalendar.formatShort(DateTime(2024, 3, 20)), '۱۴۰۳/۱/۱');
      expect(PersianCalendar.formatShort(DateTime(2024, 3, 20), persianDigits: false), '1403/1/1');
    });
  });
}
