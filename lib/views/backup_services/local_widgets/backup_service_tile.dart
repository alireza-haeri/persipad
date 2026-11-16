import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/extensions/color_scheme_extension.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/backups/backup_cloud_service.dart';
import 'package:storypad/core/services/platform_capabilities.dart';
import 'package:storypad/core/types/backup_connection_status.dart';
import 'package:storypad/providers/backup_provider.dart';
import 'package:storypad/providers/backup_sync_state_store.dart';
import 'package:storypad/views/backup_services/show/show_backup_service_view.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// Generic backup service tile that displays a cloud service status.
class BackupServiceTile extends StatelessWidget {
  final BackupCloudService service;

  const BackupServiceTile({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BackupProvider>(context);
    final status = provider.statusFor(service.serviceType);
    final metadata = service.serviceType;

    final unavailable = !PlatformCapabilities.cloudSyncOnThisDevice(service.serviceType);
    if (unavailable) {
      return ListTile(
        enabled: false,
        leading: Icon(metadata.icon),
        title: Text(metadata.displayName),
        subtitle: Text(tr('list_tile.backup.unavailable_subtitle')),
        trailing: const Icon(SpIcons.cloudOff),
      );
    }

    Widget leading = Icon(metadata.icon);
    Widget? trailing;
    Widget title = Text.rich(
      TextSpan(
        text: '${metadata.displayName} ',
        style: TextTheme.of(context).bodyLarge,
        children: [
          if (service.currentUser?.photoUrl != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(
                  service.currentUser!.photoUrl!,
                ),
                onBackgroundImageError: (_, _) {},
                radius: 8.0,
              ),
            ),
        ],
      ),
    );

    Widget subtitle = const Text("...");
    VoidCallback? onPressed;

    if (!service.isSignedIn) {
      trailing = const Icon(SpIcons.cloudOff);
      subtitle = Text(
        status.connectionStatus == BackupConnectionStatus.noInternet
            ? tr('list_tile.backup.no_internet_subtitle')
            : tr('list_tile.backup.unsignin_subtitle'),
      );
      onPressed = () => provider.signIn(context, service.serviceType);
    } else {
      trailing = Icon(
        SpIcons.next(context),
        color: ColorScheme.of(context).bootstrap.success.color,
      );

      subtitle = Text(service.currentUser?.identifier ?? '...');
      onPressed = () => ShowBackupServiceRoute(service: service).push(context);

      switch (status.connectionStatus) {
        case BackupConnectionStatus.unknownError:
          subtitle = Text(tr('list_tile.backup.unknown_error'));
          break;
        case BackupConnectionStatus.noInternet:
          subtitle = Text(tr('list_tile.backup.no_internet_subtitle'));
          break;
        case BackupConnectionStatus.needServicePermission:
          subtitle = Text(tr('list_tile.backup.no_permission_subtitle'));
          break;
        case BackupConnectionStatus.readyToSync:
          subtitle = Text(tr('list_tile.backup.some_data_has_not_sync_subtitle'));
          break;
        case null:
          break;
      }

      if (status.connectionStatus == BackupConnectionStatus.readyToSync && status.lastSyncedAt != null) {
        subtitle = Text(
          DateFormatHelper.yMEd_jmNullable(
                status.lastSyncedAt,
                context.locale,
              ) ??
              '...',
        );
      }
    }

    if (service.isSignedIn && status.activity == SyncActivity.active) {
      trailing = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator.adaptive(),
      );
      subtitle = Text(tr("general.syncing"));
      onPressed = () => ShowBackupServiceRoute(service: service).push(context);

      if (status.currentStep != null) {
        subtitle = Text("${tr("general.syncing")} ${status.currentStep!.stepNumber}/4");
      }
    } else if (service.isSignedIn && status.activity == SyncActivity.queued) {
      trailing = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator.adaptive(),
      );
      subtitle = Text(tr("list_tile.backup.waiting_to_sync_subtitle"));
      onPressed = () => ShowBackupServiceRoute(service: service).push(context);
    }

    return ListTile(
      onTap: onPressed,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
