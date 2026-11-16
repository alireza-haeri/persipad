part of 'mood_calendar_view.dart';

class _CalendarStoriesContent extends StatelessWidget {
  const _CalendarStoriesContent(this.viewModel);

  final MoodCalendarViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        automaticallyImplyActions: false,
        toolbarHeight: viewModel.params.hasMultipleSegments ? 12.0 : 2.0,
        bottom: viewModel.tags?.isNotEmpty == true
            ? PreferredSize(
                preferredSize: const Size.fromHeight(34.0 + 12.0),
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisAlignment: .start,
                  children: [
                    SizedBox(
                      width: .infinity,
                      child: SpScrollableChoiceChips<TagDbModel>(
                        choices: viewModel.tags ?? [],
                        storiesCount: (TagDbModel tag) =>
                            viewModel.tagSelected(tag) ? viewModel.currentFilterStoriesCount : null,
                        toLabel: (TagDbModel tag) => tag.title,
                        selected: (TagDbModel tag) => viewModel.tagSelected(tag),
                        onToggle: (TagDbModel tag) => viewModel.selectTag(tag),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                ),
              )
            : null,
      ),
      floatingActionButtonLocation: SpFabLocation.endFloat(context),
      floatingActionButton: SpFadeIn.fromBottom(
        delay: Durations.medium1,
        child: FloatingActionButton(
          heroTag: null,
          tooltip: tr("button.new_story"),
          child: const Icon(SpIcons.newStory),
          onPressed: () => viewModel.goToNewPage(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return buildBigScreenView(context);
          } else {
            return buildSmallScreenView(context);
          }
        },
      ),
    );
  }

  Widget buildBigScreenView(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MediaQuery.paddingOf(context).left + 16.0,
        right: MediaQuery.paddingOf(context).right,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: MediaQuery.paddingOf(context).copyWith(left: 0, right: 0)),
        child: Row(
          crossAxisAlignment: .start,
          spacing: 0,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: buildCalendar(context, showBottomBorder: false, scrollable: true),
              ),
            ),
            Flexible(child: buildStoryList(context)),
          ],
        ),
      ),
    );
  }

  Widget buildSmallScreenView(BuildContext context) {
    return NestedScrollView(
      controller: PrimaryScrollController.maybeOf(context),
      headerSliverBuilder: (context, _) {
        return [
          SliverPadding(
            padding: MediaQuery.paddingOf(context).copyWith(top: 0, bottom: 0),
            sliver: SliverToBoxAdapter(
              child: buildCalendar(context, showBottomBorder: true),
            ),
          ),
        ];
      },
      body: buildStoryList(context),
    );
  }

  Widget buildStoryList(BuildContext context) {
    // Day count in the *display* calendar: a Shamsi month has 29–31 days too, but
    // `DateTime(year, month + 1, 0)` would count a Gregorian month.
    final daysInMonth = CalendarDisplay.daysInMonth(viewModel.year, viewModel.month);
    final int? selectedDay = viewModel.selectedDay;

    final Widget pages = PageView.builder(
      onPageChanged: (index) {
        // Index 0 = show all (selectedDay = null), Index 1+ = specific day
        if (index == 0) {
          viewModel.onPageChanged(viewModel.year, viewModel.month, null);
        } else {
          viewModel.onPageChanged(viewModel.year, viewModel.month, index);
        }
      },
      controller: viewModel.pageController,
      itemCount: daysInMonth + 1, // +1 for "all" page
      itemBuilder: (context, index) {
        // Index 0 shows all stories for the month
        if (index == 0) {
          return SpStoryList.withQuery(
            key: ValueKey(SearchFilterObject.encode(viewModel.searchFilter.toDatabaseFilter())),
            disableMultiEdit: true,
            watch: viewModel,
            filter: viewModel.searchFilter,
          );
        }

        // Index 1+ shows stories for specific day (`day` is a display day number).
        final filter = viewModel.filterFor(day: index);

        return SpStoryList.withQuery(
          key: ValueKey(SearchFilterObject.encode(filter.toDatabaseFilter())),
          disableMultiEdit: true,
          watch: viewModel,
          filter: filter,
        );
      },
    );

    return Column(
      children: [
        // Above the day's stories: the score for the day the user just picked, so
        // rating a day does not require leaving the list or remembering to
        // long-press (D-033 §4 keeps long press as the shortcut, not the only way).
        if (viewModel.enableScores && selectedDay != null)
          Padding(
            padding: EdgeInsets.only(
              left: MediaQuery.paddingOf(context).left + 16.0,
              right: MediaQuery.paddingOf(context).right + 16.0,
              top: 4.0,
              bottom: 8.0,
            ),
            child: SpScoreCallout(
              title: DateFormatHelper.yMMMd(
                CalendarDisplay.dateOf(viewModel.year, viewModel.month, selectedDay),
                Localizations.localeOf(context),
              ),
              subtitle: viewModel.scoresByDay[selectedDay] == null
                  ? tr('general.score_none_yet')
                  : tr('general.score_of_day'),
              score: viewModel.scoresByDay[selectedDay],
              onTap: () => viewModel.openScoreSheet(
                context,
                CalendarDisplay.dateOf(viewModel.year, viewModel.month, selectedDay),
              ),
            ),
          ),
        Expanded(child: pages),
      ],
    );
  }

  Widget buildCalendar(
    BuildContext context, {
    required bool showBottomBorder,
    bool scrollable = false,
  }) {
    final firstDayOfWeek = context.select(
      (DevicePreferencesProvider provider) => provider.preferences.firstDayOfWeek,
    );

    Widget child = SpCalendar(
      showBottomBorder: showBottomBorder,
      initialYear: viewModel.year,
      initialMonth: viewModel.month,
      firstDayOfWeek: firstDayOfWeek,
      onMonthChanged: viewModel.onMonthChanged,
      controller: viewModel.calendarController,
      cellBuilder: (context, date, isDisplayMonth) {
        // Feelings and scores are keyed by *display* day — the grid pages display
        // months, so `date.month` is not the month being shown.
        final int displayDay = CalendarDisplay.dayOf(date);
        List<String>? feelings = isDisplayMonth ? viewModel.feelingsMapByDay[displayDay] : null;

        return SpCalendarDateCell(
          feelingVisibleIndexNotifier: displayDay.isEven
              ? viewModel.evenFeelingVisibleIndexNotifier
              : viewModel.oddFeelingVisibleIndexNotifier,
          date: date,
          selectedYear: viewModel.year,
          selectedMonth: viewModel.month,
          selectedDay: viewModel.selectedDay,
          feelings: feelings,
          isDisplayMonth: isDisplayMonth,
          // Only when the add-on is on, and only for a real day of the shown
          // month: the borrowed days at the edges belong to another page's month.
          score: isDisplayMonth ? viewModel.scoresByDay[displayDay] : null,
          onTap: isDisplayMonth
              ? () => viewModel.selectDay(
                  viewModel.year,
                  viewModel.month,
                  viewModel.selectedDay == displayDay ? null : displayDay,
                )
              : null,
          onLongPress: isDisplayMonth && viewModel.enableScores
              ? () => viewModel.openScoreSheet(context, date)
              : null,
        );
      },
    );

    if (scrollable) {
      return SingleChildScrollView(child: child);
    } else {
      return child;
    }
  }
}
