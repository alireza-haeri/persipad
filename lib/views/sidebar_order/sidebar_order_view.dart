import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';
import 'package:storypad/widgets/base_view/base_route.dart';
import 'package:storypad/widgets/sp_icons.dart';

import 'sidebar_order_view_model.dart';

part 'sidebar_order_content.dart';

/// Lets the user decide where each sidebar item sits.
///
/// The sidebar is a fixed list of routes, so "I want the calendar above the map"
/// used to be impossible without editing code. The order is per device and stored
/// as item names (`SidebarItemId.parse` repairs it on read), which is why nothing
/// here has to migrate when an item is added or removed later.
class SidebarOrderRoute extends BaseRoute {
  const SidebarOrderRoute();

  @override
  Widget buildPage(BuildContext context) => SidebarOrderView(params: this);
}

class SidebarOrderView extends StatelessWidget {
  const SidebarOrderView({
    super.key,
    required this.params,
  });

  final SidebarOrderRoute params;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SidebarOrderViewModel>(
      create: (context) => SidebarOrderViewModel(params: params, context: context),
      builder: (context, child) => _SidebarOrderContent(Provider.of(context)),
    );
  }
}

/// The row's leading badge colour and icon come from the id, so the list and the
/// sidebar cannot disagree about what an item looks like.
class _SidebarOrderTile extends StatelessWidget {
  const _SidebarOrderTile({
    super.key,
    required this.item,
    required this.available,
    required this.index,
  });

  final SidebarItemId item;

  /// False for an item that is off right now (the map add-on, relax sounds). It
  /// keeps its place in the list — otherwise turning an add-on off would silently
  /// reset where the user had put it.
  final bool available;

  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      key: ValueKey(item.name),
      leading: Icon(item.icon, color: available ? null : theme.disabledColor),
      title: Text(
        item.displayName,
        style: available ? null : TextStyle(color: theme.disabledColor),
      ),
      subtitle: available ? null : Text(tr('general.disabled')),
      trailing: ReorderableDragStartListener(
        index: index,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(SpIcons.reorder, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
