/// How a reminder repeats.
///
/// [daily] and [weekly] are driven by [ReminderObject.weekdays] and are
/// scheduled as *repeating* OS notifications. [monthly] and [yearly] are
/// calendar-relative: they follow the app's displayed calendar (Gregorian or
/// Solar Hijri), so their concrete dates cannot be expressed with one repeating
/// OS rule — see `ReminderSchedulePlanner` and `D-068`.
enum ReminderRecurrence {
  daily,
  weekly,
  monthly,
  yearly;

  /// True when the dates depend on the displayed calendar and therefore have to
  /// be calculated one by one instead of handed to the OS as a repeat rule.
  bool get isCalendarBased => this == ReminderRecurrence.monthly || this == ReminderRecurrence.yearly;
}
