import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/notifications/reminder_navigation_service.dart';
import 'package:storypad/core/services/notifications/reminder_schedule_planner.dart';
import 'package:storypad/core/services/notifications/reschedule_queue.dart';
import 'package:storypad/core/services/on_this_day_prediction_service.dart';
import 'package:storypad/core/storages/device_preferences_storage.dart';
import 'package:storypad/core/types/notification_channel.dart';
import 'package:storypad/core/types/reminder_type.dart';

/// Device-local scheduled reminders via flutter_local_notifications.
///
/// Reminders are per-device (not synced). Each [ReminderObject] can produce
/// several OS alarms:
///
///  * **daily / weekly** — one *repeating* alarm per weekday slot, matched by the
///    OS on every occurrence (`matchDateTimeComponents`). These never expire.
///  * **monthly / yearly** — a finite list of concrete dates produced by
///    [ReminderSchedulePlanner], because a Shamsi month is not a Gregorian one and
///    because a day that does not exist (31 Farvardin → 30 in a 30-day month) has
///    to be clamped per occurrence. The list covers
///    [ReminderSchedulePlanner.defaultCalendarOccurrenceCount] future dates; it is
///    replenished on app start, on resume and on every reminder edit, so the app
///    does **not** need to be running for them to fire, only to renew the window.
///
/// v1 uses inexact scheduling to avoid the SCHEDULE_EXACT_ALARM permission; the
/// OS may defer a reminder by a few minutes under Doze.
///
/// Reboots are handled natively: `ScheduledNotificationBootReceiver` is declared
/// in the manifest and restores the alarms the plugin persisted. A *time zone*
/// change is not broadcast to Dart, so [didChangeAppLifecycleState] compares the
/// device zone on resume and reschedules when it moved.
class LocalNotificationService with WidgetsBindingObserver {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  late final RescheduleQueue<List<ReminderObject>?> _rescheduleQueue = RescheduleQueue(_runReschedule);

  /// Notification ids are allocated per reschedule pass, starting at 1. Every
  /// pass cancels all of the app's notifications first, so nothing from a
  /// previous pass can collide; payloads (not ids) are what a tap needs.
  int _nextNotificationId = 1;

  /// The time zone identifier used for the current schedules, so a change can be
  /// detected on resume.
  String? _timeZoneIdentifier;

  bool get supported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (_initialized || !supported) return;
    _initialized = true;

    tz.initializeTimeZones();
    await _syncTimeZone();
    WidgetsBinding.instance.addObserver(this);

    final androidSettings = AndroidInitializationSettings(NotificationChannel.reminderCustom.androidIcon);
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        for (final type in ReminderType.values)
          if (type.notificationActionId case final actionId?)
            DarwinNotificationCategory(
              actionId,
              actions: [DarwinNotificationAction.plain(actionId, type.notificationActionLabel!)],
            ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: androidSettings, iOS: darwinSettings, macOS: darwinSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails!.notificationResponse;
      if (response != null) _onTap(response);
    }

