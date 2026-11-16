import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/yearly_backup_files_object.dart';
import 'package:storypad/core/objects/backup_exceptions/backup_exception.dart';
import 'package:storypad/core/objects/cloud_file_object.dart';
import 'package:storypad/core/objects/cloud_service_user.dart';
import 'package:storypad/core/objects/cloud_storage_quota_object.dart';
import 'package:storypad/core/repositories/backup_repository.dart';
import 'package:storypad/core/services/backups/backup_cloud_service.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_images_uploader_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_importer_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_latest_checker_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_sync_messenger.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_uploader_service.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/restore_backup_service.dart';
import 'package:storypad/core/services/internet_checker_service.dart';
import 'package:storypad/core/storages/backup_import_history_storage.dart';
import 'package:storypad/core/types/backup_connection_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BackupRepository buildRepository({
    required BackupCloudService googleDriveService,
    bool hasInternet = true,
  }) {
    final messenger = BackupSyncMessenger();
    return BackupRepository(
      restoreService: RestoreBackupService(),
      messenger: messenger,
      step1ImagesUploader: BackupImagesUploaderService(messenger: messenger),
      step2LatestBackupChecker: BackupLatestCheckerService(messenger: messenger),
      step3LatestBackupImporter: BackupImporterService(messenger: messenger),
      step4NewBackupUploader: BackupUploaderService(messenger: messenger),
      internetChecker: _FakeInternetChecker(hasInternet),
      googleDriveService: googleDriveService,
      importHistoryStorage: BackupImportHistoryStorage(),
    );
  }

  group('BackupRepository.checkConnection', () {
    test('healthy Google Drive reports readyToSync', () async {
      final repository = buildRepository(
        googleDriveService: _FakeCloudService(serviceType: BackupServiceType.google_drive),
      );

      final result = await repository.checkConnection();

      expect(result.isSuccess, isTrue);
      expect(result.data!.hasInternet, isTrue);
      expect(result.data!.statusByService[BackupServiceType.google_drive], BackupConnectionStatus.readyToSync);
    });

    test('revoked token reports needServicePermission', () async {
      final repository = buildRepository(
        googleDriveService: _FakeCloudService(
          serviceType: BackupServiceType.google_drive,
          shouldThrow: true,
        ),
      );

      final result = await repository.checkConnection();

      expect(result.isSuccess, isTrue);
      expect(
        result.data!.statusByService[BackupServiceType.google_drive],
        BackupConnectionStatus.needServicePermission,
      );
    });

    test('no internet marks signed-in service noInternet without checking it', () async {
      final repository = buildRepository(
        googleDriveService: _FakeCloudService(serviceType: BackupServiceType.google_drive),
        hasInternet: false,
      );

      final result = await repository.checkConnection();

      expect(result.data!.hasInternet, isFalse);
      expect(result.data!.statusByService[BackupServiceType.google_drive], BackupConnectionStatus.noInternet);
    });

    test('not signed in fails fast', () async {
      final repository = buildRepository(
        googleDriveService: _FakeCloudService(serviceType: BackupServiceType.google_drive, signedIn: false),
      );

      final result = await repository.checkConnection();

      expect(result.isSuccess, isFalse);
    });

    test('transient network error during reauth reports noInternet', () async {
      final repository = buildRepository(
        googleDriveService: _FakeCloudService(
          serviceType: BackupServiceType.google_drive,
          reauthenticateError: const NetworkException(
            'Could not reach Google',
            serviceType: BackupServiceType.google_drive,
          ),
        ),
      );

      final result = await repository.checkConnection();

      expect(result.isSuccess, isTrue);
      expect(result.data!.statusByService[BackupServiceType.google_drive], BackupConnectionStatus.noInternet);
    });
  });
}

class _FakeInternetChecker extends InternetCheckerService {
  _FakeInternetChecker(this._result);
  final bool _result;

  @override
  Future<bool> check() async => _result;
}

class _FakeCloudService implements BackupCloudService {
  _FakeCloudService({
    required this.serviceType,
    this.shouldThrow = false,
    this.signedIn = true,
    this.reauthenticateError,
  });

  @override
  final BackupServiceType serviceType;

  final bool shouldThrow;
  final bool signedIn;
  final Exception? reauthenticateError;

  @override
  CloudServiceUser? get currentUser => signedIn ? _FakeUser(serviceType) : null;

  @override
  bool get isSignedIn => signedIn;

  @override
  bool get autoBackupEnabled => true;

  @override
  bool get hasCompression => true;

  @override
  Future<bool> reauthenticateIfNeeded() async {
    if (reauthenticateError != null) throw reauthenticateError!;
    if (shouldThrow) {
      throw AuthException('Broken', AuthExceptionType.tokenRevoked, serviceType: serviceType);
    }
    return true;
  }

  @override
  Future<bool> canAccessRequestedScopes() async => true;

  @override
  Future<CloudFileObject?> uploadFile(String fileName, io.File file, {String? folderName}) async => null;

  @override
  Future<CloudStorageQuotaObject?> fetchStorageQuota() async => null;

  @override
  Future<List<CloudFileObject>> listFilesInFolder(String folderName) async => [];

  @override
  Future<YearlyBackupFilesObject> fetchYearlyBackups() async => const YearlyBackupFilesObject();

  @override
  Future<(String, int)?> getFileContent(CloudFileObject file) async => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements CloudServiceUser {
  _FakeUser(this.serviceType);

  @override
  final BackupServiceType serviceType;

  @override
  String get identifier => 'tester@example.com';

  @override
  String get destinationKey => identifier;

  @override
  List<({String label, String value})> get configuration => const [];

  @override
  String? get displayName => 'Tester';

  @override
  String? get photoUrl => null;

  @override
  bool? get autoBackupEnabled => true;

  @override
  String? get globalId => 'global-id';
}
