part of 'calendar_view.dart';

class _CalendarContent extends StatelessWidget {
  const _CalendarContent(this.viewModel);

  final CalendarViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    final Widget segment = switch (viewModel.selectedSegment) {
      CalendarSegmentId.mood => MoodCalendarView(
        hasMultipleSegments: viewModel.segments.length > 1,
        monthYearNotifier: viewModel.monthYearNotifier,
        initialSelectedDay: viewModel.params.initialDay,
      ),
      CalendarSegmentId.period => PeriodCalendarView(
        monthYearNotifier: viewModel.monthYearNotifier,
      ),
      CalendarSegmentId.score => ScoreTrendView(
        monthYearNotifier: viewModel.monthYearNotifier,
      ),
    };

    // The segments are different screens (a grid, a period grid, two charts), so
    // one fades into the next instead of being swapped inside a single frame. The
    // key is the segment, not the widget: without it every rebuild would look like
    // a segment change.
    return AnimatedSwitcher(
      duration: Durations.medium2,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Faded-out screens must not eat taps meant for the new one.
      child: KeyedSubtree(
        key: ValueKey(viewModel.selectedSegment),
        child: segment,
      ),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      bottom: viewModel.segments.length > 1 ? buildSegmentButtons(context) : null,
      title: ValueListenableBuilder(
        valueListenable: viewModel.monthYearNotifier,
        builder: (context, monthYear, child) {
          final String label = DateFormatHelper.yMMMM(
            CalendarDisplay.firstDayOfMonth(monthYear.year, monthYear.month),
            context.locale,
          );

          return AnimatedSwitcher(
            duration: Durations.medium2,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // A swipe changes the grid under the title, so the title has to say so:
            // it slides up into place instead of snapping while the month pages by.
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.18),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: SpTapEffect(
              // The key belongs to the child of the switcher: that is what makes it
              // see a new title rather than the same one re-laid out.
              key: ValueKey(label),
              onTap: () async {
                final result = await MonthPickerService(
                  context: context,
                  month: monthYear.month,
                  year: monthYear.year,
                ).showPicker();
                if (result != null) {
                  viewModel.onMonthYearChanged(result.year, result.month);
                }
              },
              child: Text(
                // Same calendar as the grid below: both go through CalendarDisplay,
                // so "آبان ۱۴۰۵" sits over آبان's days.
                label,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
          );
        },
      ),
      // We don't need manual month navigation buttons yet. Use can use month picker or swipe gestures.
      // actions: [
      //   IconButton(
      //     icon: const Icon(SpIcons.keyboardLeft),
      //     onPressed: () {
      //       final newMonth = viewModel.monthYearNotifier.value.month - 1 == 0
      //           ? 12
      //           : viewModel.monthYearNotifier.value.month - 1;

      //       final newYear = viewModel.monthYearNotifier.value.month - 1 == 0
      //           ? viewModel.monthYearNotifier.value.year - 1
      //           : viewModel.monthYearNotifier.value.year;

      //       viewModel.onMonthYearChanged(newYear, newMonth);
      //     },
      //   ),
      //   IconButton(
      //     icon: const Icon(SpIcons.keyboardRight),
      //     onPressed: () {
      //       final newMonth = viewModel.monthYearNotifier.value.month + 1 == 13
      //           ? 1
      //           : viewModel.monthYearNotifier.value.month + 1;

      //       final newYear = viewModel.monthYearNotifier.value.month + 1 == 13
      //           ? viewModel.monthYearNotifier.value.year + 1
      //           : viewModel.monthYearNotifier.value.year;

      //       viewModel.onMonthYearChanged(newYear, newMonth);
      //     },
      //   ),
      // ],
    );
  }

  PreferredSizeWidget buildSegmentButtons(BuildContext context) {
    Widget segmentButton;

    if (kIsCupertino) {
      segmentButton = CupertinoSlidingSegmentedControl<CalendarSegmentId>(
        groupValue: viewModel.selectedSegment,
        onValueChanged: (segment) {
          if (segment != null) {
            viewModel.onSegmentChanged(segment);
          }
        },
        children: {
          // Three segments (mood / period / score) can be wider than a small
          // phone. Each label is left free to shrink instead of overflowing —
          // the same lesson as D-030 §4: never make a row of text unbounded.
          for (final segment in viewModel.segments)
            segment: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(segment.translatedName(context)),
            ),
        },
      );
    } else {
      segmentButton = SegmentedButton<CalendarSegmentId>(
        selected: {viewModel.selectedSegment},
        multiSelectionEnabled: false,
        onSelectionChanged: (value) {
          if (value.isNotEmpty) {
            viewModel.onSegmentChanged(value.first);
          }
        },
        showSelectedIcon: false,
        segments: [
          for (final segment in viewModel.segments)
            ButtonSegment<CalendarSegmentId>(
              value: segment,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(segment.translatedName(context)),
              ),
            ),
        ],
      );
    }

    return PreferredSize(
      preferredSize: CupertinoSheetRoute.hasParentSheet(context)
          ? const Size.fromHeight(32.0)
          : const Size.fromHeight(48.0),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: EdgeInsets.only(
            left: MediaQuery.of(context).padding.left,
            right: MediaQuery.of(context).padding.right,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          width: double.infinity,
          child: segmentButton,
        ),
      ),
    );
  }
}
