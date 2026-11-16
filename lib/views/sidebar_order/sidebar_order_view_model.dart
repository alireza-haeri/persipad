import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/widgets/side_items/side_items.dart';
import 'sidebar_order_view.dart';

class SidebarOrderViewModel extends ChangeNotifier with DisposeAwareMixin {
  final SidebarOrderRoute params;

  final DevicePreferencesProvider devicePreferencesProvider;

  SidebarOrderViewModel({
    required this.params,
    required BuildContext context,
  }) : devicePreferencesProvider = context.read<DevicePreferencesProvider>() {
    _order = devicePreferencesProvider.sidebarOrder;
  }

  /// The working copy. Every change is written straight through: there is no
  /// "save" button, because a reorder is already the whole intent and an unsaved
  /// one that is lost on back would be worse than no screen at all.
  late List<SidebarItemId> _order;
  List<SidebarItemId> get order => _order;

  /// Same rule the sidebar itself uses, imported rather than re-derived — a row
  /// that claims to be usable but is hidden in the sidebar (or the reverse) is the
  /// kind of inconsistency this screen exists to avoid.
  bool isAvailable(SidebarItemId item) => SideItems.isAvailable(
    item,
    enableMap: devicePreferencesProvider.enableMap,
    enableRelaxSounds: devicePreferencesProvider.enableRelaxSounds,
  );

  void reorder(int oldIndex, int newIndex) {
    // ReorderableListView reports the *pre-removal* index for the drop slot.
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final List<SidebarItemId> next = [..._order];
    next.insert(newIndex, next.removeAt(oldIndex));

    _order = next;
    devicePreferencesProvider.setSidebarOrder(next);
    notifyListeners();
  }

  void reset() {
    _order = SidebarItemId.defaults;
    devicePreferencesProvider.setSidebarOrder(SidebarItemId.defaults);
    notifyListeners();
  }
}
