import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/views/calendar/score/local_widgets/score_month_line_chart.dart';
import 'package:storypad/views/calendar/score/local_widgets/score_monthly_average_chart.dart';
import 'package:storypad/views/calendar/score/local_widgets/sp_score_calendar_date_cell.dart';
import 'package:storypad/views/calendar/score/local_widgets/today_score_tile.dart';
import 'package:storypad/widgets/calendar/sp_calendar.dart';
import 'score_calendar_view_model.dart';

part 'score_calendar_content.dart';

/// Calendar segment for the daily-score add-on: the month's grid (each rated day
/// showing its score), today's entry point, and the two charts.
class ScoreCalendarView extends StatelessWidget {
  const ScoreCalendarView({
    super.key,
    required this.monthYearNotifier,
  });

  final ValueNotifier<({int year, int month})> monthYearNotifier;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScoreCalendarViewModel>(
      create: (context) => ScoreCalendarViewModel(params: this, context: context),
      builder: (context, child) {
        return _ScoreCalendarContent(Provider.of(context));
      },
    );
  }
}
