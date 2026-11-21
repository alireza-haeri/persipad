import 'package:flutter/foundation.dart';
import 'package:storypad/core/objects/monthly_score_average.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/core/storages/daily_scores_storage.dart';
import 'package:storypad/core/storages/portable_settings.dart';

/// The app-wide store of "how was this day, 0–100".
///
/// Kept as one in-memory map loaded once at startup (no per-build storage read),
/// because three surfaces read it on every frame: the calendar cell of each of
/// ~42 days, the month line chart, and the monthly-average chart.
///
/// Every read is expressed in the **display** calendar, every write in the
/// stored one. That split is D-025's rule, and it is why a user can switch to
/// Shamsi without their history sliding by a day.
class DailyScoreProvider extends ChangeNotifier {
  DailyScoreProvider({DailyScoresStorage? storage}) : _storage = storage ?? DailyScoresStorage() {
    PortableSettings.scoresRestored.addListener(load);
  }

  @override
  void dispose() {
    PortableSettings.scoresRestored.removeListener(load);
    super.dispose();
  }

  final DailyScoresStorage _storage;
  final Map<String, int> _scores = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  bool get hasAnyScore => _scores.isNotEmpty;
  int get scoredDaysCount => _scores.length;

  /// Day keys, oldest first — useful for tests and for "first score ever".
  Iterable<String> get dayKeys => _scores.keys;

  Future<void> load() async {
    _scores
      ..clear()
      ..addAll(await _storage.readScores());
    _loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- writing

  /// Sets a day's score, or clears it when [score] is null.
  ///
  /// Listeners are notified *before* the write is awaited: callers are sheets
  /// that pop immediately afterwards, and the calendar behind them has to show
  /// the new value on the very next frame. A failed write loses one preference-
  /// sized value, which is a better trade than a visible lag on every tap.
  Future<void> setScore(DateTime date, int? score) async {
    final String key = DailyScoresStorage.keyOf(date);
    final int? previous = _scores[key];

    if (score == null) {
      if (previous == null) return;
      _scores.remove(key);
    } else {
      final int next = DailyScoreScale.clamp(score);
      if (previous == next) return;
      _scores[key] = next;
    }

    notifyListeners();
    await _storage.writeScores(_scores);
  }

  // ---------------------------------------------------------------- reading

  /// The score of the day [date] falls on, or null when that day was not rated.
  int? scoreOf(DateTime date) => _scores[DailyScoresStorage.keyOf(date)];

  /// Score of a day given in display-calendar coordinates.
  int? scoreOnDisplayDay(int year, int month, int day) => scoreOf(CalendarDisplay.dateOf(year, month, day));

  /// Only the rated days of a display month: `display day → score`.
  ///
  /// Unrated days are absent rather than zero, so the line chart can leave a gap
  /// instead of dropping the line to the bottom of the axis.
  Map<int, int> scoresOfDisplayMonth(int year, int month) {
    final Map<int, int> scores = {};
    for (int day = 1; day <= CalendarDisplay.daysInMonth(year, month); day++) {
      final int? score = scoreOnDisplayDay(year, month, day);
      if (score != null) scores[day] = score;
    }
    return scores;
  }

  /// Mean of the rated days of a display month, or null when the month has no
  /// rated day at all.
  MonthlyScoreAverage? averageOfDisplayMonth(int year, int month) {
    final List<int> scores = scoresOfDisplayMonth(year, month).values.toList();
    if (scores.isEmpty) return null;
    return MonthlyScoreAverage(
      year: year,
      month: month,
      days: scores.length,
      average: scores.reduce((a, b) => a + b) / scores.length,
    );
  }

  /// Every display month that has at least one rated day, oldest first, capped
  /// to the [limit] most recent.
  ///
  /// Months without data never appear: a bar drawn at zero for "nothing
  /// recorded" is indistinguishable from "the worst month of my life", which is
  /// exactly what the user asked the charts not to do. The cap exists because a
  /// year of bars cannot be labelled on a phone; it is the *oldest* months that
  /// drop out, so the chart always ends on the current month.
  List<MonthlyScoreAverage> monthlyAverages({int limit = 8}) {
    final Map<({int year, int month}), List<int>> byMonth = {};

    _scores.forEach((key, score) {
      final DateTime? date = DailyScoresStorage.dateOf(key);
      if (date == null) return;
      final ({int year, int month}) monthKey = CalendarDisplay.monthKeyOf(date);
      byMonth.putIfAbsent(monthKey, () => <int>[]).add(score);
    });

    final List<MonthlyScoreAverage> months = [
      for (final entry in byMonth.entries)
        MonthlyScoreAverage(
          year: entry.key.year,
          month: entry.key.month,
          days: entry.value.length,
          average: entry.value.reduce((a, b) => a + b) / entry.value.length,
        ),
    ]..sort((a, b) => a.year == b.year ? a.month - b.month : a.year - b.year);

    if (months.length <= limit) return months;
    return months.sublist(months.length - limit);
  }
}
