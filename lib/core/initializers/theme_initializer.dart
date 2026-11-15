import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/storages/device_preferences_storage.dart';

class ThemeInitializer {
  static Future<void> call() async {
    await DevicePreferencesStorage.appInstance.load();
    publishCalendarConfig();
  }

  /// Copies the calendar preferences into [CalendarConfig], the process-wide
  /// snapshot that widgets without a `BuildContext` (the calendar grid) read.
  /// Runs once at startup, before the first frame, so the calendar never renders
  /// one frame with the default week layout and then jumps to the user's.
  static void publishCalendarConfig() {
    final preferences = DevicePreferencesStorage.appInstance.preferences;

    CalendarConfig.apply(
      firstDayOfWeek: preferences.firstDayOfWeek,
      weekendDays: preferences.weekendDays,
    );
  }
}
