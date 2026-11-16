import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:storypad/core/objects/monthly_score_average.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/views/calendar/trend/local_widgets/score_chart_card.dart';

/// One bar per month that has at least one rated day.
///
/// Months with no data are simply absent: a zero-height bar would be read as
/// "the worst month I ever had" rather than "nothing recorded", which is why the
/// provider never produces such a month in the first place. Bar heights are
/// absolute on the 0–100 scale (not relative to the best month), so a month of
/// 80s is visibly better than a month of 60s even if the best is 95.
///
/// The bars grow in on mount, staggered start → end, so the chart reads as data
/// arriving rather than as a static diagram. The animation replays whenever the
/// set of months changes (its key) — e.g. after the first score of a new month.
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
    if (months.isEmpty) return const SizedBox.shrink();

    return ScoreChartCard(
      title: tr('general.score_monthly_average'),
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(months.map((month) => month.id).join(',')),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          // Each bar starts a little after the one before it; the whole stagger
          // costs 35% of the timeline, so the last bar still lands at 1.0.
          final double step = months.length <= 1 ? 0.0 : 0.35 / (months.length - 1);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 6.0,
            children: [
              for (final (int index, MonthlyScoreAverage month) in months.indexed)
                _Bar(month: month, appear: _appear(progress, index * step)),
            ],
          );
        },
      ),
    );
  }

  /// How far this bar has grown, given the shared [progress] and its own delay.
  static double _appear(double progress, double delay) {
    final double local = ((progress - delay) / 0.65).clamp(0.0, 1.0).toDouble();
    return Curves.easeOut.transform(local);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.month, required this.appear});

  final MonthlyScoreAverage month;

  /// 0 → no bar yet, 1 → its real height.
  final double appear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Locale locale = Localizations.localeOf(context);
    final Color color = DailyScoreScale.colorOf(month.roundedAverage);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Opacity(
            opacity: appear,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DailyScoreScale.label(month.roundedAverage, locale),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            height: ScoreMonthlyAverageChart._barsHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // The full 0–100 track, so a bar's height means the same thing
                // from month to month.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  heightFactor: (month.average / DailyScoreScale.max).clamp(0.03, 1.0).toDouble() * appear,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [color, color.withValues(alpha: 0.62)],
                      ),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Full month names (Persian is never abbreviated, D-030 §4); scale down
          // rather than clip when the label is wider than the bar.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              month.monthName(locale),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
