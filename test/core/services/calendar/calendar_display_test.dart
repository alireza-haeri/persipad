import 'dart:ui' show Locale;

// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

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

  group('DateFormatHelper in Shamsi mode', () {
    setUp(() => CalendarConfig.apply(system: CalendarSystemOption.persian));

    test('formats dates with Persian month names and digits', () {
      expect(DateFormatHelper.yMd(november15, const Locale('fa')), '۱۴۰۵/۸/۲۴');
      expect(DateFormatHelper.MMMM(november15, const Locale('fa')), 'آبان');
      expect(DateFormatHelper.MMM(november15, const Locale('fa')), 'آبا');
      expect(DateFormatHelper.y(november15, const Locale('fa')), '۱۴۰۵');
      expect(DateFormatHelper.d(november15, const Locale('fa')), '۲۴');
      expect(DateFormatHelper.yMMMd(november15, const Locale('fa')), '۲۴ آبان ۱۴۰۵');
    });

    test('keeps Latin digits for non-Persian languages', () {
      expect(DateFormatHelper.yMd(november15, const Locale('en')), '1405/8/24');
      expect(DateFormatHelper.yMMMd(november15, const Locale('en')), 'Aban 24, 1405');
    });

    test('weekday names come from the locale, not the calendar', () {
      // 15 Nov 2026 is a Sunday in every calendar.
      expect(DateFormatHelper.E(november15, const Locale('en')).toLowerCase().startsWith('sun'), isTrue);
    });

    test('monthName answers for the active calendar', () {
      expect(DateFormatHelper.monthName(8, const Locale('fa')), 'آبان');
      expect(DateFormatHelper.gregorianMonthName(11, const Locale('en')), 'November');
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
  });
}
