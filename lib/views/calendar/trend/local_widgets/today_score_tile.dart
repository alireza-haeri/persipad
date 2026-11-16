import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// "Rate today" / "today is a 72", pinned above the score calendar.
///
/// Without it, rating *today* means finding today's cell in a 42-cell grid — the
/// one action the add-on exists for would be its least discoverable one.
class TodayScoreTile extends StatelessWidget {
  const TodayScoreTile({
    super.key,
    required this.score,
    required this.onTap,
  });

  /// Today's score, or null when today has not been rated yet.
  final int? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Locale locale = Localizations.localeOf(context);

    final int? value = score;
    final Color accent = value == null ? colorScheme.primary : DailyScoreScale.colorOf(value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: Material(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(SpIcons.gauge, color: accent, size: 22.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr('general.score_today'), style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 1.0),
                      Text(
                        value == null ? tr('general.score_none_yet') : tr('general.score_of_day'),
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (value == null)
                  Icon(SpIcons.add, color: accent, size: 22.0)
                else
                  Text(
                    DailyScoreScale.label(value, locale),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
