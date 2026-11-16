import 'package:flutter/material.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// The one-tap entry point into the score sheet, tinted with the score it shows.
///
/// Two places need it — "how was today?" in the trend segment and "this selected
/// day" above the calendar's story list — so the look lives here and the wording
/// is passed in. Without a shared shell those two would drift apart the first
/// time either is restyled.
class SpScoreCallout extends StatelessWidget {
  const SpScoreCallout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.onTap,
  });

  final String title;
  final String subtitle;

  /// The scored value, or null when this day was not rated yet.
  final int? score;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int? value = score;
    final Color accent = value == null ? colorScheme.primary : DailyScoreScale.colorOf(value);

    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 1.0),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              // The number itself, when there is one: the tint alone says "good or
              // bad", this says "72".
              AnimatedSwitcher(
                duration: Durations.medium1,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation), child: child),
                ),
                child: value == null
                    ? Icon(SpIcons.add, key: const ValueKey('score-callout-add'), color: accent, size: 22.0)
                    : Text(
                        DailyScoreScale.label(value, Localizations.localeOf(context)),
                        key: const ValueKey('score-callout-value'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
