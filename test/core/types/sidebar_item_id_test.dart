import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';

void main() {
  group('SidebarItemId.parse', () {
    test('no stored order means the shipped one', () {
      expect(SidebarItemId.parse(null), SidebarItemId.defaults);
      expect(SidebarItemId.parse(const []), SidebarItemId.defaults);
    });

    test('a stored order is respected, in full', () {
      final order = SidebarItemId.parse([
        'calendar',
        'map',
        'home',
        'search',
        'tags',
        'relaxSounds',
      ]);

      expect(order, [
        SidebarItemId.calendar,
        SidebarItemId.map,
        SidebarItemId.home,
        SidebarItemId.search,
        SidebarItemId.tags,
        SidebarItemId.relaxSounds,
      ]);
      expect(order.length, SidebarItemId.values.length, reason: 'every item is still there');
    });

    test('an item added after the user customized is appended, not lost', () {
      // A stored order from a version that had fewer items: the new one must still
      // appear, and it must appear at the end rather than at a position the user
      // never chose.
      final order = SidebarItemId.parse(['calendar', 'home']);

      expect(order.take(2), [SidebarItemId.calendar, SidebarItemId.home]);
      expect(order.toSet(), SidebarItemId.values.toSet());
      expect(order.length, SidebarItemId.values.length);
    });

    test('unknown and duplicate names are dropped', () {
      final order = SidebarItemId.parse(['calendar', 'nonsense', 'calendar', '', 'home']);

      expect(order.take(2), [SidebarItemId.calendar, SidebarItemId.home]);
      expect(order.length, SidebarItemId.values.length);
      expect(order.toSet().length, order.length);
    });

    test('encode round-trips through parse', () {
      final order = SidebarItemId.parse(['tags', 'home', 'calendar', 'search', 'map', 'relaxSounds']);

      expect(SidebarItemId.parse(SidebarItemId.encode(order)), order);
    });
  });

  test('every item has its own name, icon and badge colour', () {
    expect(SidebarItemId.values.map((item) => item.name).toSet().length, SidebarItemId.values.length);
    expect(SidebarItemId.values.map((item) => item.weekday).toSet().length, SidebarItemId.values.length);

    for (final item in SidebarItemId.values) {
      expect(item.weekday, inInclusiveRange(1, 7), reason: 'SpSettingIconBadge colours are 1..7');
    }
  });
}
