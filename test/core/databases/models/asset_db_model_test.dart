import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/yearly_backup_files_object.dart';
import 'package:storypad/core/databases/models/asset_db_model.dart';
import 'package:storypad/core/objects/cloud_file_object.dart';
import 'package:storypad/core/objects/cloud_service_user.dart';
import 'package:storypad/core/objects/cloud_storage_quota_object.dart';
import 'package:storypad/core/services/backups/backup_cloud_service.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/types/asset_type.dart';

void main() {
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

  group('AssetDbModel.allCloudDestinations', () {
    test('is empty when never uploaded anywhere', () {
      final asset = buildAsset(cloudDestinations: {});
      expect(asset.allCloudDestinations, isEmpty);
    });

    test('flattens service+identifier into one list', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_id': 'abc', 'file_name': '1.jpg'},
          },
        },
      );

      expect(asset.allCloudDestinations, hasLength(1));
      expect(
        asset.allCloudDestinations,
        containsAll([
          (serviceType: BackupServiceType.google_drive, identifier: 'tester@example.com', fileId: 'abc'),
        ]),
      );
    });

    test('includes multiple identifiers under the same service', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_id': 'abc', 'file_name': '1.jpg'},
            'other@example.com': {'file_id': 'def', 'file_name': '1.jpg'},
          },
        },
      );

      expect(asset.allCloudDestinations, hasLength(2));
    });

    test('skips an entry with no file_id', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_name': '1.jpg'},
          },
        },
      );

      expect(asset.allCloudDestinations, isEmpty);
    });
  });

  group('AssetDbModel.matchingCloudDestinationFor', () {
    test('is null when the asset has no destinations at all', () {
      final asset = buildAsset(cloudDestinations: {});
      final drive = _FakeCloudService(currentUser: _FakeUser());

      expect(asset.matchingCloudDestinationFor([drive]), isNull);
    });

    test('is null when no signed-in service is passed', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_id': 'abc', 'file_name': '1.jpg'},
          },
        },
      );

      expect(asset.matchingCloudDestinationFor([]), isNull);
    });

    test('is null when the destination belongs to a different (switched) account on the same service', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'old@example.com': {'file_id': 'abc', 'file_name': '1.jpg'},
          },
        },
      );
      final drive = _FakeCloudService(currentUser: _FakeUser(identifier: 'new@example.com'));

      expect(asset.matchingCloudDestinationFor([drive]), isNull);
    });

    test('finds the destination matching the currently signed-in account', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_id': 'abc', 'file_name': '1.jpg'},
          },
        },
      );
      final drive = _FakeCloudService(currentUser: _FakeUser(identifier: 'tester@example.com'));

      final destination = asset.matchingCloudDestinationFor([drive]);

      expect(destination?.serviceType, BackupServiceType.google_drive);
      expect(destination?.identifier, 'tester@example.com');
      expect(destination?.fileId, 'abc');
    });
  });

  group('AssetDbModel.matchingCloudDestinationsFor', () {
    test('is empty when nothing matches', () {
      final asset = buildAsset(cloudDestinations: {});
      final drive = _FakeCloudService(currentUser: _FakeUser());

      expect(asset.matchingCloudDestinationsFor([drive]), isEmpty);
    });

    test('returns only the destination matching the signed-in account when multiple accounts exist', () {
      final asset = buildAsset(
        cloudDestinations: {
          BackupServiceType.google_drive.id: {
            'tester@example.com': {'file_id': 'drive-id', 'file_name': '1.jpg'},
            'other@example.com': {'file_id': 'other-id', 'file_name': '1.jpg'},
          },
        },
      );
      final drive = _FakeCloudService(
        currentUser: _FakeUser(identifier: 'tester@example.com'),
      );

      final destinations = asset.matchingCloudDestinationsFor([drive]);

      expect(destinations, hasLength(1));
      expect(destinations.single.identifier, 'tester@example.com');
      expect(destinations.single.fileId, 'drive-id');
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
  BackupServiceType get serviceType => BackupServiceType.google_drive;

  @override
  bool get isSignedIn => currentUser != null;

  @override
  bool get autoBackupEnabled => true;

  @override
  bool get hasCompression => true;

  @override
  Future<List<int>?> downloadFileBytes(String fileId) async => null;

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
