// ignore_for_file: constant_identifier_names

enum NewBadge {
  none;

  static List<String> get keys => values.map((e) => e.name).toList();
}
