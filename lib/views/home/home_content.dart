part of 'home_view.dart';

class _HomeContent extends StatelessWidget {
  const _HomeContent(this.viewModel);

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SpStoryListMultiEditWrapper(
      builder: (BuildContext context) {
        return buildScaffold(context);
      },
    );
  }

  Widget buildScaffold(BuildContext context) {
    return DefaultTabController(
      length: viewModel.months.length,
      child: _HomeScaffold(
        viewModel: viewModel,
        endDrawer: buildEndDrawer(context),
        appBar: _HomeAppBar(viewModel: viewModel),
        body: buildBody(context),
        bottomNavigationBar: buildBottomNavigationBar(context),
        floatingActionButton: buildFloatingButtons(context),
      ),
    );
  }

  Widget buildEndDrawer(BuildContext context) {
    bool bigScreen = WindowedDetectorService.isBigWindow(context);

    return Drawer(
      width: bigScreen ? 400 : null,
      child: bigScreen ? const SpNestedNavigation(initialScreen: HomeEndDrawer()) : const HomeEndDrawer(),
    );
  }

  Widget buildFloatingButtons(BuildContext context) {
    return SpStoryListMultiEditWrapper.listen(
      context: context,
      builder: (context, state) {
        return Visibility(
          visible: !state.editing,
          child: _HomeFloatingButtons(viewModel: viewModel),
        );
      },
    );
  }

  Widget buildBottomNavigationBar(BuildContext context) {
    return SpStoryListMultiEditWrapper.listen(
      context: context,
      builder: (context, state) {
        if (!state.editing) return const SizedBox.shrink();

        List<StoryDbModel> stories = [
          ...viewModel.stories?.items.where((story) {
                return state.selectedStories.contains(story.id);
              }) ??
              [],
          ...viewModel.pinnedStories?.items.where((story) {
                return state.selectedStories.contains(story.id);
              }) ??
              [],
        ];

        bool allPinned = stories.every((story) => story.pinned == true);

        return SpMultiEditBottomNavBar(
          editing: true,
          onCancel: () => state.turnOffEditing(),
          buttons: [
            _PinStoryIconButton(state: state, allPinned: allPinned, stories: stories, viewModel: viewModel),
            IconButton.outlined(
              tooltip: "${tr("button.archive")} (${state.selectedStories.length})",
              icon: const Icon(SpIcons.archive),
              onPressed: stories.isEmpty ? null : () => state.archiveAll(context),
            ),
            IconButton.outlined(
              color: ColorScheme.of(context).error,
              tooltip: "${tr("button.move_to_bin")} (${state.selectedStories.length})",
              icon: const Icon(SpIcons.delete),
              onPressed: stories.isEmpty ? null : () => state.moveToBinAll(context),
            ),
          ],
        );
      },
    );
  }

  Widget buildBody(BuildContext listContext) {
    if (viewModel.stories == null) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    final items = viewModel.items;
    if (items.isEmpty) {
      return SliverFillRemaining(
        child: _HomeEmpty(viewModel: viewModel),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.only(
        top: 0.0,
        left: MediaQuery.of(listContext).padding.left,
        right: MediaQuery.of(listContext).padding.right,
        bottom: kToolbarHeight + 200 + MediaQuery.of(listContext).padding.bottom,
      ),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => buildItem(context, listContext, items[i]),
      ),
    );
  }

  Widget buildItem(BuildContext context, BuildContext listContext, HomeItem item) {
    return switch (item) {
      HomeThrowbackItem() => SpThrowbackTile(throwbackDates: item.throwbackDates, listHasStories: item.listHasStories),
      HomeMonthHeaderItem() => buildMonthHeader(context, item),
      HomeMonthRecapItem() => buildMonthRecap(context, item),
      HomeLoadMoreItem() => _HomeLoadMoreTile(key: item.key, viewModel: viewModel),
      HomeStoryItem(:final story, :final showMonogram, :final showFullTimelineDivider) => buildStoryTile(
        context,
        listContext,
        item.key,
        story,
        showMonogram,
        showFullTimelineDivider,
      ),
      HomePinnedStoryItem(:final story, :final showMonogram, :final showFullTimelineDivider) => buildStoryTile(
        context,
        listContext,
        item.key,
        story,
        showMonogram,
        showFullTimelineDivider,
      ),
    };
  }

  Widget buildMonthHeader(BuildContext context, HomeMonthHeaderItem item) {
    return Column(
      key: item.key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // when this is the first header of its run and there is no throwback,
        // add extra spacing at top; else no padding to make UI look nicer
        // relative to the throwback tile / previous section above it.
        if (item.isFirstOfRun && !viewModel.hasThrowback) const SizedBox(height: 12.0),

        Stack(
          children: [
            // connector divider from the previous section's last story to
            // this header, when this header isn't the first of its run.
            if (!item.isFirstOfRun) buildTimelineDivider(context, true),
            StoryMonthHeader(isFirstOfRun: item.isFirstOfRun, story: item.story, showYear: false),
          ],
        ),
      ],
    );
  }

  Widget buildMonthRecap(BuildContext context, HomeMonthRecapItem item) {
    return Stack(
      key: item.key,
      children: [
        buildTimelineDivider(context, item.showFullTimelineDivider),
        StoryMonthRecapTile(story: item.story, stats: item.stats),
      ],
    );
  }

  Widget buildStoryTile(
    BuildContext context,
    BuildContext listContext,
    GlobalKey key,
    StoryDbModel story,
    bool showMonogram,
    bool showFullTimelineDivider,
  ) {
    return SpStoryListenerBuilder(
      key: key,
      story: story,
      onChanged: (StoryDbModel updatedStory) => viewModel.onAStoryReloaded(updatedStory),
      onDeleted: () => viewModel.onAStoryDeleted(story),
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: viewModel.scrollInfo.scrollingToStoryIdNotifier,
                builder: (context, storyId, child) {
                  return AnimatedContainer(
                    duration: Durations.long4,
                    color: storyId == story.id ? ColorScheme.of(context).readOnly.surface5 : Colors.transparent,
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
            Stack(
              children: [
                buildTimelineDivider(context, showFullTimelineDivider),
                Consumer<DevicePreferencesProvider>(
                  builder: (context, provider, child) {
                    return SpStoryTile(
                      story: story,
                      preferences: provider.preferences.storyTilePreferences,
                      showMonogram: showMonogram,
                      viewOnly: false,
                      onTap: () => viewModel.goToViewPage(context, story),
                      listContext: listContext,
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// The vertical rail that threads the story tiles together.
  ///
  /// It runs through the monograms, and the tile row puts those at its *start* —
  /// left in LTR, right in RTL. Pinning it to `left` in both directions left the
  /// line on the wrong side of every Persian list (and let it cross the dates
  /// instead of connecting them).
  Widget buildTimelineDivider(BuildContext context, bool showFullTimelineDivider) {
    final bool isRtl = AppTheme.rtl(context);

    return Positioned(
      left: isRtl ? null : 32.0,
      right: isRtl ? 32.0 : null,
      // 1. full line from header to bottom while stories follow,
      // 2. else only from header to dot/monogram when there is no story.
      top: showFullTimelineDivider ? 0.0 : null,
      bottom: showFullTimelineDivider ? 0.0 : null,
      height: showFullTimelineDivider ? null : 16.0,
      child: const VerticalDivider(width: 1),
    );
  }
}

/// Trailing loading tile for [HomeLoadMoreItem]. `SliverList.builder` only
/// builds items near the viewport, so this widget being built (mounted) is
/// itself the "scrolled near the loaded edge" signal — [initState] uses it to
/// kick [HomeViewModel.loadNextPage], which is cheap to call redundantly here
/// since [HomeViewModel.reload] already eagerly works through remaining
/// pages in the background regardless of scroll — this is a catch-up path
/// for when that background work hasn't reached this point yet.
class _HomeLoadMoreTile extends StatefulWidget {
  const _HomeLoadMoreTile({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<_HomeLoadMoreTile> createState() => _HomeLoadMoreTileState();
}

class _HomeLoadMoreTileState extends State<_HomeLoadMoreTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.viewModel.loadNextPage());
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2.0),
        ),
      ),
    );
  }
}
