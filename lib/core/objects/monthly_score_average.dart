import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';

/// One bar of the monthly-average chart: a display month that has at least one
/// scored day, and the mean of those days.
///
/// [days] is carried around because a 3-day month and a 28-day month are not
/// equally meaningful at the same average, and a later surface may want to say
/// so. It is never used to pad the average with unrated days.
class MonthlyScoreAverage {
  const MonthlyScoreAverage({
    required this.year,
    required this.month,
    required this.average,
    required this.days,
  });

  /// Year in the display calendar (Shamsi when the user picked Shamsi).
  final int year;

  /// Month 1–12 in the display calendar.
  final int month;

  final double average;
  final int days;

  int get roundedAverage => average.round();

  /// Any date inside the month, for formatting its name. The 1st is always
  /// inside it in every calendar this app supports.
  DateTime get firstDay => CalendarDisplay.dateOf(year, month, 1);

  /// Full month name in the active calendar — Persian months are never
  /// abbreviated (D-030 §4).
  String monthName(Locale locale) => DateFormatHelper.MMMM(firstDay, locale);

  String get id => '$year-$month';

  @override
  bool operator ==(Object other) =>
      other is MonthlyScoreAverage &&
      other.year == year &&
      other.month == month &&
      other.days == days &&
      other.average == average;

  @override
  int get hashCode => Object.hash(year, month, average, days);

  @override
  String toString() => 'MonthlyScoreAverage($id, avg=$average, days=$days)';
}
