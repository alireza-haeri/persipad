part of '../stats_view.dart';

/// Branding footer pinned to the bottom of each stats tab.
class _StatsShareFooter extends StatelessWidget {
  const _StatsShareFooter();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.of(context);
    final TextTheme textTheme = TextTheme.of(context);

    return Column(
      children: [
        const SizedBox(height: 16.0),
        SpTapEffect(
          onTap: () => UrlOpenerService.openInCustomTab(context, kProjectRepositoryUrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: .hardEdge,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Theme.of(context).dividerColor, width: 1.0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppLogo.storypad_1_0.asset.image(width: 40, height: 40, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12.0),
                Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      'PersiPad',
                      strutStyle: const StrutStyle(forceStrutHeight: true),
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      'My Diary Journal',
                      strutStyle: const StrutStyle(forceStrutHeight: true),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
