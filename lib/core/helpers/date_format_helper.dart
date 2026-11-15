// ignore_for_file: non_constant_identifier_names, depend_on_referenced_packages

import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/persian_calendar.dart';

/// The app's date formatting choke point.
///
/// Every date the user reads goes through here, which is what makes a second
/// calendar cheap: the methods keep their signatures and internally switch to
/// Solar Hijri when the user picked it. Two rules follow from that:
///
///  * Callers must pass a **real** `DateTime`. A synthetic placeholder such as
///    `DateTime(2000, month)` cannot be converted (it is a different day in a
///    different calendar), so month *names* come from [monthName] instead.
///  * Storage is untouched. These methods only render; converting back (a month
///    the user picked → a Gregorian query range) is `CalendarDisplay`'s job.
///
/// Persian digits are used only when the app language is Persian, so an English
/// UI showing the Shamsi calendar still reads `1404/8/24` rather than mixing
/// numeral systems inside one sentence.
class DateFormatHelper {
  static bool get _persian => CalendarConfig.isPersian;

  static bool _usePersianDigits(Locale locale) => locale.languageCode == 'fa';

  static String _digits(String value, Locale locale) =>
      _usePersianDigits(locale) ? PersianCalendar.toPersianDigits(value) : value;

  static PersianDate _persianDate(DateTime date) => PersianCalendar.of(date);

  static String _persianMonthName(DateTime date, {bool short = false}) {
    final month = _persianDate(date).month;
    return short ? PersianCalendar.monthShortName(month) : PersianCalendar.monthName(month);
  }

  /// `۱۴۰۴/۸/۲۴` (or `1404/8/24`); terse and unambiguous in either order.
  static String _persianYmd(DateTime date, Locale locale) {
    final d = _persianDate(date);
    return _digits('${d.year}/${d.month}/${d.day}', locale);
  }

  static String _persianYMMMd(DateTime date, Locale locale) {
    final d = _persianDate(date);
    final name = PersianCalendar.monthName(d.month);
    final day = _digits('${d.day}', locale);
    final year = _digits('${d.year}', locale);
    return _usePersianDigits(locale) ? '$day $name $year' : '$name $day, $year';
  }

  static String _persianYMMMM(DateTime date, Locale locale) {
    final d = _persianDate(date);
    return '${PersianCalendar.monthName(d.month)} ${_digits('${d.year}', locale)}';
  }

  static String _persianMd(DateTime date, Locale locale) {
    final d = _persianDate(date);
    final name = PersianCalendar.monthName(d.month);
    final day = _digits('${d.day}', locale);
    return _usePersianDigits(locale) ? '$day $name' : '$name $day';
  }

  static String E(DateTime date, Locale locale) {
    // Weekday names are identical in every calendar, so the locale's own data is
    // always right and a new language needs no extra work for this.
    return DateFormat.E(locale.toLanguageTag()).format(date);
  }

  static String MMM(DateTime date, Locale locale) {
    if (_persian) return _persianMonthName(date, short: true);
    return DateFormat.MMM(locale.toLanguageTag()).format(date);
  }

  static String MMMM(DateTime date, Locale locale) {
    if (_persian) return _persianMonthName(date);
    return DateFormat.MMMM(locale.toLanguageTag()).format(date);
  }

  static String Md(DateTime date, Locale locale) {
    if (_persian) return _persianMd(date, locale);
    return DateFormat.Md(locale.toLanguageTag()).format(date);
  }

  static String d(DateTime date, Locale locale) {
    if (_persian) return _digits('${_persianDate(date).day}', locale);
    return DateFormat.d(locale.toLanguageTag()).format(date);
  }

  static String yMEd_jms(DateTime date, Locale locale) {
    if (_persian) return '${yMEd(date, locale)} - ${jms(date, locale)}';
    return DateFormat.yMEd(
      locale.toLanguageTag(),
    ).addPattern("- ${DateFormat.jms(locale.toLanguageTag()).pattern!}").format(date);
  }

  static String yMEd_jm(DateTime date, Locale locale) {
    if (_persian) return '${yMEd(date, locale)} - ${jm(date, locale)}';
    return DateFormat.yMEd(
      locale.toLanguageTag(),
    ).addPattern("- ${DateFormat.jm(locale.toLanguageTag()).pattern!}").format(date);
  }

