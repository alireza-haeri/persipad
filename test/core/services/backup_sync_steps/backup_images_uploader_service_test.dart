import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/yearly_backup_files_object.dart';
import 'package:storypad/core/databases/models/asset_db_model.dart';
import 'package:storypad/core/objects/backup_exceptions/backup_exception.dart';
import 'package:storypad/core/objects/cloud_file_object.dart';
import 'package:storypad/core/objects/cloud_service_user.dart';
import 'package:storypad/core/objects/cloud_storage_quota_object.dart';
import 'package:storypad/core/services/backups/backup_cloud_service.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_images_uploader_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_sync_message.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_sync_messenger.dart';
import 'package:storypad/core/types/asset_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupSyncMessenger messenger;
  late BackupImagesUploaderService service;
  late _FakeCloudService cloudService;

  setUp(() {
    messenger = BackupSyncMessenger();
    service = BackupImagesUploaderService(messenger: messenger);
    cloudService = _FakeCloudService(currentUser: _FakeUser());
  });

  tearDown(() => messenger.dispose());

  group('BackupImagesUploaderService - uploadAssets gate', () {
    test('reports success when uploads are deferred', () async {
      final result = await service.start(cloudService, uploadAssets: false);

      expect(result, isTrue);
    });

    test('uploads nothing when deferred', () async {
      await service.start(cloudService, uploadAssets: false);

      expect(cloudService.uploadedFileNames, isEmpty);
    });

    test('still succeeds when the pending count cannot be read', () async {
      final messages = <BackupSyncMessage>[];
      messenger.messages.listen(messages.add);

      final result = await service.start(cloudService, uploadAssets: false);
      await Future.delayed(Duration.zero);

      expect(result, isTrue);
      expect(messages.last.success, isTrue);
      expect(messages.last.processing, isFalse);
    });

    test('throws when the service is not signed in, regardless of the gate', () async {
      final signedOut = _FakeCloudService(currentUser: null);

      expect(
        () => service.start(signedOut, uploadAssets: false),
        throwsA(anything),
      );
    });
  });

  group('BackupImagesUploaderService - pendingAssets', () {
    test('is empty when no user is signed in', () async {
      final signedOut = _FakeCloudService(currentUser: null);

      expect(await service.pendingAssets(signedOut), isEmpty);
    });
  });

  group('BackupImagesUploaderService - findBackfillSource', () {
    AssetDbModel buildAsset({required Map<String, Map<String, Map<String, String>>> cloudDestinations}) {
      final now = DateTime(2026, 1, 1);
      return AssetDbModel(
        id: 1,
        originalSource: 'images/1.jpg',
        cloudDestinations: cloudDestinations,
        createdAt: now,
        updatedAt: now,
        lastSavedDeviceId: null,
        permanentlyDeletedAt: null,
        type: AssetType.image,
        tags: null,
      );
    }

    test('returns null when no other connected service has the asset', () {
      final asset = buildAsset(cloudDestinations: {});

      final source = service.findBackfillSource(asset, [cloudService], cloudService);

      expect(source, isNull);
    });

    test('excludes the target service itself even if it has a matching entry', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_id': 'abc', 'file_name': '1.jpg'},
          },
        },
      );

      final source = service.findBackfillSource(asset, [cloudService], cloudService);

      expect(source, isNull);
    });
  });
}

class _FakeUser implements CloudServiceUser {
  _FakeUser({
    this.identifier = 'tester@example.com',
  });

  @override
  BackupServiceType get serviceType => BackupServiceType.google_drive;

  @override
  final String identifier;

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

class _FakeCloudService implements BackupCloudService {
  _FakeCloudService({
    required this.currentUser,
  });

  @override
  final CloudServiceUser? currentUser;

  @override
  Future<List<int>?> downloadFileBytes(String fileId) async => null;

  @override
  BackupServiceType get serviceType => BackupServiceType.google_drive;

  final List<String> uploadedFileNames = [];

  @override
  bool get isSignedIn => currentUser != null;

  @override
  bool get autoBackupEnabled => true;

  @override
  bool get hasCompression => true;

  @override
  Future<CloudFileObject?> uploadFile(String fileName, io.File file, {String? folderName}) async {
    uploadedFileNames.add(fileName);
    return null;
  }

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
