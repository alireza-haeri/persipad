import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/objects/month_recap_stats_object.dart';
import 'package:storypad/core/services/stories/story_content_embed_extractor.dart';

/// Aggregates a single year's stories into per-month recap stats.
///
/// Pure and side-effect free so it can be unit-tested in isolation: pass in the
/// stories (and optionally a fixed [now] for deterministic "days elapsed"
/// math) and get back a `month -> stats` map. The view model just calls this
/// and holds the result.
class MonthlyStoryStatsService {
  /// Returns recap stats keyed by month of the display year (1–12). Months
  /// without any stories are absent from the map.
  ///
  /// Everything here is in the **display** calendar: a Shamsi month starts on a
  /// Gregorian date in March, so grouping by the stored `month` column would mix
  /// two months into one tile and count a 31-day month that has 30 days.
  /// [stories] are expected to be scoped to one display year (which is what the
  /// home list passes).
  static Map<int, MonthRecapStatsObject> getByMonth({
    required List<StoryDbModel> stories,
    DateTime? now,
  }) {
    final DateTime today = now ?? DateTime.now();
    final int todayYear = CalendarDisplay.yearOf(today);
    final int todayMonth = CalendarDisplay.monthOf(today);

    final Map<int, List<StoryDbModel>> storiesByMonth = {};
    for (final StoryDbModel story in stories) {
      final monthKey = CalendarDisplay.monthKeyOf(story.displayPathDate);
      storiesByMonth.putIfAbsent(monthKey.month, () => []).add(story);
    }

    final Map<int, MonthRecapStatsObject> result = {};
    storiesByMonth.forEach((int month, List<StoryDbModel> monthStories) {
      final int year = CalendarDisplay.yearOf(monthStories.first.displayPathDate);

      int photoCount = 0;
      int videoCount = 0;
      int voiceCount = 0;
      final Set<int> activeDays = {};

      for (final StoryDbModel story in monthStories) {
        final content = story.latestContent ?? story.draftContent;
        photoCount += StoryContentEmbedExtractor.photos(content).length;
        videoCount += StoryContentEmbedExtractor.videos(content).length;
        voiceCount += StoryContentEmbedExtractor.audio(content).length;
        activeDays.add(CalendarDisplay.dayOf(story.displayPathDate));
      }

      final bool isCurrentMonth = year == todayYear && month == todayMonth;
      final int totalDays = isCurrentMonth ? CalendarDisplay.dayOf(today) : CalendarDisplay.daysInMonth(year, month);

      result[month] = MonthRecapStatsObject(
        month: month,
        storyCount: monthStories.length,
        photoCount: photoCount,
        videoCount: videoCount,
        voiceCount: voiceCount,
        activeDays: activeDays.length,
        totalDays: totalDays,
      );
    });

    return result;
  }
}
