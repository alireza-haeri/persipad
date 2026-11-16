import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/widgets/sp_tap_effect.dart';

/// One day of the score calendar.
///
/// A rated day shows **both** numbers the user needs — the day of the month and
/// the score — over a soft wash of the score's own colour, so the month reads as
/// a heat map at a glance. An unrated day shows the day number only: no ring, no
/// zero, nothing that could be mistaken for "you scored this day 0".
class SpScoreCalendarDateCell extends StatelessWidget {
  const SpScoreCalendarDateCell({
    super.key,
    required this.date,
    required this.isDisplayMonth,
    required this.score,
    required this.onTap,
  });

  final DateTime date;

  /// False for the leading/trailing days borrowed from the neighbouring month;
  /// those never show a score, because their real cell lives in the next page.
  final bool isDisplayMonth;

  final int? score;
  final VoidCallback? onTap;

  bool get _isToday {
    final DateTime now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int? value = isDisplayMonth ? score : null;

    final Color dayColor = isDisplayMonth
        ? (CalendarConfig.isWeekend(date) ? colorScheme.error : colorScheme.onSurface)
        : theme.disabledColor;

    return SpTapEffect(
      effects: [.scaleDown],
      scaleActive: 0.9,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3.0),
        padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: value == null ? null : DailyScoreScale.colorOf(value).withValues(alpha: 0.16),
          border: _isToday && isDisplayMonth
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.7), width: 1.2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormatHelper.d(date, Localizations.localeOf(context)),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: dayColor.withValues(alpha: value == null ? 0.85 : 0.75),
                  height: 1.0,
                ),
              ),
            ),
            // Nothing below the day number for an unrated day: the empty space is
            // the message.
            if (value != null) ...[
              const SizedBox(height: 3.0),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DailyScoreScale.label(value, Localizations.localeOf(context)),
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: DailyScoreScale.colorOf(value),
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
