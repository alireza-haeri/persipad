import 'package:storypad/core/objects/calendar_reminder_schedule.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/types/calendar_system_option.dart';

/// One concrete moment a reminder should notify at.
///
/// [slot] is a stable index inside one reminder (0, 1, 2 …). It exists so the
/// notification ids stay stable between two identical reschedules even though
/// the id itself is allocated globally — see `LocalNotificationService`.
class ReminderOccurrence {
  const ReminderOccurrence({required this.at, required this.slot});

  final DateTime at;
  final int slot;

  @override
  String toString() => 'ReminderOccurrence(at: $at, slot: $slot)';
}

/// Pure date arithmetic for reminders. No plugin, no storage, no widgets — every
/// rule in the plan that decides *when* a reminder fires is testable here.
class ReminderSchedulePlanner {
  ReminderSchedulePlanner._();

  /// How many future dates a calendar (monthly/yearly) reminder gets in one
  /// scheduling pass.
  ///
  /// The OS holds these as real alarms, so the app does not have to run for them
  /// to fire. The count is what makes renewal a *bounded* promise: 24 monthly
  /// occurrences cover at least two years, 24 yearly ones two dozen years, and
  /// every app start / resume replenishes the window. Android's practical limit
  /// is a few hundred pending alarms per app, hence the small number.
  static const int defaultCalendarOccurrenceCount = 24;

  /// Concrete occurrences for a monthly/yearly reminder, strictly after [now].
  ///
  /// Returns an empty list for disabled reminders, non-calendar recurrences and
  /// records whose anchor is missing or invalid — callers schedule nothing
  /// rather than guessing a date.
  static List<ReminderOccurrence> calendarOccurrences(
    ReminderObject reminder, {
    required CalendarSystemOption system,
    required DateTime now,
    int limit = defaultCalendarOccurrenceCount,
  }) {
    if (!reminder.enabled || limit <= 0) return const [];

    final schedule = CalendarReminderSchedule.fromReminder(reminder);
    if (schedule == null) return const [];

    final dates = schedule.upcoming(
      system: system,
      after: now,
      hour: reminder.hour,
      minute: reminder.minute,
      count: limit,
    );

    return [
      for (var index = 0; index < dates.length; index++) ReminderOccurrence(at: dates[index], slot: index),
    ];
  }

  /// The next time this reminder will notify, whatever its recurrence, or
  /// `null` when it is disabled / has no schedule yet.
  ///
  /// Used by the UI to describe the series and by tests; notification scheduling
  /// uses [calendarOccurrences] and [nextWeekdayTime] separately because daily
  /// and weekly reminders stay on repeating OS rules.
  static DateTime? nextOccurrence(
    ReminderObject reminder, {
    required CalendarSystemOption system,
    required DateTime now,
  }) {
    if (!reminder.enabled) return null;

    if (reminder.effectiveRecurrence.isCalendarBased) {
      final occurrences = calendarOccurrences(reminder, system: system, now: now, limit: 1);
      return occurrences.isEmpty ? null : occurrences.first.at;
    }

    DateTime? next;
    for (final slot in reminder.scheduleSlots) {
      final candidate = nextWeekdayTime(
        now: now,
        hour: reminder.hour,
        minute: reminder.minute,
        weekday: slot == 0 ? null : slot,
      );
      if (next == null || candidate.isBefore(next)) next = candidate;
    }
    return next;
  }

  /// The next time-of-day at or after [now] that falls on [weekday]
  /// (1=Mon … 7=Sun). A `null` weekday means "every day".
  ///
  /// Dates are built from calendar components (`DateTime(y, m, d + n)`) instead
  /// of adding a `Duration`, so a DST transition cannot skip or repeat a day
  /// (`D-049`).
  static DateTime nextWeekdayTime({required DateTime now, required int hour, required int minute, int? weekday}) {
    var daysAhead = 0;
    if (weekday != null) {
      daysAhead = (weekday - now.weekday) % DateTime.daysPerWeek;
      if (daysAhead < 0) daysAhead += DateTime.daysPerWeek;
    }

    var candidate = DateTime(now.year, now.month, now.day + daysAhead, hour, minute);
    if (!candidate.isAfter(now)) {
      final step = weekday == null ? 1 : DateTime.daysPerWeek;
      candidate = DateTime(now.year, now.month, now.day + daysAhead + step, hour, minute);
    }
    return candidate;
  }
}
