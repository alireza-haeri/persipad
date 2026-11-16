part of 'score_trend_view.dart';

class _ScoreTrendContent extends StatelessWidget {
  const _ScoreTrendContent(this.viewModel);

  final ScoreTrendViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same trick as the other calendar segments: a near-zero-height app bar so
      // the charts line up with the segment shown before them.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        automaticallyImplyActions: false,
        toolbarHeight: 12.0,
      ),
      // The side insets are the *page's*, not the safe area's: on a wide window
      // `RootPagesMediaQuery` adds the sidebar's 88pt to `padding.left/right`, and
      // without them the charts slide under the sidebar (the mood segment gets the
      // same treatment through its SliverPadding).
      body: ListView(
        padding: EdgeInsets.only(
          left: MediaQuery.paddingOf(context).left,
          right: MediaQuery.paddingOf(context).right,
          bottom: MediaQuery.paddingOf(context).bottom + 24.0,
        ),
        children: [
          TodayScoreTile(
            score: viewModel.todayScore,
            onTap: () => viewModel.openScoreSheet(context, DateTime.now()),
          ),
          // Discoverability for the one gesture this feature needs the user to
          // learn, shown only until they have rated something.
          if (!viewModel.hasAnyScore) const _LongPressHint(),
          ScoreMonthLineChart(
            scores: viewModel.scoresByDay,
            daysInMonth: viewModel.daysInMonth,
          ),
          // Hidden entirely when no month has data — an empty axis would be a
          // chart of nothing.
          if (viewModel.monthlyAverages.isNotEmpty)
            ScoreMonthlyAverageChart(months: viewModel.monthlyAverages),
        ],
      ),
    );
  }
}

class _LongPressHint extends StatelessWidget {
  const _LongPressHint();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 0.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(SpIcons.info, size: 15.0, color: color),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              tr('general.score_long_press_hint'),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
