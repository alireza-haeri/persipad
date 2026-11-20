import 'package:storypad/core/services/calendar/persian_calendar.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

/// Computes calendar-relative occurrences without relying on the device locale.
/// The anchor's numeric year/month and day are interpreted in [system]; callers
/// that change calendar system must intentionally re-anchor the schedule.
class CalendarRecurrence {
  const CalendarRecurrence._();

  /// The first occurrence strictly after [after], preserving the selected day
  /// when a shorter intervening month forces a temporary clamp to month end.
  /// The anchor itself is the first eligible month, not an occurrence limit.
  static DateTime next({
    required CalendarSystemOption system,
    required int anchorYear,
    required int anchorMonth,
    required int day,
    required int intervalMonths,
    required int hour,
    required int minute,
    required DateTime after,
  }) {
    if (anchorYear < 1 || anchorMonth < 1 || anchorMonth > 12 || day < 1 || day > 31 ||
        intervalMonths < 1 || intervalMonths > 12 || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid calendar recurrence');
    }

    final current = system.isPersian ? PersianCalendar.of(after) : PersianDate(after.year, after.month, after.day);
    final anchorIndex = anchorYear * 12 + anchorMonth - 1;
    final currentIndex = current.year * 12 + current.month - 1;
    final elapsed = currentIndex - anchorIndex;
    var occurrence = elapsed <= 0 ? 0 : elapsed ~/ intervalMonths;

    while (true) {
      final index = anchorIndex + occurrence * intervalMonths;
      final year = index ~/ 12;
      final month = index % 12 + 1;
      final days = system.isPersian ? PersianCalendar.daysInMonth(year, month) : DateTime(year, month + 1, 0).day;
      final selectedDay = day > days ? days : day;
      final date = system.isPersian ? PersianCalendar.toGregorian(year, month, selectedDay) : DateTime(year, month, selectedDay);
      final candidate = DateTime(date.year, date.month, date.day, hour, minute);
      if (candidate.isAfter(after)) return candidate;
      occurrence++;
    }
  }
}
