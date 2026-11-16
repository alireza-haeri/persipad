import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/material.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/mixins/debounched_callback.dart';
import 'package:storypad/core/objects/cloud_service_user.dart';
import 'package:storypad/core/services/auto_sync_trigger_service.dart';
import 'package:storypad/core/services/network_type_service.dart';
import 'package:storypad/core/storages/device_preferences_storage.dart';
import 'package:storypad/core/objects/google_user_object.dart';
import 'package:storypad/core/repositories/backup_repository.dart';
import 'package:storypad/core/services/analytics/analytics_service.dart';
import 'package:storypad/core/services/assets/db_asset_loader_service.dart';
import 'package:storypad/core/services/backups/backup_cloud_service.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/google_desktop_oauth_service.dart';
import 'package:storypad/core/services/backups/google_drive_cloud_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_images_uploader_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_importer_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_latest_checker_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_sync_messenger.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_uploader_service.dart';
import 'package:storypad/core/services/backups/sync_steps/sync_step.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/restore_backup_service.dart';
import 'package:storypad/core/services/internet_checker_service.dart';
import 'package:storypad/core/services/logger/app_logger.dart';
import 'package:storypad/core/storages/backup_import_history_storage.dart';
import 'package:storypad/core/types/backup_connection_status.dart';
import 'package:storypad/core/services/messenger_service.dart';
import 'package:storypad/core/types/backup_result.dart';
import 'package:storypad/providers/backup_sync_state_store.dart';
import 'package:storypad/views/home/home_view.dart';
import 'package:storypad/widgets/sp_app_lock_wrapper.dart';

class BackupProvider extends ChangeNotifier with DebounchedCallback {
  BackupProvider() {
    repository.syncMessages.listen((message) {
      AppLogger.d(
        '$runtimeType: ${message.step} message success: ${message.success} processing: ${message.processing} message: ${message.message}',
      );
      _syncState.onSyncMessage(message);

      // Only past the quick pre-check steps (upload assets/check latest) is a
      // sync "deep" enough to be worth surfacing in the home app bar — see
      // isSyncingDeepStep.
      if (message.step == SyncStep.importChanges || message.step == SyncStep.uploadBackup) {
        _reachedDeepSyncStep = true;
      }
    });

    _syncState.addListener(notifyListeners);

    for (var database in BackupRepository.databases) {
      database.addGlobalListener(_databaseListener);
    }

    _autoSyncTriggerService = AutoSyncTriggerService(
      onTrigger: () => _setupConnection().then((_) async {
        /// Auto sync if applicable.
        /// Wait 1 second before calling to ensure home context is ready.
        await Future.delayed(const Duration(seconds: 1));

        if (HomeView.homeContext?.mounted != true) return;
        autoSync(setupConnection: false, context: HomeView.homeContext!);
      }),
    );

    _autoSyncTriggerService.start();
  }

  Future<void> _databaseListener() async {
    _lastDbUpdatedAtByYear = await repository.getLastDbUpdatedAtByYear();
    notifyListeners();
  }

  static final BackupRepository repoInstance = _createRepoInstance();
  static BackupRepository _createRepoInstance() {
    final messenger = BackupSyncMessenger();

    return BackupRepository(
      restoreService: RestoreBackupService(),
      messenger: messenger,
      step1ImagesUploader: BackupImagesUploaderService(messenger: messenger),
      step2LatestBackupChecker: BackupLatestCheckerService(messenger: messenger),
      step3LatestBackupImporter: BackupImporterService(messenger: messenger),
      step4NewBackupUploader: BackupUploaderService(messenger: messenger),
      internetChecker: InternetCheckerService(),
      googleDriveService: GoogleDriveCloudService(),
      importHistoryStorage: BackupImportHistoryStorage(),
    );
  }

  late final AutoSyncTriggerService _autoSyncTriggerService;
  final NetworkTypeService _networkTypeService = const NetworkTypeService();
  BackupRepository get repository => repoInstance;

