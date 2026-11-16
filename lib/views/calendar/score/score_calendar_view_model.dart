import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/objects/monthly_score_average.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/providers/daily_score_provider.dart';
import 'package:storypad/widgets/bottom_sheets/sp_daily_score_sheet.dart';
import 'package:storypad/widgets/calendar/sp_calendar.dart';
import 'score_calendar_view.dart';

class ScoreCalendarViewModel extends ChangeNotifier with DisposeAwareMixin {
  ScoreCalendarViewModel({
    required this.params,
    required BuildContext context,
  }) {
    scoreProvider = context.read<DailyScoreProvider>();
    scoreProvider.addListener(_onScoresChanged);
    params.monthYearNotifier.addListener(_onParentMonthYearChanged);
    _reload();
  }

  final ScoreCalendarView params;

  /// Source of truth for every number on this screen. Not watched through
  /// `context.watch`: the calendar paints ~42 cells per frame, and rebuilding the
  /// whole page on every slider move would repaint all of them — re-reading three
  /// small aggregates here is cheaper and keeps the grid's own widgets stable.
  late final DailyScoreProvider scoreProvider;

  final SpCalendarController calendarController = SpCalendarController();

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

  void _reload() {
    scoresByDay = scoreProvider.scoresOfDisplayMonth(year, month);
    monthAverage = scoreProvider.averageOfDisplayMonth(year, month);
    monthlyAverages = scoreProvider.monthlyAverages();
    notifyListeners();
  }

  void _onScoresChanged() => _reload();

  void _onParentMonthYearChanged() {
    // Triggered by the shared month picker in the calendar's app bar; SpCalendar
    // then reports the new month back through [onMonthChanged].
    final ({int year, int month}) value = params.monthYearNotifier.value;
    if (value.year != year || value.month != month) {
      calendarController.goToMonth(value.year, value.month);
    }
  }

  void onMonthChanged(int year, int month) {
    this.year = year;
    this.month = month;

    final ({int year, int month}) value = params.monthYearNotifier.value;
    if (value.year != year || value.month != month) {
      params.monthYearNotifier.value = (year: year, month: month);
    }

    _reload();
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
    scoreProvider.removeListener(_onScoresChanged);
    params.monthYearNotifier.removeListener(_onParentMonthYearChanged);
    super.dispose();
  }
}
