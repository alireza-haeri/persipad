enum FirstDayOfWeekOption {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
  ;

  static const defaultValue = FirstDayOfWeekOption.monday;

  /// `DateTime` weekday number of this option (Monday = 1 … Sunday = 7).
  ///
  /// The calendar grid math works with [DateTime] weekdays, so this is the one
  /// place where the option is translated into one. Declared exhaustively (
  /// `switch` without `default`) so adding a value without teaching the grid
  /// about it is a compile error rather than a silent off-by-one.
  int get value {
    switch (this) {
      case FirstDayOfWeekOption.monday:
        return DateTime.monday;
      case FirstDayOfWeekOption.tuesday:
        return DateTime.tuesday;
      case FirstDayOfWeekOption.wednesday:
        return DateTime.wednesday;
      case FirstDayOfWeekOption.thursday:
        return DateTime.thursday;
      case FirstDayOfWeekOption.friday:
        return DateTime.friday;
      case FirstDayOfWeekOption.saturday:
        return DateTime.saturday;
      case FirstDayOfWeekOption.sunday:
        return DateTime.sunday;
    }
  }

  /// The option matching a `DateTime` weekday number.
  static FirstDayOfWeekOption fromValue(int weekday) {
    return FirstDayOfWeekOption.values.firstWhere(
      (option) => option.value == weekday,
      orElse: () => defaultValue,
    );
  }
}
