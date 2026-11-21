part of '../home_view.dart';

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.endDrawer,
    required this.viewModel,
    required this.appBar,
    required this.body,
    required this.floatingActionButton,
    required this.bottomNavigationBar,
  });

  final HomeViewModel viewModel;
  final Widget? endDrawer;
  final Widget appBar;
  final Widget body;
  final Widget floatingActionButton;
  final Widget bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: viewModel.scrollInfo.appBar(context).getScaffoldBackgroundColor(context),
      resizeToAvoidBottomInset: false,
      drawerEnableOpenDragGesture: false,
      endDrawerEnableOpenDragGesture: false,
      // For end drawer, we don't use modified padding by root content, we want original screen padding instead
      // because end drawer is on top of content. Plus, the padding on the far side is not needed for end drawer —
      // "far" being the edge the drawer does not cover, which mirrors in RTL: removing `left` there stripped the
      // safe-area inset from under the drawer itself, so its rows ran off the left edge in Persian.
      endDrawer: endDrawer != null ? _removeFarSidePadding(context, endDrawer!) : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButtonLocation: SpFabLocation.endFloat(context),
      extendBody: true,
      onEndDrawerChanged: (isOpened) {
        if (isOpened) {
          context.read<RootProvider>().setTemporaryHidden(true);
        } else {
          context.read<RootProvider>().setTemporaryHidden(false);
        }
      },
      body: Stack(
        children: [
          RefreshIndicator.adaptive(
            edgeOffset: viewModel.scrollInfo.appBar(context).getExpandedHeight() + MediaQuery.of(context).padding.top,
            onRefresh: () => viewModel.refresh(context),
            child: SpScrollConfiguration(
              child: CustomScrollView(
                controller: viewModel.scrollInfo.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  appBar,
                  body,
                ],
              ),
            ),
          ),
          buildTimelineSideBar(context),
        ],
      ),
    );
  }

  /// Drops the screen inset on the edge the end drawer does not sit on, so a
  /// page's own margins don't squeeze the drawer while its own safe area stays.
  Widget _removeFarSidePadding(BuildContext context, Widget drawer) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return MediaQuery.removePadding(
      context: RootView.rootContext ?? context,
      removeLeft: !isRtl,
      removeRight: isRtl,
      child: drawer,
    );
  }

  Widget buildTimelineSideBar(BuildContext viewContext) {
    bool bigScreen = WindowedDetectorService.isBigWindow(viewContext);

    return Positioned(
      bottom: 0,
      child: SpStoryListMultiEditWrapper.listen(
        context: viewContext,
        builder: (context, state) {
          return Visibility(
            visible: viewModel.stories != null && !state.editing && !bigScreen,
            child: _HomeTimelineSideBar(
              viewModel: viewModel,
              // when bottom navigation is visible, we should use context for screen padding.
              // else if bottom nav is not visible, padding from context is 0, so we use view context for padding instead.
              screenPadding: MediaQuery.of(context).padding.bottom == 0
                  ? MediaQuery.of(viewContext).padding
                  : MediaQuery.of(context).padding,
              backgroundColor: viewModel.scrollInfo.appBar(context).getScaffoldBackgroundColor(context),
            ),
          );
        },
      ),
    );
  }
}
