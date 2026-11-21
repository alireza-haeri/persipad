import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/reminder_recurrence.dart';
import 'package:storypad/core/types/reminder_type.dart';
import 'package:storypad/views/reminders/edit_custom_reminder/edit_custom_reminder_view_model.dart';

void main() {
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  EditCustomReminderViewModel viewModel({ReminderObject? reminder}) {
    final vm = EditCustomReminderViewModel(
      reminder: reminder ?? ReminderObject(id: 12, type: ReminderType.custom),
      isNew: reminder == null,
    );
    vm.messageController.text = 'Pay rent';
    return vm;
  }

  test('saving a monthly reminder stores the interval, anchor and intended day', () {
    final vm = viewModel();
    vm.setRecurrence(ReminderRecurrence.monthly);
    vm.setIntervalMonths(3);
    vm.setAnchorDate(DateTime(2026, 1, 31, 13, 45));

    final saved = vm.build();

    expect(saved.recurrence, ReminderRecurrence.monthly);
    expect(saved.intervalMonths, 3);
    expect(saved.anchorDate, DateTime(2026, 1, 31));
    expect(saved.anchorDay, 31);
    expect(saved.weekdays, isEmpty);
    expect(saved.message, 'Pay rent');
  });

  test('editing keeps the reminder id, type and enabled flag', () {
    final existing = ReminderObject(
      id: 21,
      type: ReminderType.custom,
      enabled: false,
      hour: 6,
      minute: 5,
      message: 'Old',
      tagIds: const [3],
    );
    final vm = EditCustomReminderViewModel(reminder: existing, isNew: false);
    vm.messageController.text = 'New';
    vm.setTime(const TimeOfDay(hour: 20, minute: 30));

    final saved = vm.build();

    expect(saved.id, 21);
    expect(saved.type, ReminderType.custom);
    expect(saved.enabled, isFalse);
    expect(saved.tagIds, [3]);
    expect(saved.hour, 20);
    expect(saved.minute, 30);
    expect(saved.message, 'New');
  });

  test('switching back to a weekday schedule clears the calendar fields', () {
    final vm = viewModel(
      reminder: ReminderObject(
        id: 13,
        type: ReminderType.custom,
        message: 'Pay rent',
        recurrence: ReminderRecurrence.monthly,
        intervalMonths: 6,
        anchorDate: DateTime(2026, 1, 31),
        anchorDay: 31,
      ),
    );
    vm.setRecurrence(ReminderRecurrence.weekly);
    vm.setWeekdays({1, 3});

    final saved = vm.build();

    expect(saved.recurrence, ReminderRecurrence.weekly);
    expect(saved.weekdays, [1, 3]);
    expect(saved.intervalMonths, isNull);
    expect(saved.anchorDate, isNull);
    expect(saved.anchorDay, isNull);
  });

  test('a weekly schedule with no days falls back to every day', () {
    final vm = viewModel();
    vm.setRecurrence(ReminderRecurrence.weekly);
    vm.setWeekdays({});

    final saved = vm.build();

    expect(saved.recurrence, ReminderRecurrence.daily);
    expect(saved.weekdays, isEmpty);
    expect(saved.intervalMonths, isNull);
  });

  test('a yearly reminder always stores a 12-month interval', () {
    final vm = viewModel();
    vm.setRecurrence(ReminderRecurrence.yearly);
    vm.setAnchorDate(DateTime(2026, 3, 21));

    final saved = vm.build();

    expect(saved.recurrence, ReminderRecurrence.yearly);
    expect(saved.intervalMonths, 12);
    expect(saved.anchorDay, 21);
  });

  test('a Persian-formatted anchor keeps the Persian day number', () {
    CalendarConfig.apply(system: CalendarSystemOption.persian);

    final vm = viewModel();
    vm.setRecurrence(ReminderRecurrence.yearly);
    // 30 Esfand 1403 = 2025-03-20.
    vm.setAnchorDate(PersianCalendar.toGregorian(1403, 12, 30));

    final saved = vm.build();

    expect(saved.anchorDate, DateTime(2025, 3, 20));
    expect(saved.anchorDay, 30);
    expect(vm.anchorDay, 30);
  });

  test('a monthly draft reports its next occurrence', () {
    final vm = viewModel();
    vm.setRecurrence(ReminderRecurrence.monthly);
    vm.setIntervalMonths(1);
    vm.setAnchorDate(DateTime.now().add(const Duration(days: 2)));
    vm.setTime(const TimeOfDay(hour: 23, minute: 59));

    final next = vm.nextOccurrence();
    expect(next, isNotNull);
    expect(next!.isAfter(DateTime.now()), isTrue);
  });
}
