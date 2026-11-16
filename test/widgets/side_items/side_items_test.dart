import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';
import 'package:storypad/views/calendar/calendar_view.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/views/search/search_view.dart';
import 'package:storypad/views/tags/tags_view.dart';
import 'package:storypad/widgets/side_items/side_items.dart';

void main() {
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  List<Type> routesOf(List<SidebarItemId> order) {
    return SideItems.getSideMenuItems(order: order).map((item) => item.route.runtimeType).toList();
  }

  test('the default order is the one the app shipped', () {
    expect(routesOf(SidebarItemId.defaults), [HomeRoute, SearchRoute, CalendarRoute, TagsRoute]);
  });

  test('the stored order decides where each item sits', () {
    final order = SidebarItemId.parse(['calendar', 'home', 'search', 'tags']);

    expect(routesOf(order), [CalendarRoute, HomeRoute, SearchRoute, TagsRoute]);
  });

  test('isAvailable keeps every core sidebar item', () {
    expect(SideItems.isAvailable(SidebarItemId.home), isTrue);
    expect(SideItems.isAvailable(SidebarItemId.search), isTrue);
    expect(SideItems.isAvailable(SidebarItemId.calendar), isTrue);
    expect(SideItems.isAvailable(SidebarItemId.tags), isTrue);
  });

  test('each available item carries the label and icon of its id', () {
    final items = SideItems.getSideMenuItems(order: SidebarItemId.defaults);

    for (final item in items) {
      final SidebarItemId id = SidebarItemId.values.firstWhere((id) => id.icon == item.iconData);
      expect(item.title, id.displayName);
      expect(item.selectedIconData, id.icon);
    }
  });
}
