import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/backup_file_object.dart';
import 'package:storypad/core/objects/backup_object.dart';
import 'package:storypad/core/objects/device_info_object.dart';
import 'package:storypad/core/services/backups/backup_cloud_service.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_importer_service.dart';
import 'package:storypad/core/services/backups/sync_steps/backup_sync_messenger.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/restore_backup_service.dart';
import 'package:storypad/core/storages/backup_import_history_storage.dart';

/// Regression tests for the "sync re-imports nothing, yet home reloads" bug.
///
/// `BackupImporterService.start` used to return `true` even when it imported
/// zero records (and even when it short-circuited because there was nothing to
/// import), which made `BackupRepository.syncService` mark the sync as "did
/// import" and fire `restoreService.notify()` — triggering a full home reload
/// on every no-op sync.
void main() {
  group('BackupImporterService', () {
    late BackupSyncMessenger messenger;

    setUp(() => messenger = BackupSyncMessenger());
    tearDown(() => messenger.dispose());

    BackupObject buildBackup({int year = 2026}) {
      return BackupObject(
        tables: const <String, dynamic>{},
        year: year,
        fileInfo: BackupFileObject(
          createdAt: DateTime.utc(2026, 11, 16),
          device: DeviceInfoObject(model: 'test', id: 'test-device'),
          hasCompression: false,
        ),
      );
    }

    test('reports no changes and skips notify() when there is nothing to import', () async {
      final restoreService = _CountingRestoreService(changesPerRestore: 0);
      final importer = BackupImporterService(messenger: messenger);

      final changed = await importer.start(
        restoreService,
        _UnsignedCloudService(),
        _NoopImportHistoryStorage(),
        const <int, BackupObject>{},
        const <int, DateTime?>{},
        const <int, DateTime?>{},
      );

      expect(changed, isFalse);
      expect(restoreService.notifyCount, 0);
      expect(restoreService.restoreCount, 0);
    });

    test('reports no changes and skips notify() when every record is already up to date', () async {
      final restoreService = _CountingRestoreService(changesPerRestore: 0);
      final importer = BackupImporterService(messenger: messenger);

      final changed = await importer.start(
        restoreService,
        _UnsignedCloudService(),
        _NoopImportHistoryStorage(),
        {2026: buildBackup()},
        const <int, DateTime?>{},
        const <int, DateTime?>{},
      );

      expect(changed, isFalse);
      expect(restoreService.notifyCount, 0);
    });

    test('reports changes and notifies once when records actually changed', () async {
      final restoreService = _CountingRestoreService(changesPerRestore: 3);
      final importer = BackupImporterService(messenger: messenger);

      final changed = await importer.start(
        restoreService,
        _UnsignedCloudService(),
        _NoopImportHistoryStorage(),
        {2026: buildBackup()},
        const <int, DateTime?>{},
        const <int, DateTime?>{},
      );

      expect(changed, isTrue);
      expect(restoreService.notifyCount, 1);
    });

    test('defers notify() to the caller when notifyCallbacks is false', () async {
      final restoreService = _CountingRestoreService(changesPerRestore: 2);
      final importer = BackupImporterService(messenger: messenger);

      final changed = await importer.start(
        restoreService,
        _UnsignedCloudService(),
        _NoopImportHistoryStorage(),
        {2026: buildBackup()},
        const <int, DateTime?>{},
        const <int, DateTime?>{},
        notifyCallbacks: false,
      );

      expect(changed, isTrue);
      expect(restoreService.notifyCount, 0);
    });
  });
}

class _CountingRestoreService extends RestoreBackupService {
  _CountingRestoreService({required this.changesPerRestore});

  final int changesPerRestore;
  int notifyCount = 0;
  int restoreCount = 0;

  @override
  Future<int> restoreOnlyNewData({
    required BackupObject backup,
    bool notifyCallbacks = true,
  }) async {
    restoreCount++;
    return changesPerRestore;
  }

  @override
  Future<void> notify() async {
    notifyCount++;
  }
}

class _NoopImportHistoryStorage implements BackupImportHistoryStorage {
  @override
  Future<void> markAsImported(BackupServiceType serviceType, int year, DateTime timestamp) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnsignedCloudService implements BackupCloudService {
  @override
  BackupServiceType get serviceType => BackupServiceType.google_drive;

  @override
  bool get isSignedIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
