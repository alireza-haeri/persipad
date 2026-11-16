import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/services/app_store_opener_service.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/sidebar_item_id.dart';
import 'package:storypad/providers/root_provider.dart';
import 'package:storypad/views/archives/archives_view.dart';
import 'package:storypad/views/calendar/calendar_view.dart';
import 'package:storypad/views/community/community_view.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/views/home/home_view_model.dart';
import 'package:storypad/views/home/local_widgets/end_drawer/survey_banner.dart';
import 'package:storypad/views/search/search_view.dart';
import 'package:storypad/widgets/bottom_sheets/sp_share_app_bottom_sheet.dart';
import 'package:storypad/widgets/side_items/local_widgets/backup_tile.dart';
import 'package:storypad/widgets/side_items/local_widgets/home_year_switcher_header.dart';
import 'package:storypad/views/library/library_view.dart';
import 'package:storypad/views/settings/settings_view.dart';
import 'package:storypad/views/tags/tags_view.dart';
import 'package:storypad/widgets/base_view/base_route.dart';
import 'package:storypad/widgets/sp_fade_in.dart';
import 'package:storypad/widgets/sp_icons.dart';

part 'local_widgets/tag_header.dart';
part 'side_item.dart';

const double _leadingPaddedSize = 12.0;

class SideItems {
  /// Whether [item] can appear in the sidebar.
  static bool isAvailable(SidebarItemId item) {
    switch (item) {
      case SidebarItemId.home:
      case SidebarItemId.search:
      case SidebarItemId.calendar:
      case SidebarItemId.tags:
        return true;
    }
  }

  /// The sidebar's items, in [order].
  static List<IconButtonSideItem> getSideMenuItems({
    required List<SidebarItemId> order,
  }) {
    final Map<SidebarItemId, IconButtonSideItem> items = {
      SidebarItemId.home: IconButtonSideItem(
        route: const HomeRoute(),
        title: SidebarItemId.home.displayName,
        iconData: SidebarItemId.home.icon,
        selectedIconData: SidebarItemId.home.icon,
        onTap: (context, route) => context.read<RootProvider>().navigate(route),
      ),
      SidebarItemId.search: IconButtonSideItem(
        route: SearchRoute(),
        title: SidebarItemId.search.displayName,
        iconData: SidebarItemId.search.icon,
        selectedIconData: SidebarItemId.search.icon,
        onTap: (context, route) => context.read<RootProvider>().navigate(route),
      ),
      SidebarItemId.calendar: IconButtonSideItem(
        route: CalendarRoute(
          initialMonth: CalendarDisplay.monthOf(DateTime.now()),
          initialYear: CalendarDisplay.yearOf(DateTime.now()),
          initialSegment: .mood,
        ),
        title: SidebarItemId.calendar.displayName,
        iconData: SidebarItemId.calendar.icon,
        selectedIconData: SidebarItemId.calendar.icon,
        onTap: (context, route) => context.read<RootProvider>().navigate(route),
      ),
      SidebarItemId.tags: IconButtonSideItem(
        route: TagsRoute(),
        title: SidebarItemId.tags.displayName,
        iconData: SidebarItemId.tags.icon,
        selectedIconData: SidebarItemId.tags.icon,
        onTap: (context, route) => context.read<RootProvider>().navigate(route),
      ),
    };

    return [
      for (final SidebarItemId id in order)
        if (isAvailable(id)) items[id]!,
    ];
  }

  static List<BaseSideItem> getEndDrawerItems(BuildContext context, HomeViewModel homeViewModel) {
    return [
      CustomSideItem.custom(builder: (context) => SurveyBanner(homeViewModel: homeViewModel)),
      CustomSideItem.custom(builder: (context) => HomeYearSwitcherHeader(homeViewModel: homeViewModel)),
      CustomSideItem.divider(),
      ListTileSideItem(
        title: tr('page.tags.title'),
        subtitle: null,
        icon: const Icon(SpIcons.tag),
        onTap: (context) => TagsRoute().push(context),
      ),
      ListTileSideItem(
        title: tr('page.library.title'),
        subtitle: null,
        icon: const Icon(SpIcons.photo),
        onTap: (context) => LibraryRoute().push(context),
      ),
      ListTileSideItem(
        title: tr('general.path_type.archives'),
        subtitle: null,
        icon: const Icon(SpIcons.archive),
        onTap: (context) => ArchivesRoute(pathType: .archives).push(context),
      ),
      ListTileSideItem(
        title: tr('general.path_type.bins'),
        subtitle: null,
        icon: const Icon(SpIcons.delete),
        onTap: (context) => ArchivesRoute(pathType: .bins).push(context),
      ),
      CustomSideItem.divider(),
      CustomSideItem.custom(
        builder: (context) {
          return BackupTile(onNavigate: (BaseRoute route) => route.push(context));
        },
      ),
      CustomSideItem.divider(),
      ListTileSideItem(
        title: tr('page.settings.title'),
        subtitle: null,
        icon: const Icon(SpIcons.setting),
        onTap: (context) => SettingsRoute().push(context),
      ),
      CustomSideItem.divider(),
      ListTileSideItem(
        title: tr('page.community.title'),
        subtitle: null,
        icon: const Icon(SpIcons.forum),
        onTap: (context) => CommunityRoute().push(context),
      ),
      ListTileSideItem(
        title: tr('list_tile.rate.title'),
        subtitle: null,
        icon: const Icon(SpIcons.star),
        onTap: (context) => AppStoreOpenerService.call(),
      ),
      ListTileSideItem(
        title: tr('list_tile.share_app.title'),
        subtitle: tr('list_tile.share_app.subtitle'),
        icon: const Icon(SpIcons.share),
        onTap: (context) => SpShareAppBottomSheet().show(context: context),
      ),
    ];
  }

  static List<TimelineSideBarItem> getTimelineSideBarItems({
    required HomeViewModel homeViewModel,
  }) {
    return [
      TimelineSideBarItem(
        icon: SpIcons.search,
        tooltip: tr('page.search.title'),
        wrap: (context, child) => SpFadeIn.bound(child: child),
        onTap: (context) => SearchRoute().push(context),
      ),
      TimelineSideBarItem(
        icon: SpIcons.calendar,
        tooltip: tr('page.calendar.title'),
        onTap: (context) {
          CalendarRoute(
            initialMonth: null,
            initialYear: homeViewModel.year,
            initialSegment: .mood,
          ).push(context);
        },
      ),
    ];
  }
}
