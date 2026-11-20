import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/databases/models/tag_db_model.dart';
import 'package:storypad/core/databases/models/template_db_model.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/objects/calendar_reminder_schedule.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/services/gallery_template_service.dart';
import 'package:storypad/core/services/notifications/reminder_schedule_planner.dart';
import 'package:storypad/core/types/reminder_recurrence.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/providers/tags_provider.dart';
import 'package:storypad/views/templates/templates_view.dart';
import 'package:storypad/widgets/bottom_sheets/sp_tags_picker_sheet.dart';
import 'package:storypad/widgets/bottom_sheets/sp_templates_picker_sheet.dart';

class EditCustomReminderViewModel extends ChangeNotifier with DisposeAwareMixin {
  EditCustomReminderViewModel({
    required this.reminder,
    required this.isNew,
  }) : messageController = TextEditingController(text: reminder.message ?? '') {
    time = reminder.timeOfDay;

    // Show the stored recurrence as-is: a legacy weekday reminder opens on
    // "selected days" with its days checked, a monthly one on its interval and
    // anchor, so editing never silently rewrites the schedule.
    recurrence = reminder.effectiveRecurrence;
    intervalMonths = reminder.effectiveIntervalMonths;

    final today = DateTime.now();
    final anchor = reminder.anchorDate ?? DateTime(today.year, today.month, today.day);
    anchorDate = DateTime(anchor.year, anchor.month, anchor.day);

    // Every day is stored as an empty set — show it as all 7 chips checked
    // so the user can see the current schedule before pruning it down.
    weekdays = reminder.weekdays.isEmpty ? ReminderObject.allWeekdays.toSet() : reminder.weekdays.toSet();
    templateId = reminder.templateId;
    galleryTemplateId = reminder.galleryTemplateId;
    tagIds = List<int>.from(reminder.tagIds ?? const []);

    // Editing an existing reminder that already has a saved template — its
    // display name wasn't cached, so resolve it once on load.
    if (hasTemplate) _loadTemplateName();
  }

  /// The reminder being edited. Its `enabled` flag isn't user-editable on this
  /// page (only the reminders list toggle changes it) — preserved as-is on save.
  final ReminderObject reminder;

  /// True while creating a brand-new reminder — nothing's persisted yet, so
  /// Delete isn't offered.
  final bool isNew;

  final formKey = GlobalKey<FormState>();

  /// Backs the adaptive message field (Material/Cupertino share it) so typing
  /// doesn't need a `notifyListeners()` round-trip through the view model.
  final TextEditingController messageController;

  late TimeOfDay time;
  late Set<int> weekdays;
  late ReminderRecurrence recurrence;

  /// 1..12, only used by [ReminderRecurrence.monthly].
  late int intervalMonths;

  /// Gregorian date of the anchor month with the selected day. Always date-only.
  late DateTime anchorDate;

  late int? templateId;
  late String? galleryTemplateId;
  late List<int> tagIds;

  /// Display name for the selected template, if any. Null while unset or
  /// still being resolved (see constructor).
  String? templateName;

  bool get hasTemplate => templateId != null || galleryTemplateId != null;

  bool get isCalendarRecurring => recurrence.isCalendarBased;

  /// The day number the user is choosing, in the calendar they are reading.
  int get anchorDay => CalendarDisplay.dayOf(anchorDate);

  void setTime(TimeOfDay value) {
    time = value;
    notifyListeners();
  }

  void setWeekdays(Set<int> value) {
    weekdays = value;
    notifyListeners();
  }

  void setRecurrence(ReminderRecurrence value) {
    recurrence = value;
    // Entering "selected days" with nothing selected would be a schedule with no
    // days at all; start from every day so the chips always mean what they show.
    if (value == ReminderRecurrence.weekly && weekdays.isEmpty) {
      weekdays = ReminderObject.allWeekdays.toSet();
    }
    notifyListeners();
  }

