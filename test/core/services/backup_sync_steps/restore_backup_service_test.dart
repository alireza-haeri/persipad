import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/adapters/base_db_adapter.dart';
import 'package:storypad/core/databases/models/base_db_model.dart';
import 'package:storypad/core/databases/models/collection_db_model.dart';
import 'package:storypad/core/objects/backup_file_object.dart';
import 'package:storypad/core/objects/backup_object.dart';
import 'package:storypad/core/objects/device_info_object.dart';
import 'package:storypad/core/repositories/backup_repository.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/restore_backup_service.dart';

/// The merge rules in [RestoreBackupService.restoreOnlyNewData] decide which copy
/// of a note survives a sync. They are pure timestamp comparisons, but a mistake
/// here silently destroys data on one of the devices — so they get a table test
/// instead of trust (`ai/ANALYSIS.md` §2, `BACKLOG.md` T-10).
///
/// Everything runs against a fake [BaseDbAdapter]: no ObjectBox, no files.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late RestoreBackupService service;

  setUp(() {
    adapter = _FakeAdapter(tableName: 'stories');
    BackupRepository.overrideDatabases([adapter]);
    service = RestoreBackupService();
  });

  tearDown(() => BackupRepository.overrideDatabases(const []));

  final older = DateTime(2026, 11, 1, 10);
  final newer = DateTime(2026, 11, 2, 10);

  BackupObject backupWith(List<_FakeModel> records) {
    return BackupObject(
      tables: {
        'stories': [for (final record in records) record.toJson()],
      },
      fileInfo: BackupFileObject(
        createdAt: newer,
        device: DeviceInfoObject(model: 'test', id: 'test-device'),
        hasCompression: false,
        version: '4',
        year: 2026,
      ),
    );
  }

  group('device copy is newer', () {
    test('keeps the device copy, touches it so it uploads again, and imports nothing', () async {
      adapter.existing = _FakeModel(id: 1, updatedAt: newer, body: 'device');
      final backup = backupWith([_FakeModel(id: 1, updatedAt: older, body: 'backup')]);

      final changes = await service.restoreOnlyNewData(backup: backup);

      expect(changes, 0);
      expect(adapter.sets, isEmpty, reason: 'the device version must not be overwritten');
      expect(adapter.touches, 1, reason: 'touch() is what marks the row unsynced for the next upload');
      expect(adapter.existing!.body, 'device');
    });
  });

  group('backup copy is newer', () {
    test('imports the backup copy and counts it as one change', () async {
      adapter.existing = _FakeModel(id: 1, updatedAt: older, body: 'device');
      final backup = backupWith([_FakeModel(id: 1, updatedAt: newer, body: 'backup')]);

      final changes = await service.restoreOnlyNewData(backup: backup);

      expect(changes, 1);
      expect(adapter.sets, hasLength(1));
      expect(adapter.sets.single.body, 'backup');
      expect(adapter.touches, 0);
    });
  });

  group('timestamps are equal', () {
    test('is a no-op in both directions', () async {
      adapter.existing = _FakeModel(id: 1, updatedAt: older, body: 'device');
      final backup = backupWith([_FakeModel(id: 1, updatedAt: older, body: 'backup')]);

      final changes = await service.restoreOnlyNewData(backup: backup);

      expect(changes, 0);
      expect(adapter.sets, isEmpty);
      expect(adapter.touches, 0, reason: 'equal timestamps are "nothing happened", not "re-upload"');
    });
  });

  group('the record does not exist locally', () {
    test('is inserted even when the timestamps would not matter', () async {
      final backup = backupWith([_FakeModel(id: 7, updatedAt: older, body: 'from phone')]);

      final changes = await service.restoreOnlyNewData(backup: backup);

      expect(changes, 1);
      expect(adapter.sets.single.id, 7);
      expect(adapter.touches, 0);
    });
  });

  group('missing timestamps', () {
    test('a record without updatedAt is treated as absent and imported', () async {
      adapter.existing = _FakeModel(id: 1, updatedAt: null, body: 'device');
      final backup = backupWith([_FakeModel(id: 1, updatedAt: older, body: 'backup')]);

      final changes = await service.restoreOnlyNewData(backup: backup);

      expect(changes, 1);
      expect(adapter.sets.single.body, 'backup');
    });

    test('a backup record without updatedAt never overwrites the device copy', () async {
      adapter.existing = _FakeModel(id: 1, updatedAt: newer, body: 'device');
      final backup = backupWith([_FakeModel(id: 1, updatedAt: null, body: 'backup')]);

      final changes = await service.restoreOnlyNewData(backup: backup);

      expect(changes, 1, reason: 'the else-branch imports unknown-timestamp records by design');
      expect(adapter.sets.single.body, 'backup');
    });
  });

  group('listeners', () {
    test('are notified once per restoreOnlyNewData call, not per record', () async {
      var notified = 0;
      service.addListener(() async => notified++);
      adapter.existing = _FakeModel(id: 1, updatedAt: older, body: 'device');
      final backup = backupWith([
        _FakeModel(id: 1, updatedAt: newer, body: 'a'),
        _FakeModel(id: 2, updatedAt: newer, body: 'b'),
      ]);

      await service.restoreOnlyNewData(backup: backup);

      expect(notified, 1);
    });

    test('notifyCallbacks: false suppresses them so a multi-file batch rebuilds once', () async {
      var notified = 0;
      service.addListener(() async => notified++);
      final backup = backupWith([_FakeModel(id: 1, updatedAt: newer, body: 'a')]);

      await service.restoreOnlyNewData(backup: backup, notifyCallbacks: false);
      await service.notify();

      expect(notified, 1, reason: 'the batch calls notify() itself, after the last file');
    });
  });

  group('forceRestore', () {
    test('overwrites regardless of timestamps and notifies once', () async {
      var notified = 0;
      service.addListener(() async => notified++);
      adapter.existing = _FakeModel(id: 1, updatedAt: newer, body: 'device');
      final backup = backupWith([_FakeModel(id: 1, updatedAt: older, body: 'backup')]);

      await service.forceRestore(backup: backup);

      expect(adapter.sets.single.body, 'backup');
      expect(adapter.touches, 0);
      expect(notified, 1);
    });
  });
}

