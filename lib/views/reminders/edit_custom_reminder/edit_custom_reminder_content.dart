part of 'edit_custom_reminder_view.dart';

class _EditCustomReminderContent extends StatelessWidget {
  const _EditCustomReminderContent(this.viewModel);

  final EditCustomReminderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    EdgeInsets safeContentPadding = EdgeInsets.only(
      left: math.max(MediaQuery.of(context).padding.left, 16.0),
      right: math.max(MediaQuery.of(context).padding.right, 16.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('page.reminders.add_reminder')),
        actions: [
          if (!viewModel.isNew)
            SpPopupMenuButton(
              items: (context) => [
                SpPopMenuItem(
                  titleStyle: TextStyle(color: Theme.of(context).colorScheme.error),
                  leadingIconData: SpIcons.delete,
                  title: tr('button.delete'),
                  onPressed: () => viewModel.delete(context),
                ),
              ],
              builder: (callback) => IconButton(
                tooltip: tr('button.more_options'),
                icon: const Icon(SpIcons.moreVert),
                onPressed: callback,
              ),
            ),
        ],
      ),
      body: Form(
        key: viewModel.formKey,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            SpSectionTitle(
              title: tr('reminder.field.message'),
              padding: safeContentPadding.copyWith(top: 4.0, bottom: 4.0),
            ),
            Padding(
              padding: safeContentPadding,
              child: _buildMessageField(context),
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(SpIcons.alarm),
              title: Text(tr('reminder.field.time')),
              trailing: Text(
                MaterialLocalizations.of(context).formatTimeOfDay(viewModel.time),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _pickTime(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.update),
              title: Text(tr('reminder.field.repeat')),
              trailing: Text(_repeatLabel(context), style: Theme.of(context).textTheme.titleMedium),
              onTap: () => _pickRecurrence(context),
            ),
            if (viewModel.recurrence == ReminderRecurrence.weekly)
              Padding(
                padding: safeContentPadding,
                child: ReminderWeekdaysChips(weekdays: viewModel.weekdays, onChanged: viewModel.setWeekdays),
              ),
            if (viewModel.recurrence == ReminderRecurrence.monthly) _buildIntervalTile(context),
            if (viewModel.isCalendarRecurring) _buildAnchorDateTile(context),
            const SizedBox(height: 12.0),
            Padding(
              padding: safeContentPadding,
              child: _buildScheduleHint(context),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(SpIcons.file),
              title: Text(tr('button.choose_template')),
              contentPadding: EdgeInsets.only(
                left: 16.0,
                right: viewModel.hasTemplate ? 8.0 : 16.0,
              ),
              subtitle: viewModel.hasTemplate && viewModel.templateName != null ? Text(viewModel.templateName!) : null,
              trailing: viewModel.hasTemplate
                  ? IconButton(icon: const Icon(SpIcons.clear), onPressed: viewModel.clearTemplate)
                  : Icon(SpIcons.next(context)),
              onTap: () => viewModel.chooseTemplate(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.tag),
              title: Text(tr('button.choose_tag')),
              contentPadding: EdgeInsets.only(
                left: 16.0,
                right: viewModel.tagIds.isNotEmpty ? 8.0 : 16.0,
              ),
              subtitle: viewModel.tagIds.isNotEmpty ? Text(viewModel.tagLabels(context)) : null,
              trailing: viewModel.tagIds.isNotEmpty
                  ? IconButton(icon: const Icon(SpIcons.clear), onPressed: viewModel.clearTags)
                  : Icon(SpIcons.next(context)),
              onTap: () => viewModel.chooseTags(context),
            ),
            const SizedBox(height: 16.0),
            Padding(
              padding: safeContentPadding,
              child: SizedBox(width: double.infinity, child: _buildSaveButton(context)),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    if (kIsCupertino) {
      return CupertinoButton.filled(
        disabledColor: Theme.of(context).disabledColor,
        sizeStyle: CupertinoButtonSize.medium,
        onPressed: () => viewModel.save(context),
        child: Text(tr('button.save')),
      );
    } else {
      return FilledButton(
        onPressed: () => viewModel.save(context),
        child: Text(tr('button.save')),
      );
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: viewModel.time);
    if (picked != null) viewModel.setTime(picked);
  }

  String _repeatLabel(BuildContext context) {
    switch (viewModel.recurrence) {
      case ReminderRecurrence.monthly:
        if (viewModel.intervalMonths <= 1) return tr('reminder.recurrence.monthly');
        return tr(
          'reminder.recurrence.every_n_months',
          namedArgs: {'S_COUNT': DateFormatHelper.number(viewModel.intervalMonths, context.locale)},
        );
      case ReminderRecurrence.yearly:
        return tr('reminder.recurrence.yearly');
      case ReminderRecurrence.weekly:
        return tr('reminder.recurrence.weekly');
      case ReminderRecurrence.daily:
        return tr('reminder.recurrence.every_day');
    }
  }

  String _recurrenceOptionLabel(BuildContext context, ReminderRecurrence recurrence) {
    switch (recurrence) {
      case ReminderRecurrence.daily:
        return tr('reminder.recurrence.every_day');
      case ReminderRecurrence.weekly:
        return tr('reminder.recurrence.weekly');
      case ReminderRecurrence.monthly:
        return tr('reminder.recurrence.monthly');
      case ReminderRecurrence.yearly:
        return tr('reminder.recurrence.yearly');
    }
  }

  Future<void> _pickRecurrence(BuildContext context) async {
    final selected = await showModalBottomSheet<ReminderRecurrence>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in ReminderRecurrence.values)
                ListTile(
                  leading: Icon(option == viewModel.recurrence ? SpIcons.checkCircle : SpIcons.checkboxBlank),
                  title: Text(_recurrenceOptionLabel(context, option)),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) viewModel.setRecurrence(selected);
  }

  Widget _buildIntervalTile(BuildContext context) {
    return ListTile(
      leading: const Icon(SpIcons.timer),
      title: Text(tr('reminder.field.interval')),
      trailing: DropdownButton<int>(
        value: viewModel.intervalMonths,
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value != null) viewModel.setIntervalMonths(value);
        },
        items: [
          for (var months = 1; months <= 12; months++)
            DropdownMenuItem<int>(value: months, child: Text(_intervalLabel(context, months))),
        ],
      ),
    );
  }

  String _intervalLabel(BuildContext context, int months) {
    if (months <= 1) return tr('reminder.recurrence.one_month');
    return tr(
      'reminder.recurrence.many_months',
      namedArgs: {'S_COUNT': DateFormatHelper.number(months, context.locale)},
    );
  }

  Widget _buildAnchorDateTile(BuildContext context) {
    return ListTile(
      leading: const Icon(SpIcons.calendar),
      title: Text(tr('reminder.field.start_date')),
      trailing: Text(
        DateFormatHelper.yMMMd(viewModel.anchorDate, context.locale),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => _pickAnchorDate(context),
    );
  }

  Future<void> _pickAnchorDate(BuildContext context) async {
    final picked = await SpDatePickerDialog.show(
      context: context,
      initialDate: viewModel.anchorDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) viewModel.setAnchorDate(picked);
  }

  Widget _buildScheduleHint(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final next = viewModel.nextOccurrence();
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reminderScheduleSummary(
            context,
            time: viewModel.time,
            weekdays: viewModel.recurrence == ReminderRecurrence.weekly ? viewModel.weekdays : const <int>{},
            recurrence: viewModel.recurrence,
            intervalMonths: viewModel.intervalMonths,
            anchorDate: viewModel.anchorDate,
            anchorDay: viewModel.anchorDay,
          ),
          style: style,
        ),
        if (viewModel.recurrence == ReminderRecurrence.monthly) ...[
          const SizedBox(height: 4),
          Text(tr('reminder.clamped_day_hint'), style: style),
        ],
        if (next != null && next.isAfter(now)) ...[
          const SizedBox(height: 4),
          Text(
            tr(
              'reminder.next_occurrence.at',
              namedArgs: {'SP_DATE': DateFormatHelper.yMMMd(next, context.locale)},
            ),
            style: style,
          ),
        ],
      ],
    );
  }

  Widget _buildMessageField(BuildContext context) {
    return FormField<String>(
      initialValue: viewModel.messageController.text,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => value?.trim().isNotEmpty == true ? null : tr('input.message.required'),
      builder: (state) {
        if (kIsCupertino) {
          return _buildCupertinoMessageField(context, state);
        } else {
          return _buildMaterialMessageField(context, state);
        }
      },
    );
  }

  Widget _buildMaterialMessageField(BuildContext context, FormFieldState<String> state) {
    return TextFormField(
      controller: viewModel.messageController,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: tr('reminder.field.message_hint'),
        border: const OutlineInputBorder(),
        errorText: state.errorText,
      ),
      maxLines: 2,
      onChanged: (value) => state.didChange(value),
    );
  }

  Widget _buildCupertinoMessageField(BuildContext context, FormFieldState<String> state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          controller: viewModel.messageController,
          textCapitalization: TextCapitalization.sentences,
          placeholder: tr('reminder.field.message_hint'),
          maxLines: 2,
          decoration: BoxDecoration(
            border: Border.all(
              color: state.hasError ? CupertinoColors.destructiveRed : CupertinoColors.systemGrey3.resolveFrom(context),
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          onChanged: (value) => state.didChange(value),
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 4.0),
            child: Text(
              state.errorText!,
              style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context), fontSize: 12.0),
            ),
          ),
      ],
    );
  }
}
