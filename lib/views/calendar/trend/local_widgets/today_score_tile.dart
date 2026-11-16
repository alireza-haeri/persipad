import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:storypad/widgets/scores/sp_score_callout.dart';

/// "How was today?" — the one-tap way to rate the current day.
///
/// Without it, rating *today* means finding today's cell in a 42-cell grid, so
/// the one action the add-on exists for would be its least discoverable one.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: SpScoreCallout(
        title: tr('general.score_today'),
        subtitle: score == null ? tr('general.score_none_yet') : tr('general.score_of_day'),
        score: score,
        onTap: onTap,
      ),
    );
  }
}
