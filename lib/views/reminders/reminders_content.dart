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
      subtitle: Text(reminderScheduleSummary(context, time: reminder.timeOfDay, weekdays: reminder.weekdays.toSet())),
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
        return reminderScheduleSummary(context, time: reminder.timeOfDay, weekdays: reminder.weekdays.toSet());
      case ReminderType.onThisDay:
        return tr('reminder.summary.around_time', namedArgs: {'S_TIME': time});
      case ReminderType.custom:
        return reminderScheduleSummary(context, time: reminder.timeOfDay, weekdays: reminder.weekdays.toSet());
    }
  }
}
