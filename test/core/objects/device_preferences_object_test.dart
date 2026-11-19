import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/device_preferences_object.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/first_day_of_week_option.dart';

void main() {
  group('DevicePreferencesObject.initial', () {
    test('uses the Persian first-run calendar defaults', () {
      final preferences = DevicePreferencesObject.initial();

      expect(preferences.calendarSystem, CalendarSystemOption.persian);
      expect(preferences.firstDayOfWeek, FirstDayOfWeekOption.saturday);
      expect(preferences.weekendDays, [DateTime.friday]);
      expect(preferences.enableDailyScore, isTrue);
    });
  });
}