    await rescheduleAll(DevicePreferencesStorage.appInstance.preferences.reminders);
  }

  Future<bool>? _pendingPermissionRequest;

  /// Requests OS notification permission. Returns true when granted.
  Future<bool> requestPermission() {
    return _pendingPermissionRequest ??= _requestPermission().whenComplete(() {
      _pendingPermissionRequest = null;
    });
  }

  Future<bool> _requestPermission() async {
    if (!supported) return false;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    if (Platform.isMacOS) {
      final macOS = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      return await macOS?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    return false;
  }

  /// True only when the platform *tells* us notifications are switched off.
  ///
  /// Unknown means "not blocked", so a platform quirk can never show a warning
  /// that is not true. Android is the active target; other platforms report
  /// `false` because their status cannot be read without a plugin-specific API.
  Future<bool> notificationsBlocked() async {
    if (!supported || !Platform.isAndroid) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      return enabled == false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels all reminder notifications and reschedules the enabled ones.
  Future<void> rescheduleAll(List<ReminderObject>? reminders) {
    if (!supported || !_initialized) return Future<void>.value();

    return _rescheduleQueue.schedule(reminders);
  }

  Future<void> _runReschedule(List<ReminderObject>? reminders, bool Function() isCurrent) async {
    if (!isCurrent()) return;

    _nextNotificationId = 1;
    await _plugin.cancelAll();

    for (final reminder in reminders ?? const <ReminderObject>[]) {
      if (!isCurrent()) return;
      if (reminder.type == ReminderType.custom && (reminder.message?.trim().isEmpty ?? true)) continue;
      if (reminder.enabled) await _schedule(reminder);
    }
  }

  Future<void> _schedule(ReminderObject reminder) async {
    // On-this-day fires only on dates that actually have past memories.
    if (reminder.type == ReminderType.onThisDay) {
      await _scheduleOnThisDay(reminder);
      return;
    }

    if (reminder.isCalendarRecurring) {
      await _scheduleCalendarRecurrence(reminder);
      return;
    }

    final details = _detailsFor(reminder.type);
    final payload = jsonEncode({'reminderId': reminder.id});
    final (title, body) = await ReminderNavigationService.copyFor(reminder);

    for (final slot in reminder.scheduleSlots) {
      final weekday = slot == 0 ? null : slot;
      await _plugin.zonedSchedule(
        id: _takeNotificationId(),
        title: title,
        body: body,
        scheduledDate: _nextInstance(hour: reminder.hour, minute: reminder.minute, weekday: weekday),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: weekday == null ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    }
  }

  /// Monthly/yearly reminders: a bounded list of concrete alarms in the app's
  /// displayed calendar, each one clamped independently.
  Future<void> _scheduleCalendarRecurrence(ReminderObject reminder) async {
    final occurrences = ReminderSchedulePlanner.calendarOccurrences(
      reminder,
      system: CalendarConfig.system,
      now: DateTime.now(),
    );
    if (occurrences.isEmpty) return;

    final details = _detailsFor(reminder.type);
    final payload = jsonEncode({'reminderId': reminder.id});
    final (title, body) = await ReminderNavigationService.copyFor(reminder);

    for (final occurrence in occurrences) {
      await _plugin.zonedSchedule(
        id: _takeNotificationId(),
        title: title,
        body: body,
        scheduledDate: _zoned(occurrence.at),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> _scheduleOnThisDay(ReminderObject reminder) async {
    final dates = await OnThisDayPredictionService.loadUpcomingMemoryDates(
      horizonDays: 30,
      maxResults: 20,
    );
    if (dates.isEmpty) return;

    final details = _detailsFor(reminder.type);
    final payload = jsonEncode({'reminderId': reminder.id});
    final now = tz.TZDateTime.now(tz.local);

    for (final date in dates) {
      final scheduled = tz.TZDateTime(tz.local, date.year, date.month, date.day, reminder.hour, reminder.minute);
      if (!scheduled.isAfter(now)) continue;

      final (title, body) = await ReminderNavigationService.copyFor(reminder);
      await _plugin.zonedSchedule(
        id: _takeNotificationId(),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  int _takeNotificationId() => _nextNotificationId++;

  /// A local wall-clock `DateTime` as an alarm in the device's time zone.
  tz.TZDateTime _zoned(DateTime local) =>
      tz.TZDateTime(tz.local, local.year, local.month, local.day, local.hour, local.minute);

  tz.TZDateTime _nextInstance({required int hour, required int minute, int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (weekday != null) {
      while (scheduled.weekday != weekday) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(Duration(days: weekday == null ? 1 : 7));
    }

    return scheduled;
  }

  NotificationDetails _detailsFor(ReminderType type) {
    final channel = type.channel;
    final actionId = type.notificationActionId;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.channelID,
        channel.channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: channel.androidIcon,
        actions: [
          if (actionId != null)
            AndroidNotificationAction(actionId, type.notificationActionLabel!, showsUserInterface: true),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: actionId),
      macOS: DarwinNotificationDetails(categoryIdentifier: actionId),
    );
  }

  /// Compares the device time zone with the one the alarms were built for and
  /// moves `tz.local` when it changed. Returns true when it changed.
  Future<bool> _syncTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final changed = _timeZoneIdentifier != null && _timeZoneIdentifier != info.identifier;
      _timeZoneIdentifier = info.identifier;
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return changed;
    } catch (_) {
      // Unknown zone or plugin failure: keep the current location (UTC at worst)
      // and do not claim a change we cannot verify.
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_initialized) return;
    unawaited(_refreshAfterResume());
  }

  /// A resume is the only reliable moment to notice a time-zone change and to
  /// slide the finite calendar-recurrence window forward. Both are cheap and
  /// idempotent; the queue coalesces them with any edit happening at the same
  /// time.
  Future<void> _refreshAfterResume() async {
    final timeZoneChanged = await _syncTimeZone();
    final reminders = DevicePreferencesStorage.appInstance.preferences.reminders;
    final hasCalendarReminders = reminders?.any((r) => r.enabled && r.isCalendarRecurring) ?? false;

    if (timeZoneChanged || hasCalendarReminders) {
      await rescheduleAll(reminders);
    }
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    int? reminderId;
    try {
      reminderId = (jsonDecode(payload) as Map<String, dynamic>)['reminderId'] as int?;
    } catch (_) {
      return;
    }
    if (reminderId == null) return;

    final reminder = DevicePreferencesStorage.appInstance.preferences.reminders
        ?.where((r) => r.id == reminderId)
        .firstOrNull;
    if (reminder == null) return;

    ReminderNavigationService.instance.handleTap(reminder, _navigatorKey);
  }
}
