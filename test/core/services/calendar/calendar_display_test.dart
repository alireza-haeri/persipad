import 'dart:ui' show Locale;

// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/objects/search_filter_object.dart';
import 'package:storypad/core/objects/stats/stats_range.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/first_day_of_week_option.dart';
import 'package:storypad/core/types/path_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting();
  });

  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  // 2026-11-15 is 24 Aban 1405, the day this feature was written.
  final november15 = DateTime(2026, 11, 15);

  group('Gregorian mode', () {
    test('reads the date as stored', () {
      expect(CalendarDisplay.yearOf(november15), 2026);
      expect(CalendarDisplay.monthOf(november15), 11);
      expect(CalendarDisplay.dayOf(november15), 15);
    });

    test('a month range is the calendar month', () {
      final range = CalendarDisplay.rangeOfMonth(2026, 11);
      expect(range.start, DateTime(2026, 11, 1));
      expect(range.end, DateTime(2026, 11, 30));
    });

    test('a year filter is the plain storage year', () {
      expect(CalendarDisplay.yearsFilter([2026]), {
        'years': [2026],
      });
      expect(CalendarDisplay.displayYearsOf([2026]), [2026]);
      expect(CalendarDisplay.displayYearsCovering(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), [2026]);
    });

    test('previousMonth wraps inside the year', () {
      expect(CalendarDisplay.previousMonth(2026, 11), (year: 2026, month: 10));
      expect(CalendarDisplay.previousMonth(2026, 1), (year: 2025, month: 12));
    });

    test('a year touches exactly one Gregorian year', () {
      expect(CalendarDisplay.gregorianYearsOfYear(2026), [2026]);
    });
  });

  group('Shamsi mode', () {
    setUp(() => CalendarConfig.apply(system: CalendarSystemOption.persian));

    test('reads the date in the Solar Hijri calendar', () {
      expect(CalendarDisplay.yearOf(november15), 1405);
      expect(CalendarDisplay.monthOf(november15), 8);
      expect(CalendarDisplay.dayOf(november15), 24);
    });

    test('a year filter becomes Gregorian years plus exact day ranges', () {
      final filters = CalendarDisplay.yearsFilter([1405]);

      // 1405 runs 21 Mar 2026 … 20 Mar 2027, so the column can only narrow the
      // scan; the day ranges are what make the filter exact.
      expect(filters['years'], [2026, 2027]);
      expect(filters['date_ranges'], [
        [DateTime(2026, 3, 21), DateTime(2027, 3, 20)],
      ]);
    });

    test('display years are derived from the Gregorian years that hold stories', () {
      // Every Shamsi year starts in March, so one Gregorian year touches two.
      expect(CalendarDisplay.displayYearsOf([2026]), [1405, 1404]);
      expect(CalendarDisplay.displayYearsCovering(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), [1404, 1405]);
      expect(CalendarDisplay.displayYearsCovering(DateTime(2026, 11, 15)), [1405]);
    });

    test('previousMonth stays inside twelve months of the display calendar', () {
      expect(CalendarDisplay.previousMonth(1405, 8), (year: 1405, month: 7));
      expect(CalendarDisplay.previousMonth(1405, 1), (year: 1404, month: 12));
    });

    test('a range filter scopes to exact days and keeps the throwback fields', () {
      final start = CalendarDisplay.firstDayOfMonth(1405, 8);
      final end = CalendarDisplay.lastDayOfMonth(1405, 8);
      final filter = DateRangeFilterObject(
        start: start,
        end: end,
        years: CalendarDisplay.displayYearsCovering(start, end).toSet(),
        types: {PathType.docs},
      );

      final filters = filter.toDatabaseFilter()!;
      expect(filters['date_range'], [DateTime(2026, 10, 23), DateTime(2026, 11, 21)]);
      // The display year 1405 touches 2026 and 2027; the exact range is what makes
      // the filter right, `years` only narrows the index scan.
      expect(filters['years'], [2026, 2027]);
      expect((filters['date_ranges'] as List).length, 1);
    });

    test('a search filter keeps display years for the UI and storage years for the query', () {
      final filter = SearchFilterObject(years: {1405}, types: {PathType.docs}, assetId: null);

      expect(filter.years, {1405});
      final filters = filter.toDatabaseFilter()!;
      expect(filters['years'], [2026, 2027]);
      expect((filters['date_ranges'] as List).length, 1);
      expect(filters['types'], ['docs']);
    });

    test('a Shamsi month maps to the exact Gregorian day range', () {
      // 1 Aban 1405 = 23 Oct 2026, 30 Aban 1405 = 21 Nov 2026.
      final range = CalendarDisplay.rangeOfMonth(1405, 8);
      expect(range.start, DateTime(2026, 10, 23));
      expect(range.end, DateTime(2026, 11, 21));
    });

    test('a Shamsi year spans two Gregorian years', () {
      // 1405 = 21 Mar 2026 … 20 Mar 2027.
      expect(CalendarDisplay.firstDayOfYear(1405), DateTime(2026, 3, 21));
      expect(CalendarDisplay.lastDayOfYear(1405), DateTime(2027, 3, 20));
      expect(CalendarDisplay.gregorianYearsOfYear(1405), [2026, 2027]);
    });

    test('dateOf and the readers are inverses', () {
      final date = CalendarDisplay.dateOf(1405, 8, 24);
      expect(date, DateTime(2026, 11, 15));
      expect(CalendarDisplay.monthKeyOf(date), (year: 1405, month: 8));
    });

    test('isInMonth follows the display calendar, not the stored month', () {
      expect(CalendarDisplay.isInMonth(november15, 1405, 8), isTrue);
      // 15 Nov 2026 is still in Gregorian November, but not in Shamsi Aban's
      // successor month.
      expect(CalendarDisplay.isInMonth(november15, 1405, 9), isFalse);
      expect(CalendarDisplay.isInMonth(november15, 2026, 11), isFalse);
    });

    test('two dates that share a Gregorian month can share a month key', () {
      // 24 and 30 Aban 1405 are 15 and 21 Nov — same Gregorian month, and the
      // month key must still be the Shamsi one.
      expect(CalendarDisplay.monthKeyOf(november15), (year: 1405, month: 8));
      expect(CalendarDisplay.monthKeyOf(DateTime(2026, 11, 21)), (year: 1405, month: 8));
      // 22 Nov 2026 is the first day of Azar, i.e. a new month header even
      // though the Gregorian month did not change. This is exactly why the
      // story list can no longer group by `story.month`.
      expect(CalendarDisplay.monthKeyOf(DateTime(2026, 11, 22)), (year: 1405, month: 9));
    });
  });

  group('month grid', () {
    test('Gregorian grid starts on the configured first day of week', () {
      final dates = CalendarDisplay.monthGridDates(
        year: 2026,
        month: 11,
        firstDayOfWeek: DateTime.monday,
      );

      // 1 Nov 2026 is a Sunday, so a Monday-first grid opens on 26 October.
      expect(dates.first, DateTime(2026, 10, 26));
      expect(dates.first.weekday, DateTime.monday);
      expect(dates.length % DateTime.daysPerWeek, 0);
      expect(dates, contains(DateTime(2026, 11, 1)));
      expect(dates, contains(DateTime(2026, 11, 30)));
    });

    test('Shamsi grid is the Shamsi month, as real Gregorian dates', () {
      CalendarConfig.apply(
        system: CalendarSystemOption.persian,
        firstDayOfWeek: FirstDayOfWeekOption.saturday,
      );

      final dates = CalendarDisplay.monthGridDates(
        year: 1405,
        month: 8,
        firstDayOfWeek: DateTime.saturday,
      );

      // 1 Aban 1405 = 23 Oct 2026 (a Friday), so a Saturday-first grid opens on
      // 17 October and the month itself starts six cells in.
      expect(dates.first, DateTime(2026, 10, 17));
      expect(dates.first.weekday, DateTime.saturday);
      expect(dates[6], DateTime(2026, 10, 23));
      expect(dates.length, 42);

      // Every day of Aban is present, and the day numbers the picker prints come
      // from the Shamsi calendar while the dates stay Gregorian.
      final monthDays = dates.where((date) => CalendarDisplay.isInMonth(date, 1405, 8)).toList();
      expect(monthDays.length, 30);
      expect(DateFormatHelper.d(monthDays.first, const Locale('en')), '1');
      expect(DateFormatHelper.d(monthDays.last, const Locale('en')), '30');
    });

    test('a day number can be forced back to Gregorian for Gregorian grids', () {
      CalendarConfig.apply(system: CalendarSystemOption.persian);

      // The mood/period calendar still pages Gregorian months, so it must keep
      // printing the Gregorian day even in Shamsi mode.
      expect(DateFormatHelper.d(november15, const Locale('en')), '24');
      expect(DateFormatHelper.gregorianDay(november15, const Locale('en')), '15');
    });
  });

  group('DateFormatHelper in Shamsi mode', () {
    setUp(() => CalendarConfig.apply(system: CalendarSystemOption.persian));

    test('formats dates with Persian month names and digits', () {
      expect(DateFormatHelper.yMd(november15, const Locale('fa')), '۱۴۰۵/۸/۲۴');
      expect(DateFormatHelper.MMMM(november15, const Locale('fa')), 'آبان');
      // Persian months have no abbreviation: `MMM` still spells them out.
      expect(DateFormatHelper.MMM(november15, const Locale('fa')), 'آبان');
      expect(DateFormatHelper.y(november15, const Locale('fa')), '۱۴۰۵');
      expect(DateFormatHelper.d(november15, const Locale('fa')), '۲۴');
      expect(DateFormatHelper.yMMMd(november15, const Locale('fa')), '۲۴ آبان ۱۴۰۵');
    });

    test('keeps Latin digits for non-Persian languages', () {
      // The month *name* stays Persian: it is the Persian calendar, and there is
      // no transliteration table to keep in sync. Only the numerals and the
      // word order follow the UI language.
      expect(DateFormatHelper.yMd(november15, const Locale('en')), '1405/8/24');
      expect(DateFormatHelper.yMMMd(november15, const Locale('en')), 'آبان 24, 1405');
    });

    test('weekday names come from the locale, not the calendar', () {
      // 15 Nov 2026 is a Sunday in every calendar.
      expect(DateFormatHelper.E(november15, const Locale('en')).toLowerCase().startsWith('sun'), isTrue);
    });

    test('monthName answers for the active calendar', () {
      expect(DateFormatHelper.monthName(8, const Locale('fa')), 'آبان');
      expect(DateFormatHelper.gregorianMonthName(11, const Locale('en')), 'November');
    });

    test('a short month name is still the full Persian name', () {
      // Short labels are asked for by the month tabs, the stats chips and the
      // story headers. In Persian the answer is the whole word: "آبا" is a stem,
      // not a name (and آبان/آذر would both start with "آ").
      for (var month = 1; month <= 12; month++) {
        final full = DateFormatHelper.monthName(month, const Locale('fa'));
        expect(DateFormatHelper.monthName(month, const Locale('fa'), short: true), full);
      }

      expect(DateFormatHelper.monthName(8, const Locale('fa'), short: true), 'آبان');
      expect(DateFormatHelper.monthName(8, const Locale('fa'), short: true).length, greaterThan(3));
    });

    test('a stats range covers the display month, not the Gregorian one', () {
      // 15 Nov 2026 is 24 Aban 1405; Aban runs 23 Oct – 21 Nov 2026.
      final range = StatsRange.month(november15);

      expect(range.displayYear, 1405);
      expect(range.displayMonth, 8);
      expect(range.start, DateTime(2026, 10, 23));
      expect(range.end, DateTime(2026, 11, 21, 23, 59, 59, 999));
      expect(range.totalDays, 30);
      expect(range.month, 8);
      expect(range.years, {2026, 2027});
      expect(range.label(const Locale('fa')), 'آبان ۱۴۰۵');

      expect(range.previous.start, DateTime(2026, 9, 23));
      expect(range.next.start, DateTime(2026, 11, 22));
    });

    test('a stats year range starts on the display new year', () {
      final range = StatsRange.year(november15);

      expect(range.start, DateTime(2026, 3, 21));
      expect(range.end, DateTime(2027, 3, 20, 23, 59, 59, 999));
      expect(range.month, isNull);
      expect(range.previous.start, CalendarDisplay.firstDayOfYear(1404));
      expect(range.next.start, CalendarDisplay.firstDayOfYear(1406));
    });

    test('a padded day number follows the display calendar', () {
      // 24 Aban 1405, and 2 Aban 1405 (which is 24 Oct 2026) for the padding.
      expect(DateFormatHelper.dayNumber(november15, const Locale('en'), pad: 2), '24');
      expect(DateFormatHelper.dayNumber(november15, const Locale('fa'), pad: 2), '۲۴');
      expect(DateFormatHelper.dayNumber(DateTime(2026, 10, 24), const Locale('en'), pad: 2), '02');
    });

    test('a bare number uses the locale digits', () {
      expect(DateFormatHelper.number(1405, const Locale('fa')), '۱۴۰۵');
      expect(DateFormatHelper.number(1405, const Locale('en')), '1405');
    });

    test('day suffixes are dropped', () {
      expect(DateFormatHelper.getDaySuffix(24, const Locale('en')), isNull);
    });
  });

  group('DateFormatHelper in Gregorian mode', () {
    test('formats dates as before', () {
      expect(DateFormatHelper.MMMM(november15, const Locale('en')), 'November');
      expect(DateFormatHelper.gregorianMonthName(11, const Locale('en')), 'November');
      expect(DateFormatHelper.monthName(11, const Locale('en')), 'November');
      expect(DateFormatHelper.getDaySuffix(2, const Locale('en')), 'nd');
    });

    test('latin months are still abbreviated when asked to be', () {
      // Only Persian loses the abbreviation; "Aug" stays "Aug".
      expect(DateFormatHelper.monthName(8, const Locale('en'), short: true), 'Aug');
      expect(DateFormatHelper.MMM(november15, const Locale('en')), 'Nov');
    });
  });
}
