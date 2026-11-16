import 'dart:async';
import 'package:flutter/material.dart';
import 'package:storypad/core/services/window_appearance_service.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/extensions/font_weight_extension.dart';
import 'package:storypad/core/objects/app_quick_action_object.dart';
import 'package:storypad/core/objects/device_preferences_object.dart';
import 'package:storypad/core/objects/default_story_preferences_object.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/objects/story_tile_preferences_object.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/notifications/local_notification_service.dart';
import 'package:storypad/core/types/reminder_type.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';
import 'package:storypad/core/services/app_quick_actions_service.dart';
import 'package:storypad/core/types/asset_compression_option.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/first_day_of_week_option.dart';
import 'package:storypad/core/types/media_sync_option.dart';
import 'package:storypad/core/services/analytics/analytics_user_propery_service.dart';
import 'package:storypad/core/storages/device_preferences_storage.dart';
import 'package:storypad/core/types/appearance_preference_key.dart';
import 'package:storypad/core/types/font_size_option.dart';
import 'package:storypad/core/types/time_format_option.dart';

class DevicePreferencesProvider extends ChangeNotifier with WidgetsBindingObserver {
  static DevicePreferencesStorage get storage => DevicePreferencesStorage.appInstance;

  DevicePreferencesObject _preferences = storage.preferences;
  DevicePreferencesObject get preferences => _preferences;
  ThemeMode get themeMode => preferences.themeMode;

  /// Opt-in daily score feature: off by default, free for all users.
  bool get enableDailyScore => preferences.enableDailyScore ?? false;

  /// The desktop sidebar order, repaired against [SidebarItemId.defaults].
  List<SidebarItemId> get sidebarOrder => SidebarItemId.parse(preferences.sidebarOrder);

  /// Effective time format — falls back to the device's 24-hour setting when
  /// the user hasn't customized [DevicePreferencesObject.timeFormat].
  TimeFormatOption timeFormatOf(BuildContext context) => TimeFormatOption.resolve(context, preferences.timeFormat);

  final Map<String, List<void Function()>> _listeners = {};

  bool isDarkModeBaseOnThemeMode(BuildContext context) {
    if (themeMode == ThemeMode.system) {
      return View.maybeOf(context)?.platformDispatcher.platformBrightness == Brightness.dark;
    } else {
      return themeMode == ThemeMode.dark;
    }
  }

  /// Resets exactly the preferences named by [keys], leaving every other
  /// preference (region, stories, reminders, etc.) untouched.
  void resetAppearance(Set<AppearancePreferenceKey> keys) {
    if (keys.isEmpty) return;

    final defaults = DevicePreferencesObject.initial();
    var updated = _preferences;

    for (final key in keys) {
      updated = switch (key) {
        .themeMode => updated.copyWith(themeMode: defaults.themeMode),
        .colorSeed => updated.copyWith(colorSeedValue: defaults.colorSeedValue),
        .fontSize => updated.copyWith(fontSize: defaults.fontSize),
        .fontWeight => updated.copyWith(fontWeightIndex: defaults.fontWeightIndex),
        .dayColors => updated.copyWith(colorByDay: defaults.colorByDay),
        .storyTilePreferences => updated.copyWith(storyTilePreferences: defaults.storyTilePreferences),
      };
    }

    _preferences = updated;
    storage.writeObject(_preferences);
    notifyListeners();

    if (keys.contains(AppearancePreferenceKey.colorSeed)) {
      AnalyticsUserProperyService.instance.logSetColorSeedTheme(newColor: null);
    }

    if (keys.contains(AppearancePreferenceKey.themeMode)) {
      AnalyticsUserProperyService.instance.logSetThemeMode(newThemeMode: ThemeMode.system);
    }

    if (keys.contains(AppearancePreferenceKey.fontWeight)) {
      AnalyticsUserProperyService.instance.logSetFontWeight(newFontWeight: kDefaultFontWeight);
    }
  }

  void setColorSeed(Color color) {
    _preferences = _preferences.copyWith(
      // ignore: deprecated_member_use
      colorSeedValue: _preferences.colorSeedValue == color.value ? null : color.value,
    );

    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetColorSeedTheme(
      newColor: _preferences.colorSeed,
    );
  }

