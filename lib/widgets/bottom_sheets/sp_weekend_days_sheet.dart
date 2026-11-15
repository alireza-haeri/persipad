import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/weekday_name_service.dart';
import 'package:storypad/widgets/bottom_sheets/base_bottom_sheet.dart';

/// Lets the user pick which weekdays count as weekend / non-working days.
///
/// The set is fully user-defined instead of a fixed Saturday+Sunday, because
/// "weekend" is a regional fact: Iran rests on Friday (and often Thursday),
/// while most of Europe rests on Saturday+Sunday. Nothing outside the calendar
/// UI depends on a specific pair of days, so any subset — including none — is
/// a valid answer and is stored as-is.
class SpWeekendDaysSheet extends BaseBottomSheet {
  const SpWeekendDaysSheet({
    required this.weekendDays,
    required this.onChanged,
  });

  final List<int> weekendDays;
  final void Function(List<int> value) onChanged;

  @override
  bool get fullScreen => false;

  @override
  Widget build(BuildContext context, double bottomPadding) {
    return _SpWeekendDaysContent(
      weekendDays: weekendDays,
      onChanged: onChanged,
      bottomPadding: bottomPadding,
    );
  }
}

class _SpWeekendDaysContent extends StatefulWidget {
  const _SpWeekendDaysContent({
    required this.weekendDays,
    required this.onChanged,
    required this.bottomPadding,
  });

  final List<int> weekendDays;
  final void Function(List<int> value) onChanged;
  final double bottomPadding;

  @override
  State<_SpWeekendDaysContent> createState() => _SpWeekendDaysContentState();
}

class _SpWeekendDaysContentState extends State<_SpWeekendDaysContent> {
  late final Set<int> _selected = {...widget.weekendDays};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              tr('list_tile.weekend_days.subtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorScheme.of(context).onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ...CalendarConfig.orderedWeekdays.map((weekday) {
            return CheckboxListTile(
              value: _selected.contains(weekday),
              title: Text(WeekdayNameService.full(context.locale, weekday)),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(weekday);
                  } else {
                    _selected.remove(weekday);
                  }
                });

                // Stored Monday-first and deduplicated; an empty set is a
                // deliberate "no weekend" answer and is kept as empty.
                widget.onChanged(CalendarConfig.normalizeWeekendDays(_selected.toList()).toList());
              },
            );
          }),
          SizedBox(height: widget.bottomPadding),
        ],
      ),
    );
  }
}
