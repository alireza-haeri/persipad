import 'package:flutter/material.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// Frame shared by both score charts: an icon + title, an optional one-line
/// subtitle (the month average), and the chart itself.
///
/// Exists so the two charts cannot drift apart visually — before this they were
/// two copies of the same Card/Padding/Row block.
class ScoreChartCard extends StatelessWidget {
  const ScoreChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
      padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 12.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(SpIcons.gauge, size: 18.0, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (subtitle case final subtitle?)
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 10.0),
          child,
        ],
      ),
    );
  }
}
