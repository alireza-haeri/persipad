import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// One entry of the desktop sidebar, and the order the app ships them in.
///
/// The order lives in device preferences as the *names* of these values, so a
/// stored order stays readable and survives a reordering of this enum.
enum SidebarItemId {
  home(icon: SpIcons.home, weekday: 1),
  search(icon: SpIcons.search, weekday: 2),
  calendar(icon: SpIcons.calendar, weekday: 4),
  tags(icon: SpIcons.tag, weekday: 5);

  final IconData icon;

  /// Badge colour index for `SpSettingIconBadge`, 1–7.
  final int weekday;

  const SidebarItemId({required this.icon, required this.weekday});

  static const List<SidebarItemId> defaults = SidebarItemId.values;

  /// Turns a stored list of [name]s into a complete, duplicate-free order.
  ///
  /// Unknown names are dropped (an item removed in a later version must not come
  /// back from a stale preference) and anything the stored order does not mention
  /// is appended in [defaults] order.
  static List<SidebarItemId> parse(List<String>? names) {
    final List<SidebarItemId> ordered = [];

    for (final String name in names ?? const <String>[]) {
      for (final SidebarItemId item in values) {
        if (item.name == name && !ordered.contains(item)) ordered.add(item);
      }
    }

    for (final SidebarItemId item in defaults) {
      if (!ordered.contains(item)) ordered.add(item);
    }

    return ordered;
  }

  /// The names to persist for [order].
  static List<String> encode(List<SidebarItemId> order) => [for (final item in order) item.name];

  String get displayName {
    switch (this) {
      case SidebarItemId.home:
        return tr('page.home.title');
      case SidebarItemId.search:
        return tr('page.search.title');
      case SidebarItemId.calendar:
        return tr('page.calendar.title');
      case SidebarItemId.tags:
        return tr('page.tags.title');
    }
  }
}
