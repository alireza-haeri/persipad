import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';
import 'package:storypad/views/calendar/calendar_view.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/views/map/map_view.dart';
import 'package:storypad/views/relax_sounds/relax_sounds_view.dart';
import 'package:storypad/views/search/search_view.dart';
import 'package:storypad/views/tags/tags_view.dart';
import 'package:storypad/widgets/side_items/side_items.dart';

void main() {
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  List<Type> routesOf(List<SidebarItemId> order, {bool enableMap = true, bool enableRelaxSounds = false}) {
    return SideItems.getSideMenuItems(
      enableRelaxSounds: enableRelaxSounds,
      enableMap: enableMap,
      order: order,
    ).map((item) => item.route.runtimeType).toList();
  }

  test('the default order is the one the app shipped', () {
    expect(routesOf(SidebarItemId.defaults), [HomeRoute, SearchRoute, MapRoute, CalendarRoute, TagsRoute]);
  });

  test('the stored order decides where each item sits', () {
    final order = SidebarItemId.parse(['calendar', 'home', 'map', 'search', 'tags', 'relaxSounds']);

    expect(routesOf(order), [CalendarRoute, HomeRoute, MapRoute, SearchRoute, TagsRoute]);
  });

  test('turning the map add-on off removes the map and keeps everything else in place', () {
    final order = SidebarItemId.parse(['calendar', 'home', 'map', 'search', 'tags', 'relaxSounds']);

    expect(routesOf(order, enableMap: false), [CalendarRoute, HomeRoute, SearchRoute, TagsRoute]);
  });

  test('relax sounds needs both the add-on and pro features', () {
    final routes = routesOf(SidebarItemId.defaults, enableRelaxSounds: true);

    // This build may or may not ship pro features; the contract is the conjunction,
    // not "loud" — so the assertion follows the flag instead of assuming it.
    if (kProFeaturesAvailable) {
      expect(routes, contains(RelaxSoundsRoute));
    } else {
      expect(routes, isNot(contains(RelaxSoundsRoute)));
    }
  });

  test('isAvailable explains the same rule the sidebar applies', () {
    expect(SideItems.isAvailable(SidebarItemId.home, enableMap: false, enableRelaxSounds: false), isTrue);
    expect(SideItems.isAvailable(SidebarItemId.calendar, enableMap: false, enableRelaxSounds: false), isTrue);
    expect(SideItems.isAvailable(SidebarItemId.map, enableMap: true, enableRelaxSounds: false), isTrue);
    expect(SideItems.isAvailable(SidebarItemId.map, enableMap: false, enableRelaxSounds: false), isFalse);
    expect(SideItems.isAvailable(SidebarItemId.relaxSounds, enableMap: true, enableRelaxSounds: false), isFalse);
  });

  test('each available item carries the label and icon of its id', () {
    final items = SideItems.getSideMenuItems(
      enableRelaxSounds: false,
      enableMap: true,
      order: SidebarItemId.defaults,
    );

    for (final item in items) {
      final SidebarItemId id = SidebarItemId.values.firstWhere((id) => id.icon == item.iconData);
      expect(item.title, id.displayName);
      expect(item.selectedIconData, id.icon);
    }
  });
}
