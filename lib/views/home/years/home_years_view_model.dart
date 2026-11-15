import 'package:flutter/material.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/path_type.dart';
import 'package:storypad/views/home/years/new/new_year_view.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'home_years_view.dart';

class HomeYearsViewModel extends ChangeNotifier with DisposeAwareMixin {
  final HomeYearsRoute params;

  HomeYearsViewModel({
    required this.params,
  }) {
    load();
  }

  Map<int, int>? years;

  Future<void> load() async {
    final gregorianCounts = await StoryDbModel.db.getStoryCountsByYear(
      filters: {
        'types': [
          PathType.docs.name,
          PathType.archives.name,
        ],
      },
    );

    years = CalendarDisplay.isPersian ? _asDisplayYears(gregorianCounts) : gregorianCounts;

    if (years == null || years?.isEmpty == true) {
      years = {
        CalendarDisplay.yearOf(DateTime.now()): 0,
      };
    }

    notifyListeners();
  }

  /// Regroups per-Gregorian-year counts into display years.
  ///
  /// A Shamsi year straddles two Gregorian years, so no exact regrouping is
  /// possible from year-level counts alone: each Gregorian bucket is attributed
  /// to the display year that owns most of it (1 July is always in the second
  /// half of the display year). The counts shown in the picker are therefore
  /// approximate in Shamsi mode; the list of years itself is not.
  Map<int, int>? _asDisplayYears(Map<int, int>? counts) {
    if (counts == null || counts.isEmpty) return counts;

    final result = <int, int>{};
    for (final entry in counts.entries) {
      final displayYear = CalendarDisplay.yearOf(DateTime(entry.key, 7, 1));
      result[displayYear] = (result[displayYear] ?? 0) + entry.value;
    }

    return result;
  }

  Future<void> addYear(BuildContext context) async {
    dynamic result = await NewYearRoute(years: years).push(context);

    if (result is List<String> && result.isNotEmpty && context.mounted) {
      int year = int.parse(result.first);

      StoryDbModel initialStory = StoryDbModel.startYearStory(
        year,
        // `year` is a display year; date the starter story to its real first day.
        date: CalendarDisplay.isPersian ? CalendarDisplay.firstDayOfYear(year) : null,
      );
      await StoryDbModel.db.set(initialStory);
      await load();
      await params.viewModel.changeYear(year);
    }
  }
}