  final BackupSyncStateStore _syncState = BackupSyncStateStore();
  ServiceSyncStatus statusFor(BackupServiceType type) => _syncState.statusFor(type);

  GoogleUserObject? get currentGoogleUser => repository.currentGoogleUser;
  bool get isSignedIn => repository.isSignedIn;

  /// Get all authenticated cloud service users for asset downloads
  List<CloudServiceUser> get availableUsers => repository.availableUsers;

  /// Set once a sync run's messages reach import/upload — see the
  /// constructor's `syncMessages` listener. Reset at the start of every run.
  bool _reachedDeepSyncStep = false;

  /// Whether the home app bar should show its "we're syncing" banner — only
  /// once a run is past the quick pre-check steps, so a fast no-op check
  /// doesn't flash the banner for no reason.
  bool get isSyncingDeepStep => _syncing && _reachedDeepSyncStep;

  // Uses "remote not behind local" rather than strict equality: after the
  // yearly/global backup table split, a year's own remote file can carry a
  // filename timestamp inflated by tables that no longer bucket into it
  // (e.g. a tag edit from before the split), which would never again equal
  // that year's locally-recomputed (partitioned-only) timestamp even though
  // nothing is actually pending for it — matches the same "anything to
  // upload" criterion BackupUploaderService._start uses to skip a year.
  bool get allYearSynced =>
      _lastDbUpdatedAtByYear?.entries.every((entry) {
        final local = entry.value;
        final remote = _lastSyncedAtByYear?[entry.key];
        return local != null && remote != null && !local.isAfter(remote);
      }) ==
      true;

  /// Whether the last connectivity check found internet at all — the one
  /// remaining global gate on [recheckAndSync]. Per-service auth/permission
  /// problems no longer block the whole batch; see [statusFor].
  bool _hasInternet = true;

  DateTime? get lastSyncedAt => _lastSyncedAtByYear?.values.whereType<DateTime>().fold<DateTime?>(
    null,
    (latest, current) => latest == null || current.isAfter(latest) ? current : latest,
  );

  DateTime? get lastDbUpdatedAt => _lastDbUpdatedAtByYear?.values.whereType<DateTime>().fold<DateTime?>(
    null,
    (latest, current) => latest == null || current.isAfter(latest) ? current : latest,
  );

  Map<int, DateTime?>? _lastSyncedAtByYear;
  Map<int, DateTime?>? get lastSyncedAtByYear => _lastSyncedAtByYear;

  Map<int, DateTime?>? _lastDbUpdatedAtByYear;
  Map<int, DateTime?>? get lastDbUpdatedAtByYear => _lastDbUpdatedAtByYear;

  /// Devices (by model) seen writing old-format backups in the last sync: an older StoryPad whose new stories this
  /// device can't receive until it's updated.
  Set<String> _olderAppDeviceModels = const {};
  Set<String> get olderAppDeviceModels => _olderAppDeviceModels;

  bool _syncing = false;
  bool get syncing => _syncing;

  /// Media deferred by the Wi-Fi-only setting. [allYearSynced] only reflects the
  /// yearly backup files, so without this the app would report "Synced" while
  /// media is still pending.
  int _pendingMediaCount = 0;
  int get pendingMediaCount => _pendingMediaCount;

  Future<void> refreshPendingMediaCount() async {
    try {
      _pendingMediaCount = await repository.pendingMediaCount();
    } catch (e) {
      AppLogger.d('$runtimeType#refreshPendingMediaCount failed: $e');
    }

    notifyListeners();
  }

  List<BackupCloudService> get services => repository.services;
  List<BackupCloudService> get autoBackupServices =>
      repository.services.where((service) => service.autoBackupEnabled).toList();

  /// Every service with an active account — the set an asset could actually
  /// be downloaded from right now.
  List<BackupCloudService> get signedInServices => repository.services.where((service) => service.isSignedIn).toList();

