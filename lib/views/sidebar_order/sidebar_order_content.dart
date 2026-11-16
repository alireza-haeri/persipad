part of 'sidebar_order_view.dart';

class _SidebarOrderContent extends StatelessWidget {
  const _SidebarOrderContent(this.viewModel);

  final SidebarOrderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('page.sidebar_order.title')),
        actions: [
          IconButton(
            tooltip: tr('button.reset'),
            icon: const Icon(SpIcons.refresh),
            onPressed: viewModel.reset,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
            child: Text(
              tr('general.sidebar_order_hint'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24.0),
              itemCount: viewModel.order.length,
              onReorder: viewModel.reorder,
              itemBuilder: (context, index) {
                final SidebarItemId item = viewModel.order[index];
                return _SidebarOrderTile(
                  // ReorderableListView requires a key on every row it is given.
                  key: ValueKey(item.name),
                  item: item,
                  available: viewModel.isAvailable(item),
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
