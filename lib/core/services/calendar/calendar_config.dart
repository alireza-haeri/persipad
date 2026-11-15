import 'package:flutter/material.dart';
import 'package:storypad/core/types/first_day_of_week_option.dart';

/// Snapshot of the calendar-related device preferences that widgets need while
/// building UI.
///
/// Calendar settings are read from places that have no `BuildContext` and no
/// `Provider` access (calendar grid generators, small leaf widgets), so instead
/// of threading a provider through every one of them the app keeps one
/// read-mostly copy here. It is written in exactly two places:
///
///  * [ThemeInitializer] after the preferences are loaded from storage, so the
///    very first frame already uses the user's settings, and
///  * `DevicePreferencesProvider` whenever a calendar setting changes.
///
/// Nothing else may assign to [firstDayOfWeek] or [weekendDays]. Everything
/// reads them through the getters below, which are null-safe and always fall
/// back to the defaults so a partially initialized app can never crash.
class CalendarConfig {
  CalendarConfig._();

  /// Weekends shown when the user never picked a set of days. Saturday/Sunday
  /// is the old hard-coded behaviour and stays the default so existing users
  /// see no change until they choose otherwise.
  static const List<int> defaultWeekendDays = [DateTime.saturday, DateTime.sunday];

  static FirstDayOfWeekOption _firstDayOfWeek = FirstDayOfWeekOption.defaultValue;
  static List<int> _weekendDays = defaultWeekendDays;

  static FirstDayOfWeekOption get firstDayOfWeek => _firstDayOfWeek;

  /// Non-working days as `DateTime` weekday numbers (Monday = 1 … Sunday = 7),
  /// normalized to Monday-first order. An empty list is valid and means "no
  /// weekend at all"; `null` (never configured) means [defaultWeekendDays].
  static List<int> get weekendDays => _weekendDays;

  /// Weekdays ordered from [firstDayOfWeek] (Saturday-first for Persian users,
  /// Monday-first by default). Used for the weekday header row and for the
  /// chips that pick the weekend days.
  static List<int> get orderedWeekdays {
    final start = _firstDayOfWeek.value;
    return List.generate(
      DateTime.daysPerWeek,
      (index) => ((start + index - 1) % DateTime.daysPerWeek) + 1,
    );
  }

  static bool isWeekend(DateTime date) => _weekendDays.contains(date.weekday);

  static bool isWeekendWeekday(int weekday) => _weekendDays.contains(weekday);

  /// Applies the persisted preferences. Called by [ThemeInitializer] at startup
  /// and by the preferences provider on every change, so both paths go through
  /// the same normalization.
  static void apply({
    FirstDayOfWeekOption? firstDayOfWeek,
    List<int>? weekendDays,
  }) {
    if (firstDayOfWeek != null) _firstDayOfWeek = firstDayOfWeek;
    _weekendDays = normalizeWeekendDays(weekendDays);
  }

  /// Drops out-of-range weekdays and duplicates, keeping Monday-first order so
  /// the stored list has a single canonical shape no matter how the UI built
  /// it. `null` means "never configured" and resolves to the default.
  static List<int> normalizeWeekendDays(List<int>? days) {
    if (days == null) return defaultWeekendDays;
    final unique = days.where((day) => day >= DateTime.monday && day <= DateTime.sunday).toSet().toList()..sort();
    return List<int>.unmodifiable(unique);
  }

  /// Resets to the built-in defaults. Used by tests.
  @visibleForTesting
  static void reset() {
    _firstDayOfWeek = FirstDayOfWeekOption.defaultValue;
    _weekendDays = defaultWeekendDays;
  }
}
