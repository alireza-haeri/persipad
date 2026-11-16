import 'dart:ui';

import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';

/// Granularity of a stats range. Prefill-only: month or year.
enum StatsRangeType { month, year }

/// A prefilled, immutable date window the stats screen is computed against.
///
/// Pick a granularity ([StatsRangeType]) and an [anchor] date, and the window
/// snaps to the containing month or year. [previous]/[next] step the anchor by
/// one unit so the UI can page through time.
///
/// [start] is inclusive at 00:00; [end] is inclusive at 23:59:59.999 of the last
/// day, so a simple `>= start && <= end` covers the whole window.
class StatsRange {
  final StatsRangeType type;

  /// Any date inside the window. The window is derived from this, not stored, so
  /// the two can never drift apart.
  final DateTime anchor;

  const StatsRange._(this.type, this.anchor);

  factory StatsRange.month(DateTime anchor) => StatsRange._(StatsRangeType.month, _dateOnly(anchor));
  factory StatsRange.year(DateTime anchor) => StatsRange._(StatsRangeType.year, _dateOnly(anchor));

  factory StatsRange.of(StatsRangeType type, DateTime anchor) {
    switch (type) {
      case StatsRangeType.month:
        return StatsRange.month(anchor);
      case StatsRangeType.year:
        return StatsRange.year(anchor);
    }
  }

  /// Year and month of the window in the *display* calendar (1405/8 in Shamsi,
  /// 2026/11 in Gregorian). [anchor] is a real date; these are the numbers the
  /// screen labels and pages with.
  int get displayYear => CalendarDisplay.yearOf(anchor);

  int get displayMonth => CalendarDisplay.monthOf(anchor);

  /// First day of the window (00:00), in the display calendar.
  DateTime get start {
    final DateTime first = switch (type) {
      StatsRangeType.month => CalendarDisplay.firstDayOfMonth(displayYear, displayMonth),
      StatsRangeType.year => CalendarDisplay.firstDayOfYear(displayYear),
    };
    return DateTime(first.year, first.month, first.day);
  }

  /// Last day of the window (23:59:59.999), in the display calendar.
  DateTime get end {
    final DateTime last = switch (type) {
      StatsRangeType.month => CalendarDisplay.lastDayOfMonth(displayYear, displayMonth),
      StatsRangeType.year => CalendarDisplay.lastDayOfYear(displayYear),
    };
    return DateTime(last.year, last.month, last.day, 23, 59, 59, 999);
  }

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  /// Total whole days in the window (28–31 or 365/366).
  /// Uses UTC dates so local DST spring-forward transitions cannot subtract an
  /// hour and truncate `Duration.inDays` by one.
  int get totalDays {
    final s = start;
    final e = end;
    return DateTime.utc(e.year, e.month, e.day).difference(DateTime.utc(s.year, s.month, s.day)).inDays + 1;
  }

  /// Display month number for a month range, null for a year range.
  int? get month => type == StatsRangeType.month ? displayMonth : null;

  StatsRange get previous {
    switch (type) {
      case StatsRangeType.month:
        final previous = CalendarDisplay.previousMonth(displayYear, displayMonth);
        return StatsRange.month(CalendarDisplay.dateOf(previous.year, previous.month, 1));
      case StatsRangeType.year:
        return StatsRange.year(CalendarDisplay.firstDayOfYear(displayYear - 1));
    }
  }

  StatsRange get next {
    switch (type) {
      case StatsRangeType.month:
        final next = CalendarDisplay.nextMonth(displayYear, displayMonth);
        return StatsRange.month(CalendarDisplay.dateOf(next.year, next.month, 1));
      case StatsRangeType.year:
        return StatsRange.year(CalendarDisplay.firstDayOfYear(displayYear + 1));
    }
  }

  /// Gregorian years the window touches — what the indexed `year` column can
  /// narrow a query to before the exact day range does the rest.
  Set<int> get years => CalendarDisplay.gregorianYearsOfYear(displayYear).toSet();

  /// True when the window includes [now] (i.e. it is the current, in-progress
  /// month/year). Used to cap "days elapsed".
  bool isCurrent([DateTime? now]) => contains(now ?? DateTime.now());

  /// Human label for the selected window, e.g. "آبان ۱۴۰۵", "۱۴۰۵".
  String label(Locale locale) {
    switch (type) {
      case StatsRangeType.month:
        return DateFormatHelper.yMMMM(start, locale);
      case StatsRangeType.year:
        return DateFormatHelper.y(start, locale);
    }
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}
