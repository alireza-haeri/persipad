import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:storypad/core/objects/monthly_score_average.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/views/calendar/score/local_widgets/score_chart_card.dart';

/// One bar per month that has at least one rated day.
///
/// Months with no data are simply absent: a zero-height bar would be read as
/// "the worst month I ever had" rather than "nothing recorded", which is why the
/// provider never produces such a month in the first place. Bar heights are
/// absolute on the 0–100 scale (not relative to the best month), so a month of
/// 80s is visibly better than a month of 60s even if the best is 95.
class ScoreMonthlyAverageChart extends StatelessWidget {
  const ScoreMonthlyAverageChart({
    super.key,
    required this.months,
  });

  /// Oldest first, already capped by the provider.
  final List<MonthlyScoreAverage> months;

  static const double _barsHeight = 92.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (months.isEmpty) return const SizedBox.shrink();

    return ScoreChartCard(
      title: tr('general.score_monthly_average'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6.0,
        children: [
          for (final MonthlyScoreAverage month in months)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 4.0,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DailyScoreScale.label(month.roundedAverage, Localizations.localeOf(context)),
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: DailyScoreScale.colorOf(month.roundedAverage),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _barsHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // The full 0–100 track, so a bar's height means the same
                        // thing from month to month.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          heightFactor: (month.average / DailyScoreScale.max).clamp(0.03, 1.0).toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  DailyScoreScale.colorOf(month.roundedAverage),
                                  DailyScoreScale.colorOf(month.roundedAverage).withValues(alpha: 0.62),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Full month names (Persian is never abbreviated, D-030 §4);
                  // scale down rather than clip when the label is wider than the
                  // bar.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      month.monthName(Localizations.localeOf(context)),
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
