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
    // Counted per *display* year, so the picker lists Shamsi years in Shamsi
    // mode (an exact count per year, not a regrouped approximation).
    years = await StoryDbModel.db.getStoryCountsByDisplayYear(
      filters: {
        'types': [
          PathType.docs.name,
          PathType.archives.name,
        ],
      },
    );

    if (years == null || years?.isEmpty == true) {
      years = {
        CalendarDisplay.yearOf(DateTime.now()): 0,
      };
    }

    notifyListeners();
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
