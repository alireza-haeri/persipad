import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/weekday_name_service.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/widgets/bottom_sheets/sp_weekend_days_sheet.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

class WeekendDaysTile extends StatelessWidget {
  const WeekendDaysTile({
    super.key,
    required this.weekday,
    required this.weekendDays,
    required this.onChanged,
  });

  final int weekday;
  final List<int> weekendDays;
  final void Function(List<int> value) onChanged;

  static Widget globalTheme({required int weekday}) {
    return Consumer<DevicePreferencesProvider>(
      builder: (context, provider, child) {
        return WeekendDaysTile(
          weekday: weekday,
          weekendDays: provider.weekendDays,
          onChanged: (value) => provider.setWeekendDays(value),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SpSettingIconBadge(weekday: weekday, icon: SpIcons.calendar),
      title: Text(context.tr('list_tile.weekend_days.title')),
      subtitle: Text(_label(context)),
      onTap: () {
        SpWeekendDaysSheet(
          weekendDays: weekendDays,
          onChanged: onChanged,
        ).show(context: context);
      },
    );
  }

  String _label(BuildContext context) {
    if (weekendDays.isEmpty) return context.tr('general.na');

    // Sorted from the user's own first day of the week, so an Iranian user who
    // starts the week on Saturday reads "Saturday, Friday"-style order rather
    // than an arbitrary Monday-first one.
    final ordered = CalendarConfig.orderedWeekdays.where(weekendDays.contains);
    return ordered.map((day) => WeekdayNameService.full(context.locale, day)).join(', ');
  }
}
