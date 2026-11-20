import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/services/notifications/reminder_navigation_service.dart';
import 'package:storypad/core/services/notifications/reschedule_queue.dart';
import 'package:storypad/core/services/on_this_day_prediction_service.dart';
import 'package:storypad/core/storages/device_preferences_storage.dart';
import 'package:storypad/core/types/notification_channel.dart';
import 'package:storypad/core/types/reminder_type.dart';

/// Device-local scheduled reminders via flutter_local_notifications.
///
/// Reminders are per-device (not synced). Each [ReminderObject] can produce
/// several OS notifications — one per selected weekday — using a derived id so
/// each slot can be cancelled/rescheduled independently.
///
/// v1 uses inexact scheduling to avoid the SCHEDULE_EXACT_ALARM permission.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  late final RescheduleQueue<List<ReminderObject>?> _rescheduleQueue = RescheduleQueue(_runReschedule);

  bool get supported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (_initialized || !supported) return;
    _initialized = true;

    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to the default (UTC) location; reminders still fire, just in UTC.
    }

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

  /// Cancels all reminder notifications and reschedules the enabled ones.
  Future<void> rescheduleAll(List<ReminderObject>? reminders) {
    if (!supported || !_initialized) return Future<void>.value();

    return _rescheduleQueue.schedule(reminders);
  }

  Future<void> _runReschedule(List<ReminderObject>? reminders, bool Function() isCurrent) async {
    if (!isCurrent()) return;

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

    final details = _detailsFor(reminder.type);
    final payload = jsonEncode({'reminderId': reminder.id});

    for (final slot in reminder.scheduleSlots) {
      final weekday = slot == 0 ? null : slot;
      final (title, body) = await ReminderNavigationService.copyFor(reminder);
      await _plugin.zonedSchedule(
        id: _notificationId(reminder.id, slot),
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
        id: _dateNotificationId(reminder.id, date),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  int _notificationId(int reminderId, int slot) => reminderId * 10 + slot;

  int _dateNotificationId(int reminderId, DateTime date) => reminderId * 100000 + date.month * 100 + date.day;

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
