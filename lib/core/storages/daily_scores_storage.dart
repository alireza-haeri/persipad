import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/core/storages/base_object_storages/map_storage.dart';

/// One score per day, stored as JSON in the app's preferences.
///
/// Keyed by the **stored** (Gregorian) date as `yyyy-MM-dd` on purpose — see
/// D-025: switching the display calendar must not move a day's score to another
/// day. Everything the user reads converts through `CalendarDisplay` at render
/// time instead. `yyyy-MM-dd` is also sortable as a string, which is what makes
/// the monthly grouping in `DailyScoreProvider` a plain map walk.
///
/// A day without a score has no key at all. There is no such thing as a stored
/// zero: `0` is a legitimate "terrible day" and must never be confused with
/// "not rated", which is the whole reason the charts can omit gaps.
class DailyScoresStorage extends MapStorage {
  static String keyOf(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? dateOf(String key) {
    final DateTime? date = DateTime.tryParse(key);
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  /// Tolerant read: a value that is not a number, or a key that is not a date,
  /// is dropped rather than throwing. A corrupt entry costs one day's score, not
  /// the whole calendar screen.
  static Map<String, int> decode(Map<String, dynamic>? json) {
    final Map<String, int> scores = {};
    if (json == null) return scores;

    json.forEach((key, value) {
      if (dateOf(key) == null) return;
      final num? number = value is num ? value : null;
      if (number == null) return;
      scores[key] = DailyScoreScale.clamp(number.round());
    });

    return scores;
  }

  Future<Map<String, int>> readScores() async => decode(await readMap());

  Future<void> writeScores(Map<String, int> scores) {
    final List<String> keys = scores.keys.toList()..sort();
    return writeMap(<String, dynamic>{
      for (final String key in keys) key: scores[key],
    });
  }
}