  Future<void> _setupConnection() async {
    final connectionResult = await repository.checkConnection();
    if (connectionResult.data != null) {
      _hasInternet = connectionResult.data!.hasInternet;
      _syncState.onConnectionChecked(connectionResult.data!.statusByService);
    }

    if (connectionResult.error != null) {
      AppLogger.d('Connection check failed: ${connectionResult.error!.message}');
    }
  }

  Future<void> autoSync({
    bool setupConnection = true,
    required BuildContext context,
  }) async {
    await recheckAndSync(
      setupConnection: setupConnection,
      services: autoBackupServices,
      context: context,
    );
  }

  /// [forceMediaUpload] bypasses the Wi-Fi-only media gate for an explicit
  /// "Sync Media Now" — the deliberate escape hatch, since the setting otherwise
  /// applies to manual "Sync now" as well as auto sync.
  Future<bool> recheckAndSync({
    bool setupConnection = true,
    bool forceMediaUpload = false,
    required List<BackupCloudService> services,
    required BuildContext context,
  }) async {
    if (services.isEmpty) return false;
    if (_syncing) return false;

    _syncing = true;
    _reachedDeepSyncStep = false;
    _syncState.onSyncQueueStarted(services.map((service) => service.serviceType).toList());
    notifyListeners();

    try {
      if (setupConnection) await _setupConnection();
      if (!_hasInternet) return false;

      return await _syncBackupAcrossDevices(
        services: services,
        uploadAssets: forceMediaUpload || await _canUploadMedia(),
      );
    } catch (e) {
      AppLogger.d('$runtimeType#recheckAndSync failed: $e');
      return false;
    } finally {
      _syncing = false;
      _syncState.onSyncFinished();
      await refreshPendingMediaCount();
      notifyListeners();
    }
  }

  Future<void> signIn(
    BuildContext context,
    BackupServiceType serviceType,
  ) async {
    final service = repository.getService(serviceType);
    if (service is GoogleDriveCloudService && !service.isConfigured) {
      if (context.mounted) await _showGoogleDriveSetupHelp(context);
      return;
    }

    final result = await _signInWithFallback(context, serviceType);

    if (result.isSuccess == true) {
      AnalyticsService.instance.logSignInWithGoogle();

      _syncState.onConnectionChecked({serviceType: BackupConnectionStatus.readyToSync});
      _lastSyncedAtByYear = null;
      _lastDbUpdatedAtByYear = null;
    } else if (result.error != null) {
      AppLogger.d('Sign-in failed: ${result.error!.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_signInMessage(result.error!))),
        );
      }

      if (result.error!.type == BackupErrorType.network) {
        // Nothing about the account is wrong — the device cannot reach Google
        // (a DNS failure inside an emulator looks exactly like this). Record it
        // as a connection state so the tile offers "fix connection" instead of
        // puzzling over a credentials error.
        _hasInternet = false;
        _syncState.onConnectionChecked({serviceType: BackupConnectionStatus.noInternet});
      }
    }

