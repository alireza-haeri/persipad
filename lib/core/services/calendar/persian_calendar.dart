/// The Solar Hijri (Jalali / Shamsi) calendar, in pure Dart.
///
/// Why hand-written instead of a package: the generated code in this repo is
/// committed and the agent sandbox cannot reach pub.dev, so a new dependency
/// would be unresolvable. The conversion is the standard arithmetical algorithm
/// (Borkowski / Khayyam, the same one used by jalaali-js and most Persian
/// calendar libraries) and is checked against published conversion vectors plus
/// a 45-year round-trip in the tests.
///
/// Everything here is *date-only*: a [DateTime]'s time of day is ignored, and
/// conversions return local midnights.
library;

class PersianDate {
  /// Solar Hijri year, e.g. 1405.
  final int year;

  /// 1 = Farvardin … 12 = Esfand.
  final int month;

  /// 1-based day of month.
  final int day;

  const PersianDate(this.year, this.month, this.day);

  @override
  String toString() => '$year/$month/$day';

  @override
  bool operator ==(Object other) => other is PersianDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

class PersianCalendar {
  PersianCalendar._();

  static const List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Indexed the Persian way: 0 = Saturday … 6 = Friday.
  static const List<String> weekdayNames = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

  /// Single-letter weekday labels, used as calendar column headers where a full
  /// name does not fit (each letter is already distinctive in Persian).
  static const List<String> weekdayShortNames = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  static const List<String> _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  static int _div(int a, int b) => (a / b).floor();

  /// Converts a (proleptic) Gregorian date to Solar Hijri.
  static PersianDate fromGregorian(int gregorianYear, int gregorianMonth, int gregorianDay) {
    const daysInMonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

    final gy2 = gregorianMonth > 2 ? gregorianYear + 1 : gregorianYear;
    var days =
        355666 +
        (365 * gregorianYear) +
        _div(gy2 + 3, 4) -
        _div(gy2 + 99, 100) +
        _div(gy2 + 399, 400) +
        gregorianDay +
        daysInMonth[gregorianMonth - 1];

    var jy = -1595 + (33 * _div(days, 12053));
    days %= 12053;
    jy += 4 * _div(days, 1461);
    days %= 1461;

    if (days > 365) {
      jy += _div(days - 1, 365);
      days = (days - 1) % 365;
    }

    if (days < 186) {
      return PersianDate(jy, 1 + _div(days, 31), 1 + (days % 31));
    }

    return PersianDate(jy, 7 + _div(days - 186, 30), 1 + ((days - 186) % 30));
  }

  /// Converts a Solar Hijri date to a Gregorian [DateTime] at local midnight.
  static DateTime toGregorian(int jy, int jm, int jd) {
    jy += 1595;
    var days =
        -355668 +
        (365 * jy) +
        (_div(jy, 33) * 8) +
        _div((jy % 33) + 3, 4) +
        jd +
        ((jm < 7) ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);

    var gy = 400 * _div(days, 146097);
    days %= 146097;

    if (days > 36524) {
      days--;
      gy += 100 * _div(days, 36524);
      days %= 36524;
      if (days >= 365) days++;
    }

    gy += 4 * _div(days, 1461);
    days %= 1461;

    if (days > 365) {
      gy += _div(days - 1, 365);
      days = (days - 1) % 365;
    }

    final leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
    final monthLengths = [0, 31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    var gd = days + 1;
    var gm = 1;
    while (gm <= 12 && gd > monthLengths[gm]) {
      gd -= monthLengths[gm];
      gm++;
    }

    return DateTime(gy, gm, gd);
  }

  static PersianDate of(DateTime date) => fromGregorian(date.year, date.month, date.day);

  static int yearOf(DateTime date) => of(date).year;
  static int monthOf(DateTime date) => of(date).month;
  static int dayOf(DateTime date) => of(date).day;

  /// A Jalali year has 366 days when the year after it starts a day later than
  /// the naive 365-day arithmetic suggests. Derived from the conversion above so
  /// the leap rule can never disagree with it.
  static bool isLeapYear(int year) {
    final start = toGregorian(year, 1, 1);
    final next = toGregorian(year + 1, 1, 1);
    return next.difference(start).inDays == 366;
  }

  static int daysInMonth(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    return isLeapYear(year) ? 30 : 29;
  }

  /// 0 = Saturday … 6 = Friday, matching [weekdayNames].
  static int weekdayIndexOf(DateTime date) => (date.weekday + 1) % DateTime.daysPerWeek;

  static String weekdayName(DateTime date) => weekdayNames[weekdayIndexOf(date)];
  static String weekdayShortName(DateTime date) => weekdayShortNames[weekdayIndexOf(date)];

  static String monthName(int month) => monthNames[(month - 1).clamp(0, 11)];

  /// Formats a date as `۱۴۰۵/۸/۲۴` (or `1405/8/24`), zero-padding nothing —
  /// this is the terse form used where space is tight.
  static String formatShort(DateTime date, {bool persianDigits = true}) {
    final d = of(date);
    final text = '${d.year}/${d.month}/${d.day}';
    return persianDigits ? toPersianDigits(text) : text;
  }

  static String toPersianDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final digit = int.tryParse(char);
      buffer.write(digit != null ? _persianDigits[digit] : char);
    }
    return buffer.toString();
  }
}
