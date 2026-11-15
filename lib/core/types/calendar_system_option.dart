/// Which calendar the app *shows*. Storage is always Gregorian — every
/// `DateTime`, every `year`/`month`/`day` column in the database, and every
/// query stays Gregorian, so switching this value can never corrupt or migrate
/// data; it only changes how a stored date is rendered and how a month the user
/// picked is turned back into a date range to query.
enum CalendarSystemOption {
  gregorian,
  persian;

  static const defaultValue = CalendarSystemOption.gregorian;

  bool get isPersian => this == CalendarSystemOption.persian;
}
