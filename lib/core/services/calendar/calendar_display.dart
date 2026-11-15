import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';
import 'package:storypad/core/services/days_count_in_month_service.dart';

/// The display calendar: the one place that turns a stored Gregorian `DateTime`
/// into the year/month/day the user sees, and a displayed month back into the
/// Gregorian date range to query.
///
/// Design rule for the whole feature (D-025): **storage and queries stay
/// Gregorian**. A story keeps its real `DateTime`, the database keeps
/// `year`/`month`/`day` columns in Gregorian, and nothing is ever rewritten when
/// the user switches calendars. Only two things happen here:
///
///  * read direction — `yearOf`/`monthOf`/`dayOf` for rendering, and
///  * write direction — `dateOf`/ranges, so a month the user picked in Shamsi
///    becomes the exact Gregorian day range the query needs.
///
/// Everything is date-only; times of day are irrelevant to the calendar and are
/// preserved by callers that care.
class CalendarDisplay {
  CalendarDisplay._();

  static bool get isPersian => CalendarConfig.system.isPersian;

  static int yearOf(DateTime date) => isPersian ? PersianCalendar.yearOf(date) : date.year;

  static int monthOf(DateTime date) => isPersian ? PersianCalendar.monthOf(date) : date.month;

  static int dayOf(DateTime date) => isPersian ? PersianCalendar.dayOf(date) : date.day;

  /// `(year, month)` of a date in the *display* calendar. This is the grouping
  /// key of the story list: two stories belong to the same displayed month iff
  /// their keys are equal, which is exactly what a month header needs (a Jalali
  /// month straddles two Gregorian months, so `story.year`/`story.month` cannot
  /// be used for that comparison).
  static ({int year, int month}) monthKeyOf(DateTime date) => (year: yearOf(date), month: monthOf(date));

  static int daysInMonth(int year, int month) {
    if (isPersian) return PersianCalendar.daysInMonth(year, month);
    return DaysCountInMonthService.get(year: year, month: month);
  }

  /// The Gregorian date for a display-calendar (year, month, day), at local
  /// midnight.
  static DateTime dateOf(int year, int month, int day) {
    if (isPersian) return PersianCalendar.toGregorian(year, month, day);
    return DateTime(year, month, day);
  }

  static DateTime firstDayOfMonth(int year, int month) => dateOf(year, month, 1);

  static DateTime lastDayOfMonth(int year, int month) => dateOf(year, month, daysInMonth(year, month));

  static DateTime firstDayOfYear(int year) => dateOf(year, 1, 1);

  static DateTime lastDayOfYear(int year) => dateOf(year, 12, daysInMonth(year, 12));

  /// Gregorian years a display year touches: at most two, because no calendar
  /// year is longer than 366 days. Used to bound DB queries, which filter on
  /// the Gregorian `year` column.
  static List<int> gregorianYearsOfYear(int year) {
    final start = firstDayOfYear(year).year;
    final end = lastDayOfYear(year).year;
    return start == end ? [start] : [start, end];
  }

  /// Inclusive Gregorian day range of a display month — the shape every DB
  /// filter and every "does this story belong to the shown month" check wants.
  static ({DateTime start, DateTime end}) rangeOfMonth(int year, int month) {
    return (start: firstDayOfMonth(year, month), end: lastDayOfMonth(year, month));
  }

  static ({DateTime start, DateTime end}) rangeOfYear(int year) {
    return (start: firstDayOfYear(year), end: lastDayOfYear(year));
  }

  /// True when [date] belongs to the displayed (year, month).
  static bool isInMonth(DateTime date, int year, int month) => yearOf(date) == year && monthOf(date) == month;

  /// The dates a month grid shows, in the display calendar: whole weeks, with
  /// the days of the neighbouring months needed to fill the first and last row.
  ///
  /// Returned as real Gregorian dates so every cell can be tapped, styled and
  /// compared like any other date. [firstDayOfWeek] is a `DateTime` weekday
  /// number (Monday = 1 … Sunday = 7).
  static List<DateTime> monthGridDates({
    required int year,
    required int month,
    required int firstDayOfWeek,
  }) {
    final first = firstDayOfMonth(year, month);
    final leading = (first.weekday - firstDayOfWeek + DateTime.daysPerWeek) % DateTime.daysPerWeek;
    final cells = ((leading + daysInMonth(year, month)) / DateTime.daysPerWeek).ceil() * DateTime.daysPerWeek;

    // Built from day offsets on a real date rather than by adding Durations, so
    // a DST transition cannot shift a cell onto the previous day.
    return List.generate(cells, (index) => DateTime(first.year, first.month, first.day + index - leading));
  }
}
