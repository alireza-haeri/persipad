import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/storages/search_filter_storage.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/widgets/bottom_sheets/sp_calendar_system_sheet.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

class CalendarSystemTile extends StatelessWidget {
  const CalendarSystemTile({
    super.key,
    required this.weekday,
    required this.calendarSystem,
    required this.onChanged,
  });

  final int weekday;
  final CalendarSystemOption calendarSystem;
  final void Function(CalendarSystemOption value) onChanged;

  static Widget globalTheme({required int weekday}) {
    return Consumer<DevicePreferencesProvider>(
      builder: (context, provider, child) {
        return CalendarSystemTile(
          weekday: weekday,
          calendarSystem: provider.calendarSystem,
          onChanged: (value) async {
            provider.setCalendarSystem(value);
            // The list is scoped to a *display* year/month, and the same year
            // number means a different span in the other calendar. Re-anchor on
            // today (rather than just reloading the same year, which would show
            // an empty 2026-as-a-Jalali-year and look broken).
            await HomeView.resetToToday();

            // The saved search filter carries *display* years, which mean a
            // different span in the other calendar — restoring "1405" as a
            // Gregorian year would silently filter everything out.
            SearchFilterStorage().remove();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SpSettingIconBadge(weekday: weekday, icon: SpIcons.calendar),
      title: Text(context.tr('list_tile.calendar_system.title')),
      subtitle: Text(
        calendarSystem == CalendarSystemOption.persian
            ? context.tr('general.calendar_system.persian')
            : context.tr('general.calendar_system.gregorian'),
      ),
      onTap: () {
        SpCalendarSystemSheet(
          calendarSystem: calendarSystem,
          onChanged: onChanged,
        ).show(context: context);
      },
    );
  }
}
