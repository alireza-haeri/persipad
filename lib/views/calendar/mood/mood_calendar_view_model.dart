import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/tag_db_model.dart';
import 'package:storypad/core/mixins/debounched_callback.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/objects/search_filter_object.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/path_type.dart';
import 'package:storypad/providers/daily_score_provider.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/providers/tags_provider.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/views/stories/edit/edit_story_view.dart';
import 'package:storypad/widgets/bottom_sheets/sp_daily_score_sheet.dart';
import 'package:storypad/widgets/calendar/sp_calendar.dart';
import 'mood_calendar_view.dart';

class MoodCalendarViewModel extends ChangeNotifier with DisposeAwareMixin, DebounchedCallback {
  final MoodCalendarView params;
  late final TagsProvider tagsProvider;

  MoodCalendarViewModel({
    required this.params,
    required BuildContext context,
  }) {
    tagsProvider = context.read<TagsProvider>();
    oddFeelingVisibleIndexNotifier = ValueNotifier<int>(0);
    oddPeriodicTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      oddFeelingVisibleIndexNotifier.value = oddFeelingVisibleIndexNotifier.value + 1;
    });

    evenFeelingVisibleIndexNotifier = ValueNotifier<int>(0);
    evenPeriodicTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      Future.delayed(const Duration(seconds: 1)).then((_) {
        if (disposed) return;
        evenFeelingVisibleIndexNotifier.value = evenFeelingVisibleIndexNotifier.value + 1;
      });
    });

    feelingsMapByDay = StoryDbModel.db.getStoryFeelingByMonth(
      month: month,
      year: year,
      feelingEmojiById: context.read<TagsProvider>().feelingEmojiById,
    );

    // The daily-score add-on tints this same grid (D-033): one calendar shows
    // feelings, the check, the day number and the score, in that order.
    enableScores = context.read<DevicePreferencesProvider>().enableDailyScore;
    dailyScoreProvider = context.read<DailyScoreProvider>();
    dailyScoreProvider.addListener(_reloadScores);
    scoresByDay = enableScores ? dailyScoreProvider.scoresOfDisplayMonth(year, month) : const {};

    _tags = [...context.read<TagsProvider>().tags?.items ?? []];
    if (_tags?.isNotEmpty == true) _tags?.insert(0, TagDbModel.fromIDTitle(0, tr('general.all')));

    currentFilterStoriesCount = StoryDbModel.db.getStoryCountBy(filters: searchFilter.toDatabaseFilter());

    StoryDbModel.db.addGlobalListener(_reloadFeeling);
    params.monthYearNotifier.addListener(_onParentMonthYearChanged);

    selectedDay =
        params.initialSelectedDay ??
        (params.monthYearNotifier.value.month == CalendarDisplay.monthOf(DateTime.now()) &&
                params.monthYearNotifier.value.year == CalendarDisplay.yearOf(DateTime.now())
            ? CalendarDisplay.dayOf(DateTime.now())
            : 1);
  }

  // For feeling flip animation, giving even days a 1-second delay
  // before flipping to have better visual effect.
  late final Timer oddPeriodicTimer;
  late final Timer evenPeriodicTimer;
  late final ValueNotifier<int> oddFeelingVisibleIndexNotifier;
  late final ValueNotifier<int> evenFeelingVisibleIndexNotifier;

  final SpCalendarController calendarController = SpCalendarController();
  late final PageController pageController = PageController(initialPage: selectedDay ?? 0);

  List<TagDbModel>? _tags;
  List<TagDbModel>? get tags => _tags;

  late int month = params.monthYearNotifier.value.month;
  late int year = params.monthYearNotifier.value.year;

  /// [SpStoryList.withQuery] is passed this view model as `watch`, so calling
  /// this silently reloads the visible story list — without remounting it
  /// (no loading-spinner flash).
  void refreshList() {
    notifyListeners();
  }

  int? selectedDay;
  int? selectedTagId;
  int? currentFilterStoriesCount;

  Map<int, List<String>> feelingsMapByDay = {};

  /// Whether the daily-score add-on is on for this visit. Read once, like the
  /// period segment's gate: the calendar is opened as a sheet, so the preference
  /// is already loaded when this view model is built.
  late final bool enableScores;

  late final DailyScoreProvider dailyScoreProvider;

  /// Rated days of the shown month: display day → score. Empty when the add-on is
  /// off, which is also what turns the score tint and the long-press gesture off.
  Map<int, int> scoresByDay = {};

  void _reloadScores() {
    // No add-on, no scores. Reading them anyway is what left the grid tinted after
    // the user switched the add-on off: the tint is keyed off this map, so an
    // empty map is the whole difference between "one calendar with a score layer"
    // and "the calendar as it was before the add-on existed" (D-035 §2).
    scoresByDay = enableScores ? dailyScoreProvider.scoresOfDisplayMonth(year, month) : const {};
    notifyListeners();
  }

  /// Opens the rating sheet for a day. Long press on a cell calls this; a plain
  /// tap still selects the day and shows its stories.
  Future<void> openScoreSheet(BuildContext context, DateTime date) async {
    await SpDailyScoreSheet(date: date).show(context: context);
  }

  bool tagSelected(TagDbModel tag) => (selectedTagId == tag.id) || (tag.id == 0 && selectedTagId == null);

  SearchFilterObject get searchFilter => filterFor(day: selectedDay);

  /// The story filter for this screen, in the *display* calendar.
  ///
  /// `year`/`month` are display values, and a Shamsi month is a run of days rather
  /// than a `month` column value, so the scope is always an exact day range. For a
  /// single day the Gregorian month/day are kept as well, which is what lets the
  /// list show its "on this day in another year" throwback.
  SearchFilterObject filterFor({int? day}) {
    final DateTime start = day == null
        ? CalendarDisplay.firstDayOfMonth(year, month)
        : CalendarDisplay.dateOf(year, month, day);
    final DateTime end = day == null ? CalendarDisplay.lastDayOfMonth(year, month) : start;

    return DateRangeFilterObject(
      start: start,
      end: end,
      years: CalendarDisplay.displayYearsCovering(start, end).toSet(),
      month: day == null ? null : start.month,
      day: day == null ? null : start.day,
      types: {PathType.docs},
      tagIds: selectedTagId != null ? {selectedTagId!} : {},
    );
  }

  // only reload feeling when listen to DB.
  // story query list already know how to refresh their own list, so we don't have to refresh for them.
  Future<void> _reloadFeeling() async {
    feelingsMapByDay = StoryDbModel.db.getStoryFeelingByMonth(
      month: month,
      year: year,
      feelingEmojiById: tagsProvider.feelingEmojiById,
    );
    scoresByDay = dailyScoreProvider.scoresOfDisplayMonth(year, month);
    notifyListeners();
  }

  Future<void> goToNewPage(BuildContext context) async {
    // The edit screen takes storage (Gregorian) dates, so the display month/day
    // is converted on the way in and back on the way out.
    final DateTime date = selectedDay == null
        ? CalendarDisplay.firstDayOfMonth(year, month)
        : CalendarDisplay.dateOf(year, month, selectedDay!);

    final addedStory = await EditStoryRoute(
      id: null,
      initialYear: date.year,
      initialMonth: date.month,
      initialDay: date.day,
      initialTagIds: selectedTagId != null ? [selectedTagId!] : null,
    ).push(context);

    if (addedStory is StoryDbModel) {
      final int storyYear = CalendarDisplay.yearOf(addedStory.displayPathDate);
      final int storyMonth = CalendarDisplay.monthOf(addedStory.displayPathDate);

      // Navigate to the story's month if different
      if (storyMonth != month || storyYear != year) {
        calendarController.goToMonth(storyYear, storyMonth);
      }
      selectedDay = CalendarDisplay.dayOf(addedStory.displayPathDate);
    }

    refreshList();

    Future.delayed(const Duration(seconds: 1)).then((_) {
      HomeView.reload(debugSource: '$runtimeType#goToNewPage');
    });
  }

  void onChanged(
    int year,
    int month,
    int? selectedDay,
    int? selectedTagId,
  ) async {
    if (year != this.year || month != this.month || selectedTagId != this.selectedTagId) {
      feelingsMapByDay = StoryDbModel.db.getStoryFeelingByMonth(
        month: month,
        year: year,
        tagId: selectedTagId,
        feelingEmojiById: tagsProvider.feelingEmojiById,
      );
    }

    this.selectedDay = year != this.year || month != this.month ? null : selectedDay;

    if (year != this.year || month != this.month) {
      scoresByDay = dailyScoreProvider.scoresOfDisplayMonth(year, month);
    }

    this.year = year;
    this.month = month;
    this.selectedTagId = selectedTagId;

    currentFilterStoriesCount = StoryDbModel.db.getStoryCountBy(
      filters: searchFilter.toDatabaseFilter(),
    );

    notifyListeners();
  }

  void selectTag(TagDbModel tag) {
    onChanged(year, month, selectedDay, tag.id == 0 ? null : tag.id);
  }

  void onMonthChanged(int year, int month) {
    onChanged(year, month, selectedDay, selectedTagId);

    if (params.monthYearNotifier.value.month != month || params.monthYearNotifier.value.year != year) {
      params.monthYearNotifier.value = (year: year, month: month);
    }

    // Reset page controller to index 0 when month changes
    if (pageController.hasClients) {
      pageController.jumpToPage(0);
    }
  }

  // this will also trigger onMonthChanged from SpCalendar.
  void _onParentMonthYearChanged() {
    final newMonth = params.monthYearNotifier.value.month;
    final newYear = params.monthYearNotifier.value.year;
    if (newMonth != month || newYear != year) {
      calendarController.goToMonth(newYear, newMonth);
    }
  }

  void selectDay(int year, int month, int? day) {
    onChanged(year, month, day, selectedTagId);

    if (!pageController.hasClients) return;

    final targetPage = day ?? 0;
    final currentPage = pageController.page?.toInt() ?? 0;

    if (currentPage != targetPage) {
      pageController.jumpToPage(targetPage);
    }
  }

  void onPageChanged(int year, int month, int? day) {
    onChanged(year, month, day, selectedTagId);
  }

  void navigateToMonth(int year, int month) {
    calendarController.goToMonth(year, month);
  }

  @override
  void dispose() {
    params.monthYearNotifier.removeListener(_onParentMonthYearChanged);
    StoryDbModel.db.removeGlobalListener(_reloadFeeling);
    dailyScoreProvider.removeListener(_reloadScores);
    pageController.dispose();
    oddPeriodicTimer.cancel();
    evenPeriodicTimer.cancel();
    oddFeelingVisibleIndexNotifier.dispose();
    evenFeelingVisibleIndexNotifier.dispose();
    super.dispose();
  }
}