  static String yMEd_Hms(DateTime date, Locale locale) {
    if (_persian) return '${yMEd(date, locale)} - ${Hms(date, locale)}';
    return DateFormat.yMEd(
      locale.toLanguageTag(),
    ).addPattern("- ${DateFormat.Hms(locale.toLanguageTag()).pattern!}").format(date);
  }

  static String yMEd_Hm(DateTime date, Locale locale) {
    if (_persian) return '${yMEd(date, locale)} - ${Hm(date, locale)}';
    return DateFormat.yMEd(
      locale.toLanguageTag(),
    ).addPattern("- ${DateFormat.Hm(locale.toLanguageTag()).pattern!}").format(date);
  }

  static String? yMEd_jmNullable(DateTime? date, Locale locale) {
    if (date == null) return null;
    return yMEd_jm(date, locale);
  }

  static String? yMEdNullable(DateTime? date, Locale locale) {
    if (date == null) return null;
    return yMEd(date, locale);
  }

  static String yMEd(DateTime date, Locale locale) {
    if (_persian) return '${E(date, locale)}، ${_persianYmd(date, locale)}';
    return DateFormat.yMEd(locale.toLanguageTag()).format(date);
  }

  static String jm(DateTime date, Locale locale) {
    return DateFormat.jm(locale.toLanguageTag()).format(date);
  }

  static String Hm(DateTime date, Locale locale) {
    return DateFormat.Hm(locale.toLanguageTag()).format(date);
  }

  static String Hms(DateTime date, Locale locale) {
    return DateFormat.Hms(locale.toLanguageTag()).format(date);
  }

  static String jms(DateTime date, Locale locale) {
    return DateFormat.jms(locale.toLanguageTag()).format(date);
  }

  static String yMd(DateTime date, Locale locale) {
    if (_persian) return _persianYmd(date, locale);
    return DateFormat.yMd(locale.toLanguageTag()).format(date);
  }

  static String yMMMd(DateTime date, Locale locale) {
    if (_persian) return _persianYMMMd(date, locale);
    return DateFormat.yMMMd(locale.toLanguageTag()).format(date);
  }

  static String yMMMM(DateTime date, Locale locale) {
    if (_persian) return _persianYMMMM(date, locale);
    return DateFormat.yMMMM(locale.toLanguageTag()).format(date);
  }

  static String y(DateTime date, Locale locale) {
    if (_persian) return _digits('${_persianDate(date).year}', locale);
    return DateFormat.y(locale.toLanguageTag()).format(date);
  }

  /// Month name for a month **number** in the active calendar.
  ///
  /// This exists because `DateTime(2000, month)` was used as a placeholder to
  /// get a month name — that trick silently breaks the moment the calendar is
  /// not Gregorian, since month 8 of year 2000 is not the same month as month 8
  /// of a Jalali year. Callers pass the month they actually mean.
  static String monthName(int month, Locale locale, {bool short = false}) {
    if (_persian) {
      return short ? PersianCalendar.monthShortName(month) : PersianCalendar.monthName(month);
    }
    return gregorianMonthName(month, locale, short: short);
  }

  /// Month name for a Gregorian month number, regardless of the active calendar.
  /// Only for surfaces whose data is still aggregated by Gregorian month (stats,
  /// monthly recap) — using it elsewhere would be exactly the bug [monthName]
  /// prevents.
  static String gregorianMonthName(int month, Locale locale, {bool short = false}) {
    final date = DateTime(2000, month);
    if (short) return DateFormat.MMM(locale.toLanguageTag()).format(date);
    return DateFormat.MMMM(locale.toLanguageTag()).format(date);
  }

  /// Same as [yMMMM] but always Gregorian. For surfaces whose data is still
  /// grouped by Gregorian month and whose grid still pages by Gregorian month —
  /// a Shamsi label there would describe a different month than the one shown.
  static String yMMMMGregorian(DateTime date, Locale locale) {
    return DateFormat.yMMMM(locale.toLanguageTag()).format(date);
  }

  static String gregorianYear(DateTime date, Locale locale) {
    return DateFormat.y(locale.toLanguageTag()).format(date);
  }

  static String? getDaySuffix(int day, Locale locale) {
    // Only English ordinals exist, and they are meaningless next to a Persian
    // day number.
    if (_persian) return null;
    if (locale.languageCode != 'en') return null;
    if (day >= 11 && day <= 13) return 'th';

    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
