import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/views/calendar/trend/local_widgets/score_month_line_chart.dart';
import 'package:storypad/views/calendar/trend/local_widgets/score_monthly_average_chart.dart';
import 'package:storypad/views/calendar/trend/local_widgets/today_score_tile.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'score_trend_view_model.dart';

part 'score_trend_content.dart';

/// The score add-on's trend segment: today's rating plus the two charts.
///
/// Deliberately **not** a second calendar. There is one calendar in the app and it
/// lives in the mood segment, where each day already shows its emoji, its day
/// number and its score tint (D-033). What that grid cannot show is shape over
/// time, which is what this segment is for. The month it charts follows the app
/// bar's month, like every other segment.
class ScoreTrendView extends StatelessWidget {
  const ScoreTrendView({
    super.key,
    required this.monthYearNotifier,
  });

  final ValueNotifier<({int year, int month})> monthYearNotifier;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScoreTrendViewModel>(
      create: (context) => ScoreTrendViewModel(params: this, context: context),
      builder: (context, child) {
        return _ScoreTrendContent(Provider.of(context));
      },
    );
  }
}