class _FakeModel extends BaseDbModel {
  _FakeModel({required this.id, required this.updatedAt, required this.body});

  @override
  final int id;

  @override
  final DateTime? updatedAt;

  final String body;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'updated_at': updatedAt?.toIso8601String(),
    'body': body,
  };
}

/// Minimal [BaseDbAdapter] that records what the merge logic asked for.
///
/// Only the four methods `RestoreBackupService` calls are implemented; the rest
/// throw, so an accidental future dependency on the real database shows up as a
/// failing test rather than a hanging one.
class _FakeAdapter extends BaseDbAdapter<_FakeModel> {
  _FakeAdapter({required this.tableName});

  @override
  final String tableName;

  _FakeModel? existing;

  final List<_FakeModel> sets = [];
  int touches = 0;

  @override
  Future<_FakeModel?> find(int id, {bool returnDeleted = false}) async {
    return existing?.id == id ? existing : null;
  }

  @override
  Future<_FakeModel?> set(_FakeModel record, {bool runCallbacks = true}) async {
    sets.add(record);
    existing = record;
    return record;
  }

  @override
  Future<_FakeModel?> touch(_FakeModel record, {bool runCallbacks = true}) async {
    touches++;
    return record;
  }

  @override
  _FakeModel modelFromJson(Map<String, dynamic> json) {
    return _FakeModel(
      id: json['id'] as int,
      updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
      body: json['body'] as String,
    );
  }

  @override
  Future<Map<int, DateTime?>> getLastUpdatedAtByYear({bool? fromThisDeviceOnly}) =>
      throw UnimplementedError('not used by the merge');

  @override
  Future<int> count({Map<String, dynamic>? filters, required String? debugSource}) =>
      throw UnimplementedError('not used by the merge');

  @override
  Future<CollectionDbModel<_FakeModel>?> where({
    Map<String, dynamic>? filters,
    Map<String, dynamic>? options,
    bool returnDeleted = false,
  }) => throw UnimplementedError('not used by the merge');

  @override
  Future<void> setAll(List<_FakeModel> records, {bool runCallbacks = true}) =>
      throw UnimplementedError('not used by the merge');

  @override
  Future<_FakeModel?> update(_FakeModel record, {bool runCallbacks = true}) =>
      throw UnimplementedError('not used by the merge');

  @override
  Future<_FakeModel?> create(_FakeModel record, {bool runCallbacks = true}) =>
      throw UnimplementedError('not used by the merge');

  @override
  Future<_FakeModel?> delete(int id, {bool softDelete = true, bool runCallbacks = true, DateTime? deletedAt}) =>
      throw UnimplementedError('not used by the merge');

  @override
  bool hasDeleted(int id) => false;
}
