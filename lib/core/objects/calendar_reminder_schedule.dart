import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/services/calendar/calendar_recurrence.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

/// A calendar-relative reminder schedule, independent of the selected calendar.
///
/// [anchor] is the actual Gregorian date the user selected when the schedule was
/// created, and [day] is the day number they meant in the calendar that was
/// active at that moment. Keeping both is what makes a short month harmless: the
/// occurrence is clamped to the month's last day, while [day] — and therefore
/// every later occurrence — stays exactly what the user asked for.
///
/// When the display calendar changes, the anchor's *month* is re-read in the new
/// calendar and [day] is reused there (clamped if needed). That is a deliberate
/// "same day number, new calendar" rule (`D-067`): switching calendars
/// re-anchors the series instead of silently moving it to an unrelated date.
class CalendarReminderSchedule {
  CalendarReminderSchedule({required this.anchor, required this.day, required this.intervalMonths}) {
    if (day < 1 || day > 31 || intervalMonths < 1 || intervalMonths > maxIntervalMonths) {
      throw ArgumentError('Invalid calendar reminder schedule');
    }
  }

  /// The widest interval the UI offers (`1..12` months). 12 is "yearly".
  static const int maxIntervalMonths = 12;

  /// Gregorian date-only anchor (the time of day is carried by the reminder).
  final DateTime anchor;

  /// Intended day number in the displayed calendar, 1..31.
  final int day;

  /// Distance between occurrences in months, 1..12.
  final int intervalMonths;

  /// Reads a schedule out of a reminder, or `null` when the reminder is not a
  /// calendar series / has no usable anchor yet. No throwing: this runs while
  /// scheduling notifications, where one bad record must not stop the rest.
  static CalendarReminderSchedule? fromReminder(ReminderObject reminder) {
    if (!reminder.isCalendarRecurring) return null;

    final anchor = reminder.anchorDate;
    final day = reminder.effectiveAnchorDay;
    if (anchor == null || day == null) return null;

    final dateOnly = DateTime(anchor.year, anchor.month, anchor.day);
    if (dateOnly.month != anchor.month || dateOnly.day != anchor.day) return null;

    return CalendarReminderSchedule(
      anchor: dateOnly,
      day: day,
      intervalMonths: reminder.effectiveIntervalMonths,
    );
  }

  /// The first occurrence strictly after [after].
  DateTime next({
    required CalendarSystemOption system,
    required DateTime after,
    required int hour,
    required int minute,
  }) {
    final anchorInSystem = system.isPersian
        ? PersianCalendar.of(anchor)
        : PersianDate(anchor.year, anchor.month, anchor.day);

    return CalendarRecurrence.next(
      system: system,
      anchorYear: anchorInSystem.year,
      anchorMonth: anchorInSystem.month,
      day: day,
      intervalMonths: intervalMonths,
      hour: hour,
      minute: minute,
      after: after,
    );
  }

  /// [count] consecutive occurrences after [after], in ascending order.
  List<DateTime> upcoming({
    required CalendarSystemOption system,
    required DateTime after,
    required int hour,
    required int minute,
    required int count,
  }) {
    final result = <DateTime>[];
    var cursor = after;
    for (var index = 0; index < count; index++) {
      final next = this.next(system: system, after: cursor, hour: hour, minute: minute);
      result.add(next);
      cursor = next;
    }
    return result;
  }

  /// Human-readable anchor of this schedule in the *display* calendar: the
  /// anchor month with the intended day, clamped to a real date. Used by the
  /// editor to describe the series and by tests.
  DateTime describeAnchor({required CalendarSystemOption system}) {
    final anchorInSystem = system.isPersian
        ? PersianCalendar.of(anchor)
        : PersianDate(anchor.year, anchor.month, anchor.day);
    final days = system.isPersian
        ? PersianCalendar.daysInMonth(anchorInSystem.year, anchorInSystem.month)
        : DateTime(anchorInSystem.year, anchorInSystem.month + 1, 0).day;
    final selectedDay = day > days ? days : day;

    return system.isPersian
        ? PersianCalendar.toGregorian(anchorInSystem.year, anchorInSystem.month, selectedDay)
        : DateTime(anchorInSystem.year, anchorInSystem.month, selectedDay);
  }
}