    notifyListeners();
  }

  /// Runs the sign-in with the loopback escape hatch installed: if the browser
  /// never reaches the app's local server, the user can paste the address from the
  /// browser instead of being stuck on a page that spins forever (`D-058`, `D-060`).
  Future<BackupResult<bool>> _signInWithFallback(BuildContext context, BackupServiceType serviceType) async {
    if (repository.getService(serviceType) is GoogleDriveCloudService) {
      GoogleDesktopOAuthService.manualRedirectPrompt = (redirectArrived) => _askForRedirectUri(context, redirectArrived);
    }

    try {
      return await SpAppLockWrapper.disableAppLockIfHas(
        context,
        callback: () => repository.signIn(serviceType),
      );
    } finally {
      GoogleDesktopOAuthService.manualRedirectPrompt = null;
    }
  }

  /// The browser tab is stuck on `http://127.0.0.1:<port>/?code=…`: offer to finish
  /// the sign-in from the address bar. Returns null when the user would rather keep
  /// waiting, which leaves the loopback server running.
  Future<String?> _askForRedirectUri(BuildContext context, Future<void> redirectArrived) async {
    if (!context.mounted) return null;

    final controller = TextEditingController();
    try {
      final dialog = showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // The loopback can still win after the dialog opened; close it then.
          redirectArrived.then((_) {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          });

          return AlertDialog(
            title: Text(tr('dialog.google_drive_redirect.title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('dialog.google_drive_redirect.description')),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: tr('dialog.google_drive_redirect.hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('button.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(controller.text),
                child: Text(tr('button.confirm')),
              ),
            ],
          );
        },
      );

      return await dialog;
    } finally {
      controller.dispose();
    }
  }

  /// A sign-in that failed only because the device cannot reach Google gets the
  /// translated "no internet" line: the raw transport text
  /// (`ClientException with SocketException: Failed host lookup … errno = 7`)
  /// tells the user nothing they can act on. Every other failure keeps the
  /// specific message the stack produced.
  String _signInMessage(BackupError error) {
    if (error.type == BackupErrorType.network) return tr('snack_bar.no_internet');
    return error.message;
  }

  /// One-time setup instructions when no OAuth client id is configured.
  Future<void> _showGoogleDriveSetupHelp(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Drive needs one setup step'),
        content: const SingleChildScrollView(
          child: SelectableText(
            'This build has no Google OAuth client id yet. It identifies the app to '
            'Google (it is not an account — every user still signs in with their own '
            'Google account, and backups go to their own Drive).\n\n'
            '1. console.cloud.google.com -> create a project\n'
            '2. APIs & Services -> Library -> enable "Google Drive API"\n'
            '3. Google Auth Platform -> Branding: name + support email, then '
            'Audience: External, and add your own account under Test users\n'
            '4. Data access -> add scopes: drive.appdata, openid, userinfo.email, '
            'userinfo.profile (Google refuses scopes it was never told about)\n'
            '5. Credentials -> Create credentials -> OAuth client ID -> Desktop app\n'
            '6. Put both values next to the repo, outside git:\n\n'
            '   private_keys/dart_defines/community.json\n'
            '   {"GOOGLE_DESKTOP_CLIENT_ID": "...", "GOOGLE_DESKTOP_CLIENT_SECRET": "..."}\n\n'
            'Then rebuild with bin/dev --community-linux or bin/build_apk.\n\n'
            'Note: while the Google project stays in Testing, Google expires the '
            'refresh token after 7 days. Publishing the app (the scopes used here are '
            'non-sensitive, so no Google review is required) stops that.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> requestScope(
    BuildContext context,
    BackupServiceType serviceType,
  ) async {
    final result = await MessengerService.of(context).showLoading<BackupResult<bool>>(
      debugSource: '$runtimeType#requestScope',
      future: () => SpAppLockWrapper.disableAppLockIfHas(
        context,
        callback: () => repository.requestScope(),
      ),
    );

    if (result?.isSuccess == true) {
      AnalyticsService.instance.logRequestGoogleDriveScope();
    } else if (result?.error != null) {
      AppLogger.d('Request scope failed: ${result!.error!.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!.message)),
        );
      }
    }

    notifyListeners();
    if (!context.mounted) return;
    await recheckAndSync(
      services: [repository.getService(serviceType)],
      context: context,
    );
  }

  Future<void> signOut(
    BuildContext context,
    BackupServiceType serviceType,
  ) async {
    final result = await MessengerService.of(context).showLoading<BackupResult<void>>(
      debugSource: '$runtimeType#signOut',
      future: () => repository.signOut(serviceType),
    );

    AnalyticsService.instance.logSignOut();

    _syncState.resetService(serviceType);
    _lastSyncedAtByYear = null;
    _lastDbUpdatedAtByYear = null;

    if (result?.error != null) {
      AppLogger.d('Sign-out had issues: ${result!.error!.message}');
    }

    DbAssetLoaderService.instance.clear();
    notifyListeners();
  }

  Future<bool> _canUploadMedia() async {
    final mediaSync = DevicePreferencesStorage.appInstance.preferences.mediaSync;
    if (mediaSync == .wifiAndCellular) return true;

    return _networkTypeService.isUnmetered();
  }

  Future<bool> _syncBackupAcrossDevices({
    required List<BackupCloudService> services,
    required bool uploadAssets,
  }) async {
    _lastDbUpdatedAtByYear = await repository.getLastDbUpdatedAtByYear();
    notifyListeners();

    var attemptedSync = false;
    var allSyncsSucceeded = true;

    var didImportAny = false;
    final olderAppDeviceModels = <String>{};

    for (final service in services) {
      if (!service.isSignedIn) {
        AppLogger.d('Skipping service ${service.serviceType.displayName}: not signed in');
        continue;
      }

      final serviceId = service.serviceType.id;
      attemptedSync = true;

      _syncState.onServiceSyncStarted(service.serviceType);

      kErrorReportingService.log('$runtimeType#_syncBackupAcrossDevices[$serviceId]: started');

      final result = await repository.sync(service, uploadAssets: uploadAssets, notifyImportCallbacks: false);

      if (!result.isSuccess) {
        allSyncsSucceeded = false;
        kErrorReportingService.log(
          '$runtimeType#_syncBackupAcrossDevices[$serviceId]: failed — ${result.error?.message}',
        );
        if (result.error?.type == BackupErrorType.authentication) {
          final connectionResult = await repository.checkConnection();
          if (connectionResult.data != null) {
            _hasInternet = connectionResult.data!.hasInternet;
            _syncState.onConnectionChecked(connectionResult.data!.statusByService);
          }
        } else {
          final failureStatus = result.error?.type == BackupErrorType.network
              ? BackupConnectionStatus.noInternet
              : BackupConnectionStatus.unknownError;
          _syncState.onConnectionChecked({service.serviceType: failureStatus});
        }

        _syncState.onServiceSyncFinished(service.serviceType);
        continue;
      }

      kErrorReportingService.log('$runtimeType#_syncBackupAcrossDevices[$serviceId]: succeeded');

      if (result.data?.didImport == true) didImportAny = true;
      olderAppDeviceModels.addAll(result.data?.olderAppDeviceModels ?? const {});

      _lastDbUpdatedAtByYear = await repository.getLastDbUpdatedAtByYear();

      final uploadedYearlyFilesPerService = result.data?.uploadedYearlyFiles;
      final lastSyncedAtByYearPerService = result.data?.lastSyncedAtByYear ?? {};

      if (uploadedYearlyFilesPerService != null) {
        for (var entry in uploadedYearlyFilesPerService.entries) {
          lastSyncedAtByYearPerService[entry.key] = entry.value.lastUpdatedAt;
        }
      }

      final serviceLastSyncedAt = lastSyncedAtByYearPerService.values.whereType<DateTime>().fold<DateTime?>(
        null,
        (latest, current) => latest == null || current.isAfter(latest) ? current : latest,
      );
      _syncState.onServiceSyncFinished(service.serviceType, lastSyncedAt: serviceLastSyncedAt);

      for (var entry in lastSyncedAtByYearPerService.entries) {
        final year = entry.key;
        final syncedAt = entry.value;
        final current = _lastSyncedAtByYear?[year];

        if (syncedAt != null && (current == null || syncedAt.isAfter(current))) {
          _lastSyncedAtByYear ??= {};
          _lastSyncedAtByYear?[year] = syncedAt;
        }
      }
    }

    if (didImportAny) await repository.restoreService.notify();
    if (attemptedSync && allSyncsSucceeded) _olderAppDeviceModels = olderAppDeviceModels;

    notifyListeners();
    return attemptedSync && allSyncsSucceeded;
  }

  @override
  void dispose() {
    _autoSyncTriggerService.dispose();
    _syncState.dispose();
    repository.dispose();
    super.dispose();
  }
}