  void setIntervalMonths(int value) {
    intervalMonths = value.clamp(1, 12);
    notifyListeners();
  }

  void setAnchorDate(DateTime value) {
    anchorDate = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  /// The reminder `save` would persist. Pure, so the mapping between the editor
  /// and the stored schedule can be tested without a widget.
  ReminderObject build() {
    final trimmedMessage = messageController.text.trim();
    final normalizedWeekdays = ReminderObject.normalizeWeekdays(weekdays);
    final effectiveRecurrence = recurrence == ReminderRecurrence.weekly && normalizedWeekdays.isEmpty
        ? ReminderRecurrence.daily
        : recurrence;

    return reminder.copyWith(
      hour: time.hour,
      minute: time.minute,
      recurrence: effectiveRecurrence,
      weekdays: effectiveRecurrence == ReminderRecurrence.weekly ? normalizedWeekdays : const <int>[],
      intervalMonths: effectiveRecurrence == ReminderRecurrence.monthly
          ? intervalMonths
          : (effectiveRecurrence == ReminderRecurrence.yearly ? CalendarReminderSchedule.maxIntervalMonths : null),
      anchorDate: effectiveRecurrence.isCalendarBased ? anchorDate : null,
      anchorDay: effectiveRecurrence.isCalendarBased ? anchorDay : null,
      message: trimmedMessage.isNotEmpty ? trimmedMessage : null,
      templateId: templateId,
      galleryTemplateId: galleryTemplateId,
      tagIds: tagIds.isNotEmpty ? tagIds : null,
    );
  }

  /// When this draft would next notify, or null for a disabled reminder.
  DateTime? nextOccurrence() {
    return ReminderSchedulePlanner.nextOccurrence(
      build(),
      system: CalendarConfig.system,
      now: DateTime.now(),
    );
  }

  Future<void> chooseTemplate(BuildContext context) async {
    final result = await const SpTemplatesPickerSheet().show<TemplatePickResult>(context: context);
    if (result == null) return;

    switch (result.type) {
      case TemplatePickResultType.custom:
        templateId = result.customTemplate?.id;
        galleryTemplateId = null;
        break;
      case TemplatePickResultType.gallery:
        galleryTemplateId = result.galleryTemplate?.id;
        templateId = null;
        break;
    }
    templateName = result.label;
    notifyListeners();
  }

  void clearTemplate() {
    templateId = null;
    galleryTemplateId = null;
    templateName = null;
    notifyListeners();
  }

  Future<void> _loadTemplateName() async {
    if (templateId != null) {
      final template = await TemplateDbModel.db.find(templateId!);
      templateName = template?.name ?? tr('general.na');
    } else if (galleryTemplateId != null) {
      final templatesByCategory = await GalleryTemplateService.loadTemplates();
      for (final templates in templatesByCategory.values) {
        for (final template in templates) {
          if (template.id == galleryTemplateId) {
            templateName = template.name;
            break;
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> chooseTags(BuildContext context) async {
    final result = await SpTagsPickerSheet(selectedTagIds: tagIds).show<List<TagDbModel>>(context: context);
    if (result == null) return;

    tagIds = result.map((e) => e.id).toList();
    notifyListeners();
  }

  void clearTags() {
    tagIds = [];
    notifyListeners();
  }

  String tagLabels(BuildContext context) {
    final allTags = context.read<TagsProvider>().allTags?.items ?? [];
    final titles = tagIds.map((id) => allTags.where((t) => t.id == id).firstOrNull?.title).whereType<String>().toList();
    return titles.join(', ');
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> save(BuildContext context) async {
    if (formKey.currentState?.validate() != true) return;

    await context.read<DevicePreferencesProvider>().upsertReminder(build());
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> delete(BuildContext context) async {
    await context.read<DevicePreferencesProvider>().deleteReminder(reminder.id);
    if (context.mounted) Navigator.of(context).pop(true);
  }
}
