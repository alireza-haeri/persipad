import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/types/reminder_recurrence.dart';

/// e.g. "Every day at 9:00 PM", "Mon, Wed at 9:00 PM",
/// "Every month on day 31 at 9:00 PM", "Every 3 months on day 5 at 9:00 PM",
/// "Every year on 20 March 2025 at 9:00 PM".
///
/// Shared by the reminders list (tile subtitle) and the custom reminder edit page
/// (live preview), so both read from the same wording while the user edits. The
/// day number is rendered in the locale's digits and the date in the app's
/// displayed calendar, because that is what the user picked.
String reminderScheduleSummary(
  BuildContext context, {
  required TimeOfDay time,
  required Set<int> weekdays,
  ReminderRecurrence recurrence = ReminderRecurrence.daily,
  int intervalMonths = 1,
  DateTime? anchorDate,
  int? anchorDay,
}) {
  final locale = context.locale;
  final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(time);

  switch (recurrence) {
    case ReminderRecurrence.monthly:
      final day = DateFormatHelper.number(anchorDay ?? anchorDate?.day ?? 1, locale);
      if (intervalMonths <= 1) {
        return tr(
          'reminder.summary.every_month_on_day',
          namedArgs: {'S_DAY': day, 'S_TIME': formattedTime},
        );
      }

      return tr(
        'reminder.summary.every_n_months_on_day',
        namedArgs: {
          'S_COUNT': DateFormatHelper.number(intervalMonths, locale),
          'S_DAY': day,
          'S_TIME': formattedTime,
        },
      );

    case ReminderRecurrence.yearly:
      final date = anchorDate == null ? '' : DateFormatHelper.yMMMd(anchorDate, locale);
      return tr(
        'reminder.summary.every_year',
        namedArgs: {'SP_DATE': date, 'S_TIME': formattedTime},
      );

    case ReminderRecurrence.daily:
    case ReminderRecurrence.weekly:
      if (weekdays.isEmpty) {
        return tr('reminder.summary.every_day', namedArgs: {'S_TIME': formattedTime});
      }

      final ordered = weekdays.toSet().toList()..sort();
      final labels = ordered.map((w) => DateFormat.E(locale.toString()).format(DateTime(2024, 1, w)));
      return tr(
        'reminder.summary.selected_days',
        namedArgs: {
          'S_DAYS': labels.join(', '),
          'S_TIME': formattedTime,
        },
      );
  }
}

/// [reminderScheduleSummary] for a stored reminder, reading exactly the fields
/// the planner schedules from.
String reminderSummaryOf(BuildContext context, ReminderObject reminder) {
  return reminderScheduleSummary(
    context,
    time: reminder.timeOfDay,
    weekdays: reminder.weekdays.toSet(),
    recurrence: reminder.effectiveRecurrence,
    intervalMonths: reminder.effectiveIntervalMonths,
    anchorDate: reminder.anchorDate,
    anchorDay: reminder.effectiveAnchorDay,
  );
}