  void setColorForDay(int weekday, String colorName) {
    final updated = Map<int, String>.from(_preferences.colorByDay ?? {});
    updated[weekday] = colorName;

    _preferences = _preferences.copyWith(colorByDay: updated);
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void resetColorForDay(int weekday) {
    final updated = Map<int, String>.from(_preferences.colorByDay ?? {});
    updated.remove(weekday);

    _preferences = _preferences.copyWith(colorByDay: updated.isEmpty ? null : updated);
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void resetAllDayColors() {
    _preferences = _preferences.copyWith(colorByDay: null);
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void setThemeMode(ThemeMode? value) {
    if (value != null && value != themeMode) {
      _preferences = _preferences.copyWith(themeMode: value);
      storage.writeObject(_preferences);
      notifyListeners();

      AnalyticsUserProperyService.instance.logSetThemeMode(
        newThemeMode: value,
      );
    }
  }

  void setFontWeight(FontWeight fontWeight) {
    _preferences = _preferences.copyWith(fontWeightIndex: fontWeight.weightIndex);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetFontWeight(
      newFontWeight: fontWeight,
    );
  }

  void setFontSize(FontSizeOption? fontSize) {
    _preferences = _preferences.copyWith(fontSize: fontSize);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetFontSize(
      newFontSize: fontSize,
    );
  }

  void setTimeFormat(TimeFormatOption? timeFormat) {
    _preferences = _preferences.copyWith(timeFormat: timeFormat);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetTimeFormat(
      timeFormat: timeFormat,
    );
  }

  List<int> get weekendDays => CalendarConfig.normalizeWeekendDays(preferences.weekendDays);

  CalendarSystemOption get calendarSystem => preferences.calendarSystem;

  void setCalendarSystem(CalendarSystemOption value) {
    if (preferences.calendarSystem == value) return;

    _preferences = _preferences.copyWith(calendarSystem: value);
    CalendarConfig.apply(system: value);
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void setFirstDayOfWeek(FirstDayOfWeekOption value) {
    _preferences = _preferences.copyWith(firstDayOfWeek: value);
    CalendarConfig.apply(firstDayOfWeek: value);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetFirstDayOfWeek(
      firstDayOfWeek: value,
    );
  }

  void setWeekendDays(List<int> value) {
    final normalized = CalendarConfig.normalizeWeekendDays(value).toList();
    _preferences = _preferences.copyWith(weekendDays: normalized);
    CalendarConfig.apply(weekendDays: normalized);
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void setAssetCompression(AssetCompressionOption value) {
    _preferences = _preferences.copyWith(assetCompression: value);
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void setMediaSync(MediaSyncOption value) {
    _preferences = _preferences.copyWith(mediaSync: value);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetMediaSync(mediaSync: value);
  }

  void setStoryTilePreferences(StoryTilePreferencesObject preferences) {
    _preferences = _preferences.copyWith(storyTilePreferences: preferences);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logSetStoryTilePreferences(
      showTime: preferences.showTime,
      showPageCount: preferences.showPageCount,
      showTagLabels: preferences.showTagLabels,
      showVoiceCount: preferences.showVoiceCount,
      displayCharacterCount: preferences.displayCharacterCount,
    );
  }

  void setDefaultStoryPreferences(DefaultStoryPreferencesObject preferences) {
    _preferences = _preferences.copyWith(defaultStoryPreferences: preferences);
    storage.writeObject(_preferences);

    AnalyticsUserProperyService.instance.logSetDefaultStoryPreferences(
      defaultLayoutType: preferences.defaultLayoutType.name,
      hasColorSeed: preferences.defaultColorSeedValue != null,
      hasBackground: preferences.defaultBackgroundImagePath != null,
    );
  }

  void setHomeQuickActions(List<AppQuickActionObject>? actions) {
    _preferences = _preferences.copyWith(homeQuickActions: actions);
    storage.writeObject(_preferences);
    AppQuickActionsService.instance.setActions(actions);
  }

  void setEnableDailyScore(bool enabled) {
    _preferences = _preferences.copyWith(enableDailyScore: enabled);
    storage.writeObject(_preferences);
    notifyListeners();

    AnalyticsUserProperyService.instance.logToggleDailyScore(enabled: enabled);
  }

  void setSidebarOrder(List<SidebarItemId> order) {
    _preferences = _preferences.copyWith(sidebarOrder: SidebarItemId.encode(order));
    storage.writeObject(_preferences);
    notifyListeners();
  }

  void addListenerForVoicePlaybackSpeed(void Function() listener) {
    _listeners['voice_playback_speed'] ??= [];
    _listeners['voice_playback_speed']!.add(listener);
  }

  void removeListenerForVoicePlaybackSpeed(void Function() listener) {
    _listeners['voice_playback_speed']?.remove(listener);
  }

  void setVoicePlaybackSpeed(double speed) {
    _preferences = _preferences.copyWith(voicePlaybackSpeed: speed);
    storage.writeObject(_preferences);

    _listeners['voice_playback_speed']?.forEach((listener) => listener());
  }

  void addListenerForVideoPlaybackSpeed(void Function() listener) {
    _listeners['video_playback_speed'] ??= [];
    _listeners['video_playback_speed']!.add(listener);
  }

  void removeListenerForVideoPlaybackSpeed(void Function() listener) {
    _listeners['video_playback_speed']?.remove(listener);
  }

  void setVideoPlaybackSpeed(double speed) {
    _preferences = _preferences.copyWith(videoPlaybackSpeed: speed);
    storage.writeObject(_preferences);

    _listeners['video_playback_speed']?.forEach((listener) => listener());
  }

  void addListenerForVideoMuted(void Function() listener) {
    _listeners['video_muted'] ??= [];
    _listeners['video_muted']!.add(listener);
  }

  void removeListenerForVideoMuted(void Function() listener) {
    _listeners['video_muted']?.remove(listener);
  }

  void setVideoMuted(bool muted) {
    _preferences = _preferences.copyWith(videoMuted: muted);
    storage.writeObject(_preferences);

    _listeners['video_muted']?.forEach((listener) => listener());
  }

  List<String>? get hiddenStatsSections => preferences.hiddenStatsSections;

  void setHiddenStatsSections(List<String> sectionNames) {
    _preferences = _preferences.copyWith(hiddenStatsSections: sectionNames);
    storage.writeObject(_preferences);
  }

  List<ReminderObject> get reminders => preferences.reminders ?? const [];
  ReminderObject? reminderOfType(ReminderType type) => reminders.where((r) => r.type == type).firstOrNull;

  ReminderObject? get dailyReminder => reminderOfType(ReminderType.daily);
  ReminderObject? get onThisDayReminder => reminderOfType(ReminderType.onThisDay);

  List<ReminderObject> get customReminders =>
      reminders.where((r) => r.type == ReminderType.custom && (r.message?.trim().isNotEmpty ?? false)).toList();

  int get nextCustomReminderId {
    return reminders.map((r) => r.id).fold<int>(9, (a, b) => a > b ? a : b) + 1;
  }

  Future<void> _writeReminders(List<ReminderObject> updated) async {
    _preferences = _preferences.copyWith(reminders: updated);
    _listeners['reminders']?.forEach((listener) => listener());
    storage.writeObject(_preferences);

    unawaited(LocalNotificationService.instance.rescheduleAll(updated));
  }

  void addListenerForReminderChanges(void Function() listener) {
    _listeners['reminders'] ??= [];
    _listeners['reminders']!.add(listener);
  }

  void removeListenerForReminderChanges(void Function() listener) {
    _listeners['reminders']?.remove(listener);
  }

  Future<void> upsertReminder(ReminderObject reminder) async {
    final updated = List<ReminderObject>.from(reminders);
    final index = updated.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      updated[index] = reminder;
    } else {
      updated.add(reminder);
    }
    await _writeReminders(updated);
  }

  Future<void> deleteReminder(int id) async {
    final updated = reminders.where((r) => r.id != id).toList();
    await _writeReminders(updated);
  }

  Future<void> toggleReminder(int id, bool enabled) async {
    final updated = reminders.map((r) => r.id == id ? r.copyWith(enabled: enabled) : r).toList();
    await _writeReminders(updated);
  }

  Future<void> toggleThemeMode(
    BuildContext context, {
    Duration? delay,
  }) async {
    if (delay != null) await Future.delayed(delay, () {});
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  bool get isDarkMode {
    if (themeMode == ThemeMode.system) {
      Brightness? brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    } else {
      return themeMode == ThemeMode.dark;
    }
  }

  DevicePreferencesProvider() {
    WidgetsBinding.instance.addObserver(this);

    _setPlatformTheme();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();

    _setPlatformTheme();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();

    _setPlatformTheme();
  }

  void _setPlatformTheme() => WindowAppearanceService.setDark(isDarkMode);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
