import 'dart:ui' show Locale;

// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';

/// Turns a `DateTime` weekday number (Monday = 1 … Sunday = 7) into a localized
/// weekday name.
///
/// Weekday names are the same in every calendar system (the Persian week also
/// starts on Saturday and ends on Friday), so they can always come from the
/// active locale's `intl` data. Doing it this way means the Saturday/Friday
/// options added for Persian users are translated for free in all 21 bundled
/// languages, and a new locale needs no extra strings here.
class WeekdayNameService {
  WeekdayNameService._();

  /// 2024-01-07 is a Sunday, which makes the arithmetic below trivial.
  static final DateTime _referenceSunday = DateTime(2024, 1, 7);

  static DateTime dateOf(int weekday) {
    return _referenceSunday.add(Duration(days: weekday - DateTime.sunday));
  }

  static String full(Locale locale, int weekday) {
    return DateFormat.EEEE(locale.toLanguageTag()).format(dateOf(weekday));
  }

  static String short(Locale locale, int weekday) {
    return DateFormat.E(locale.toLanguageTag()).format(dateOf(weekday));
  }
}
