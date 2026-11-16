enum NotificationChannel {
  reminderDaily(
    channelID: 'reminder_daily',
    channelName: 'Daily Reminders',
    androidIcon: 'ic_alarm',
  ),
  reminderOnThisDay(
    channelID: 'reminder_on_this_day',
    channelName: 'On This Day',
    androidIcon: 'ic_history',
  ),
  reminderCustom(
    channelID: 'reminder_custom',
    channelName: 'Custom Reminders',
    androidIcon: 'ic_notifications',
  );

  const NotificationChannel({
    required this.channelID,
    required this.channelName,
    required this.androidIcon,
  });

  final String channelID;
  final String channelName;

  /// Android status-bar icon resource name (no extension), one per channel so
  /// each reminder type can render its own glyph. Native drawables live under
  /// `android/app/src/main/res/drawable*/` — generated via Android Asset
  /// Studio's notification-icon tool, see docs/development/android-config.md
  /// ("Notification Icons"). Unlike quick-action icons, these must be flat
  /// white silhouettes — the OS strips any color at render time.
  final String androidIcon;
}
