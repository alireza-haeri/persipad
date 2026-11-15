import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/databases/models/collection_db_model.dart';
import 'package:storypad/core/databases/models/event_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/mixins/debounched_callback.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/path_type.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/views/calendar/period/period_calendar_view.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/views/stories/edit/edit_story_view.dart';
import 'package:storypad/widgets/calendar/sp_calendar.dart';

class PeriodCalendarViewModel extends ChangeNotifier with DisposeAwareMixin, DebounchedCallback {
  final PeriodCalendarView params;
  final DevicePreferencesProvider _devicePreferencesProvider;

  PeriodCalendarViewModel({
    required this.params,
    required BuildContext context,
  }) : _devicePreferencesProvider = context.read<DevicePreferencesProvider>() {
    load();
    params.monthYearNotifier.addListener(_onParentMonthYearChanged);
    // DevicePreferencesProvider intentionally skips notifyListeners on reminder
    // writes (see its _writeReminders comment) to avoid rebuilding the whole
    // app, so the period reminder tile must subscribe here instead — same
    // pattern as RemindersViewModel.
    _devicePreferencesProvider.addListenerForReminderChanges(notifyListeners);
  }

  final SpCalendarController calendarController = SpCalendarController();

  late int month = params.monthYearNotifier.value.month;
  late int year = params.monthYearNotifier.value.year;

  List<EventDbModel> _lastMonthPeriodEvents = [];
  List<EventDbModel> get lastMonthPeriodEvents => _lastMonthPeriodEvents;

  List<EventDbModel> _periodEvents = [];
  Set<DateTime> get periodDates => _periodEvents.map((e) => DateTime(e.year, e.month, e.day)).toSet();

  EventDbModel? _selectedEvent;
  EventDbModel? get selectedEvent => _selectedEvent;

  CollectionDbModel<StoryDbModel>? _selectedEventStories;
  CollectionDbModel<StoryDbModel>? get selectedEventStories => _selectedEventStories;

  DateTime? get selectedEventDate => _selectedEvent?.date;

  bool isPeriodDate(DateTime date) {
    return _periodEvents.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
  }

  bool isLastMonthPeriodDate(DateTime date) {
    // Membership by real date: the grid shows a few cells of the neighbouring
    // display months, and "same day, one calendar month earlier" stopped being a
    // one-line subtraction once months can be Shamsi.
    return _lastMonthPeriodEvents.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
  }

  bool isDateSelected(DateTime date) {
    return selectedEvent != null &&
        selectedEvent!.year == date.year &&
        selectedEvent!.month == date.month &&
        selectedEvent!.day == date.day;
  }

  Future<void> load({
    DateTime? initialSelectedDate,
  }) async {
    // `year`/`month` are display values, so the event tables (which store
    // Gregorian year/month/day) are queried by the exact day range each display
    // month covers — see `EventsBox._dateRangeCondition`.
    final thisMonth = CalendarDisplay.rangeOfMonth(year, month);
    final previous = CalendarDisplay.previousMonth(year, month);
    final lastMonth = CalendarDisplay.rangeOfMonth(previous.year, previous.month);

    _lastMonthPeriodEvents = await EventDbModel.db
        .where(
          filters: {
            'date_range': [lastMonth.start, lastMonth.end],
            'event_type': 'period',
          },
        )
        .then((e) => e?.items ?? []);

    _periodEvents = await EventDbModel.db
        .where(
          filters: {
            'date_range': [thisMonth.start, thisMonth.end],
            'event_type': 'period',
          },
        )
        .then((e) => e?.items ?? []);

    _selectedEvent =
        _periodEvents
            .where(
              (e) =>
                  e.year == initialSelectedDate?.year &&
                  e.month == initialSelectedDate?.month &&
                  e.day == initialSelectedDate?.day,
            )
            .firstOrNull ??
        _periodEvents.firstOrNull;

    _selectedEventStories = selectedEvent != null
        ? await StoryDbModel.db.where(
            filters: {
              'date_range': [selectedEventDate!, selectedEventDate!],
              'types': [PathType.docs.name],
            },
          )
        : null;

    notifyListeners();
  }

  // this will also trigger onMonthChanged from SpCalendar.
  void _onParentMonthYearChanged() {
    final newMonth = params.monthYearNotifier.value.month;
    final newYear = params.monthYearNotifier.value.year;
    if (newMonth != month || newYear != year) {
      calendarController.goToMonth(newYear, newMonth);
    }
  }

  Future<void> toggleDate(BuildContext context, DateTime date) async {
    if (isDateSelected(date)) {
      await _removeEvent(date);
    } else {
      if (isPeriodDate(date)) {
        await load(initialSelectedDate: date);
      } else {
        await EventDbModel.period(date: date).createIfNotExist();
        await load(initialSelectedDate: date);
        HomeView.reload(debugSource: '$runtimeType#toggleDate');
      }
    }
  }

  // Period and journal are independent: removing a period date is a pure toggle
  // that never touches journal entries on that day.
  Future<void> _removeEvent(DateTime date) async {
    await EventDbModel.db.delete(_selectedEvent!.id);
    await load(initialSelectedDate: date);
    HomeView.reload(debugSource: '$runtimeType#_removeEvent');
  }

  void onMonthChanged(int year, int month) async {
    this.year = year;
    this.month = month;

    await load();

    if (params.monthYearNotifier.value.month != month || params.monthYearNotifier.value.year != year) {
      params.monthYearNotifier.value = (year: year, month: month);
    }
  }

  void goToNewPage(BuildContext context) async {
    if (selectedEvent == null) return;

    // Storage dates: the event's own Gregorian day is what the edit screen wants.
    DateTime date = selectedEventDate!;
    final addedStory = await EditStoryRoute(
      id: null,
      initialYear: date.year,
      initialMonth: date.month,
      initialDay: date.day,
    ).push(context);

    if (addedStory is StoryDbModel) {
      final int storyYear = CalendarDisplay.yearOf(addedStory.displayPathDate);
      final int storyMonth = CalendarDisplay.monthOf(addedStory.displayPathDate);

      if (storyMonth != month || storyYear != year) {
        calendarController.goToMonth(storyYear, storyMonth);
      }
      date = addedStory.displayPathDate;
    }

    await load(initialSelectedDate: date);
    Future.delayed(const Duration(seconds: 1)).then((_) {
      HomeView.reload(debugSource: '$runtimeType#goToNewPage');
    });
  }

  @override
  void dispose() {
    params.monthYearNotifier.removeListener(_onParentMonthYearChanged);
    _devicePreferencesProvider.removeListenerForReminderChanges(notifyListeners);
    super.dispose();
  }
}
