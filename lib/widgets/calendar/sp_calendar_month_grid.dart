part of 'sp_calendar.dart';

/// A single month calendar grid widget.
///
/// Displays a grid of dates for a specific month, including overflow dates
/// from previous and next months to fill the grid.
///
/// The rows arrive one after another when the page is first built. A month of 42
/// cells appearing all at once reads as a texture rather than as a calendar; giving
/// each row 60ms of head start and a 6pt lift makes the grid feel like it is being
/// drawn for the month you asked for (D-036 §1).
class _SpCalendarMonthGrid extends StatefulWidget {
  const _SpCalendarMonthGrid({
    required this.year,
    required this.month,
    required this.firstDayOfWeek,
    required this.cellBuilder,
  });

  final int year;
  final int month;
  final FirstDayOfWeekOption firstDayOfWeek;
  final Widget Function(BuildContext context, DateTime date, bool isCurrentMonth) cellBuilder;

  @override
  State<_SpCalendarMonthGrid> createState() => _SpCalendarMonthGridState();
}

class _SpCalendarMonthGridState extends State<_SpCalendarMonthGrid> with SingleTickerProviderStateMixin {
  /// One controller for the whole grid rather than one per cell: 42 animations that
  /// must start together are cheaper as intervals on a single timeline, and it keeps
  /// every cell out of the per-frame rebuild (see [_GridCellEntrance]).
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleDays = CalendarDaysGenerator.generate(
      year: widget.year,
      month: widget.month,
      firstDayOfWeek: widget.firstDayOfWeek,
    );
    const crossAxisCount = DateTime.daysPerWeek;
    final itemCount = visibleDays.length;
    final int rows = (itemCount / crossAxisCount).ceil();

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        mainAxisSpacing: 0.0,
        crossAxisSpacing: 0.0,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final date = visibleDays[index];
        // In the display calendar: a Shamsi month starts mid-Gregorian-month, so
        // comparing `date.month` would shade the first three weeks of every grid.
        final isCurrentMonth = CalendarDisplay.isInMonth(date, widget.year, widget.month);

        // Rows are staggered, cells within a row are not: the month drops in as
        // weeks, which is how it is read.
        final int row = index ~/ crossAxisCount;
        final double begin = rows <= 1 ? 0.0 : (row / rows) * 0.6;

        return _GridCellEntrance(
          animation: _entrance,
          begin: begin,
          child: widget.cellBuilder(context, date, isCurrentMonth),
        );
      },
    );
  }
}

/// Fades and lifts one cell into place, without rebuilding the cell itself.
class _GridCellEntrance extends StatelessWidget {
  const _GridCellEntrance({
    required this.animation,
    required this.begin,
    required this.child,
  });

  /// The grid's shared timeline.
  final Animation<double> animation;

  /// Where in that timeline this cell starts, 0–1.
  final double begin;

  /// How much of the timeline one cell's own entrance takes.
  static const double _span = 0.4;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // The cell is handed to the builder as `child`, so it is built once and only
      // the opacity and the offset are recomputed per frame.
      child: child,
      builder: (context, child) {
        final double raw = ((animation.value - begin) / _span).clamp(0.0, 1.0).toDouble();
        final double progress = Curves.easeOutCubic.transform(raw);

        return Opacity(
          opacity: progress,
          child: Transform.translate(offset: Offset(0.0, (1.0 - progress) * 6.0), child: child),
        );
      },
    );
  }
}
