part of 'score_calendar_view.dart';

class _ScoreCalendarContent extends StatelessWidget {
  const _ScoreCalendarContent(this.viewModel);

  final ScoreCalendarViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same trick as the other calendar segments: a near-zero-height app bar so
      // the grid lines up with the segment that was shown before it.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        automaticallyImplyActions: false,
        toolbarHeight: 12.0,
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24.0),
        children: [
          TodayScoreTile(
            score: viewModel.todayScore,
            onTap: () => viewModel.openScoreSheet(context, DateTime.now()),
          ),
          buildCalendar(context),
          ScoreMonthLineChart(
            scores: viewModel.scoresByDay,
            daysInMonth: viewModel.daysInMonth,
          ),
          // Hidden entirely when no month has data — an empty axis would be a
          // chart of nothing.
          if (viewModel.monthlyAverages.isNotEmpty) ScoreMonthlyAverageChart(months: viewModel.monthlyAverages),
        ],
      ),
    );
  }

  Widget buildCalendar(BuildContext context) {
    final firstDayOfWeek = context.select(
      (DevicePreferencesProvider provider) => provider.preferences.firstDayOfWeek,
    );

    return SpCalendar(
      showBottomBorder: true,
      initialYear: viewModel.year,
      initialMonth: viewModel.month,
      firstDayOfWeek: firstDayOfWeek,
      onMonthChanged: viewModel.onMonthChanged,
      controller: viewModel.calendarController,
      cellBuilder: (context, date, isDisplayMonth) {
        // The grid pages display months, so a cell's own `date.month` is not the
        // month being shown — `viewModel.scoresByDay` is already keyed by display
        // day for the month on screen.
        final int displayDay = CalendarDisplay.dayOf(date);

        return SpScoreCalendarDateCell(
          date: date,
          isDisplayMonth: isDisplayMonth,
          score: isDisplayMonth ? viewModel.scoresByDay[displayDay] : null,
          // The tapped date is the real Gregorian date, which is exactly what the
          // sheet stores against.
          onTap: isDisplayMonth ? () => viewModel.openScoreSheet(context, date) : null,
        );
      },
    );
  }
}
