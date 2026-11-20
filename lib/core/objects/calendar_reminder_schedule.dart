import 'package:storypad/core/services/calendar/calendar_recurrence.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

/// A calendar-relative schedule independent of the selected display calendar.
///
/// [anchor] is the actual Gregorian date selected when the schedule was set.
/// [day] is retained separately so a short month never changes the requested
/// day. When the display calendar changes, the anchor's corresponding month in
/// the new calendar becomes the first month of the interval, while [day] stays
/// the same. The user can edit the schedule to choose a different anchor.
class CalendarReminderSchedule {
  CalendarReminderSchedule({required this.anchor, required this.day, required this.intervalMonths}) {
    if (day < 1 || day > 31 || intervalMonths < 1 || intervalMonths > 12) {
      throw ArgumentError('Invalid calendar reminder schedule');
    }
  }

  final DateTime anchor;
  final int day;
  final int intervalMonths;

  DateTime next({
    required CalendarSystemOption system,
    required DateTime after,
    required int hour,
    required int minute,
  }) {
    final date = system.isPersian ? PersianCalendar.of(anchor) : PersianDate(anchor.year, anchor.month, anchor.day);
    return CalendarRecurrence.next(
      system: system,
      anchorYear: date.year,
      anchorMonth: date.month,
      day: day,
      intervalMonths: intervalMonths,
      hour: hour,
      minute: minute,
      after: after,
    );
  }

  Map<String, dynamic> toJson() => {
    'anchor_year': anchor.year,
    'anchor_month': anchor.month,
    'anchor_day': anchor.day,
    'day': day,
    'interval_months': intervalMonths,
  };

  /// Returns null for malformed or future/unknown data; callers can fall back
  /// to the existing weekday schedule instead of crashing on old preferences.
  static CalendarReminderSchedule? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final year = value['anchor_year'];
    final month = value['anchor_month'];
    final anchorDay = value['anchor_day'];
    final day = value['day'];
    final interval = value['interval_months'];
    if (year is! int || month is! int || anchorDay is! int || day is! int || interval is! int ||
        year < 1 || month < 1 || month > 12 || anchorDay < 1 || anchorDay > 31 ||
        day < 1 || day > 31 || interval < 1 || interval > 12) {
      return null;
    }
    final anchor = DateTime(year, month, anchorDay);
    if (anchor.year != year || anchor.month != month || anchor.day != anchorDay) return null;
    return CalendarReminderSchedule(anchor: anchor, day: day, intervalMonths: interval);
  }
}
