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
    return switch (viewModel.selectedSegment) {
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
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      bottom: viewModel.segments.length > 1 ? buildSegmentButtons(context) : null,
      title: ValueListenableBuilder(
        valueListenable: viewModel.monthYearNotifier,
        builder: (context, monthYear, child) {
          return SpTapEffect(
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
              DateFormatHelper.yMMMM(
                CalendarDisplay.firstDayOfMonth(monthYear.year, monthYear.month),
                context.locale,
              ),
              key: ValueKey("${monthYear.month}-${monthYear.year}"),
              style: Theme.of(context).appBarTheme.titleTextStyle,
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
