part of 'reminders_view.dart';

class _RemindersContent extends StatelessWidget {
  const _RemindersContent(this.viewModel);

  final RemindersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DevicePreferencesProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(tr('page.reminders.title'))),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          if (LocalNotificationService.instance.supported && Platform.isAndroid) const _NotificationBlockedBanner(),
          _buildBuiltinTile(context, provider, ReminderType.daily, SpIcons.newStory),
          _buildBuiltinTile(context, provider, ReminderType.onThisDay, SpIcons.history),
          const SizedBox(height: 8.0),
          const Divider(height: 1),
          const SizedBox(height: 4.0),
          for (final reminder in provider.customReminders) _buildCustomTile(context, reminder),
          ListTile(
            leading: const Icon(SpIcons.add),
            title: Text(tr('page.reminders.add_reminder')),
            onTap: () => viewModel.addCustomReminder(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBuiltinTile(
    BuildContext context,
    DevicePreferencesProvider provider,
    ReminderType type,
    IconData icon,
  ) {
    final reminder = provider.reminderOfType(type);
    final enabled = reminder?.enabled ?? false;

    void openSheet() => viewModel.openBuiltinEditor(context, reminder ?? ReminderObject.builtin(type));

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16.0, right: 12.0),
      leading: Icon(icon),
      title: Text(type.title),
      subtitle: Text(
        enabled && reminder != null ? _builtinEnabledSummary(context, type, reminder) : type.description,
      ),
      trailing: Switch.adaptive(value: enabled, onChanged: (_) => openSheet()),
      onTap: openSheet,
    );
  }

  Widget _buildCustomTile(BuildContext context, ReminderObject reminder) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16.0, right: 8.0),
      leading: const Icon(SpIcons.alarm),
      title: Text(reminder.message!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(reminderSummaryOf(context, reminder)),
      onTap: () => viewModel.openCustomEditor(context, reminder),
      trailing: Switch.adaptive(
        value: reminder.enabled,
        onChanged: (value) async {
          if (value && !await ensureNotificationPermission(context)) return;
          if (context.mounted) {
            await context.read<DevicePreferencesProvider>().toggleReminder(reminder.id, value);
          }
        },
      ),
    );
  }

  String _builtinEnabledSummary(BuildContext context, ReminderType type, ReminderObject reminder) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(reminder.timeOfDay);
    switch (type) {
      case ReminderType.daily:
        return reminderSummaryOf(context, reminder);
      case ReminderType.onThisDay:
        return tr('reminder.summary.around_time', namedArgs: {'S_TIME': time});
      case ReminderType.custom:
        return reminderSummaryOf(context, reminder);
    }
  }
}

/// Shows up only when Android reports that this app's notifications are off.
///
/// A reminder the OS silently drops is the worst failure mode: the user believes
/// the reminder exists. The banner names the actual fix instead of just saying
/// "denied", and "Retry" re-reads the OS state after the user changes it (there
/// is no cross-platform API to open the system settings page from here).
class _NotificationBlockedBanner extends StatefulWidget {
  const _NotificationBlockedBanner();

  @override
  State<_NotificationBlockedBanner> createState() => _NotificationBlockedBannerState();
}

class _NotificationBlockedBannerState extends State<_NotificationBlockedBanner> {
  late Future<bool> _blocked = LocalNotificationService.instance.notificationsBlocked();

  void _refresh() {
    setState(() => _blocked = LocalNotificationService.instance.notificationsBlocked());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _blocked,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();

        final colorScheme = ColorScheme.of(context);
        return Container(
          margin: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 8.0, 12.0),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(SpIcons.warning, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('reminder.notifications_blocked.title'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      tr('reminder.notifications_blocked.message'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _refresh,
                child: Text(tr('button.retry')),
              ),
            ],
          ),
        );
      },
    );
  }
}
