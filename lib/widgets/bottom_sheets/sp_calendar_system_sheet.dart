import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/widgets/bottom_sheets/base_bottom_sheet.dart';
import 'package:storypad/widgets/sp_fade_in.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_single_state_widget.dart';

/// Picks the calendar the app displays (Gregorian or Solar Hijri).
///
/// Nothing is migrated or rewritten when this changes: every stored date stays
/// Gregorian, and only the rendering plus the "which day range does this month
/// mean" conversion changes. That is why the choice is a per-device preference
/// rather than something that touches the data.
class SpCalendarSystemSheet extends BaseBottomSheet {
  const SpCalendarSystemSheet({
    required this.calendarSystem,
    required this.onChanged,
  });

  final CalendarSystemOption calendarSystem;
  final void Function(CalendarSystemOption value) onChanged;

  @override
  bool get fullScreen => false;

  @override
  Widget build(BuildContext context, double bottomPadding) {
    return SpSingleStateWidget.listen(
      initialValue: calendarSystem,
      builder: (context, selectedValue, notifier) {
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...CalendarSystemOption.values.map((option) {
                final label = option.isPersian
                    ? tr('general.calendar_system.persian')
                    : tr('general.calendar_system.gregorian');

                return ListTile(
                  title: Text(label),
                  subtitle: option == CalendarSystemOption.defaultValue
                      ? Text(tr('general.default'))
                      : null,
                  trailing: Visibility(
                    visible: option == selectedValue,
                    child: SpFadeIn.fromBottom(
                      child: Icon(
                        SpIcons.checkCircle,
                        color: ColorScheme.of(context).primary,
                      ),
                    ),
                  ),
                  onTap: () {
                    notifier.value = option;
                    onChanged(option);
                  },
                );
              }),
              SizedBox(height: bottomPadding),
            ],
          ),
        );
      },
    );
  }
}
