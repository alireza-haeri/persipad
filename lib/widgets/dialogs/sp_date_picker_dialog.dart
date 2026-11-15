import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/services/calendar/weekday_name_service.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// A calendar picker that draws whichever calendar the app is set to.
///
/// Flutter's `showDatePicker` can only render a Gregorian month (its grid comes
/// from `MaterialLocalizations`/`DateUtils`), so with the Shamsi calendar the
/// user would be picking from a Gregorian grid and then reading a Shamsi date —
/// the exact mismatch this replaces. Everything here goes through
/// [CalendarDisplay], so the grid, the header and the day numbers are in the
/// display calendar, while the value returned is always a real Gregorian
/// `DateTime` (dates are never stored in another calendar).
class SpDatePickerDialog extends StatefulWidget {
  const SpDatePickerDialog({
    super.key,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
  });

  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => SpDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }

  @override
  State<SpDatePickerDialog> createState() => _SpDatePickerDialogState();
}

class _SpDatePickerDialogState extends State<SpDatePickerDialog> {
  late DateTime _selected = _dateOnly(widget.initialDate);
  late int _shownYear = CalendarDisplay.yearOf(_selected);
  late int _shownMonth = CalendarDisplay.monthOf(_selected);

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime get _firstDate => widget.firstDate ?? DateTime(1900);
  DateTime get _lastDate => widget.lastDate ?? DateTime(2100);

  /// (year, month) [delta] months away in the *display* calendar. A calendar
  /// month is a month, so this is the same arithmetic in every calendar.
  ({int year, int month}) _shiftedMonth(int delta) {
    final zeroBased = _shownYear * 12 + (_shownMonth - 1) + delta;

    return (year: zeroBased ~/ 12, month: zeroBased % 12 + 1);
  }

  /// True when the whole month [delta] away is inside the allowed range, so the
  /// arrow can be disabled instead of silently doing nothing.
  bool _canShiftMonth(int delta) {
    final target = _shiftedMonth(delta);
    final start = CalendarDisplay.firstDayOfMonth(target.year, target.month);
    final end = CalendarDisplay.lastDayOfMonth(target.year, target.month);

    return !end.isBefore(_firstDate) && !start.isAfter(_lastDate);
  }

  void _shiftMonth(int delta) {
    if (!_canShiftMonth(delta)) return;

    final target = _shiftedMonth(delta);
    setState(() {
      _shownYear = target.year;
      _shownMonth = target.month;
    });
  }

  void _goToToday() {
    var today = _dateOnly(DateTime.now());
    if (today.isBefore(_firstDate)) today = _firstDate;
    if (today.isAfter(_lastDate)) today = _lastDate;

    setState(() {
      _selected = today;
      _shownYear = CalendarDisplay.yearOf(today);
      _shownMonth = CalendarDisplay.monthOf(today);
    });
  }

  bool _isSelectable(DateTime date) => !date.isBefore(_firstDate) && !date.isAfter(_lastDate);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      titlePadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      title: _buildHeader(context),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWeekdayHeader(context),
            const SizedBox(height: 4),
            _buildGrid(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _goToToday,
          child: Text(tr('general.date.today')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('button.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(
            tr('button.done'),
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final shownDate = CalendarDisplay.firstDayOfMonth(_shownYear, _shownMonth);

    return Row(
      children: [
        IconButton(
          onPressed: _canShiftMonth(-1) ? () => _shiftMonth(-1) : null,
          icon: const Icon(SpIcons.keyboardLeft),
        ),
        Expanded(
          child: Text(
            DateFormatHelper.yMMMM(shownDate, context.locale),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: _canShiftMonth(1) ? () => _shiftMonth(1) : null,
          icon: const Icon(SpIcons.keyboardRight),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: CalendarConfig.orderedWeekdays.map((weekday) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              WeekdayNameService.short(context.locale, weekday),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: CalendarConfig.isWeekendWeekday(weekday) ? ColorScheme.of(context).error : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final dates = CalendarDisplay.monthGridDates(
      year: _shownYear,
      month: _shownMonth,
      firstDayOfWeek: CalendarConfig.firstDayOfWeek.value,
    );

    return GridView.count(
      crossAxisCount: DateTime.daysPerWeek,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: dates.map((date) => _buildDay(context, date)).toList(),
    );
  }

  Widget _buildDay(BuildContext context, DateTime date) {
    final colorScheme = ColorScheme.of(context);
    final inMonth = CalendarDisplay.isInMonth(date, _shownYear, _shownMonth);
    final isSelected = date == _selected;
    final isToday = date == _dateOnly(DateTime.now());
    final selectable = _isSelectable(date);

    Color foreground = isSelected
        ? colorScheme.onPrimary
        : CalendarConfig.isWeekend(date)
        ? colorScheme.error
        : colorScheme.onSurface;

    if (!inMonth || !selectable) {
      foreground = foreground.withValues(alpha: 0.35);
    }

    return InkResponse(
      onTap: selectable
          ? () {
              setState(() {
                _selected = date;
                _shownYear = CalendarDisplay.yearOf(date);
                _shownMonth = CalendarDisplay.monthOf(date);
              });
            }
          : null,
      radius: 22,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? colorScheme.primary : null,
            border: isToday && !isSelected ? Border.all(color: colorScheme.primary) : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              DateFormatHelper.d(date, context.locale),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
