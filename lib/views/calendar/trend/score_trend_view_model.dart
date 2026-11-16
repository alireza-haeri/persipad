import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/objects/monthly_score_average.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/providers/daily_score_provider.dart';
import 'package:storypad/widgets/bottom_sheets/sp_daily_score_sheet.dart';
import 'score_trend_view.dart';

class ScoreTrendViewModel extends ChangeNotifier with DisposeAwareMixin {
  ScoreTrendViewModel({
    required this.params,
    required BuildContext context,
  }) {
    scoreProvider = context.read<DailyScoreProvider>();
    scoreProvider.addListener(_reload);
    params.monthYearNotifier.addListener(_onParentMonthYearChanged);
    _reload();
  }

  final ScoreTrendView params;

  /// Source of truth for every number on this screen. Not watched through
  /// `context.watch`: the charts read three small aggregates, and re-reading them
  /// here keeps the paint of a chart independent of unrelated rebuilds.
  late final DailyScoreProvider scoreProvider;

  late int year = params.monthYearNotifier.value.year;
  late int month = params.monthYearNotifier.value.month;

  /// Rated days of the shown month: display day → score.
  Map<int, int> scoresByDay = const {};

  /// The shown month's mean, or null when nothing in it was rated.
  MonthlyScoreAverage? monthAverage;

  /// Months with data, oldest first (capped) — the bars of the second chart.
  List<MonthlyScoreAverage> monthlyAverages = const [];

  int get daysInMonth => CalendarDisplay.daysInMonth(year, month);

  int? get todayScore => scoreProvider.scoreOf(DateTime.now());

  /// Whether anything was ever rated — drives the one-time long-press hint.
  bool get hasAnyScore => scoreProvider.hasAnyScore;

  void _reload() {
    scoresByDay = scoreProvider.scoresOfDisplayMonth(year, month);
    monthAverage = scoreProvider.averageOfDisplayMonth(year, month);
    monthlyAverages = scoreProvider.monthlyAverages();
    notifyListeners();
  }

  /// The app bar's month picker is shared by all segments: it writes the notifier,
  /// and this view model re-reads. There is no grid here to page through months,
  /// so this is the only way the shown month can change.
  void _onParentMonthYearChanged() {
    final ({int year, int month}) value = params.monthYearNotifier.value;
    if (value.year != year || value.month != month) {
      year = value.year;
      month = value.month;
      _reload();
    }
  }

  /// Opens the rating sheet for a stored (Gregorian) date.
  ///
  /// The sheet writes through the provider, so nothing needs to be returned or
  /// refreshed: this view model is one of the provider's listeners.
  Future<void> openScoreSheet(BuildContext context, DateTime date) async {
    await SpDailyScoreSheet(date: date).show(context: context);
  }

  @override
  void dispose() {
    scoreProvider.removeListener(_reload);
    params.monthYearNotifier.removeListener(_onParentMonthYearChanged);
    super.dispose();
  }
}
