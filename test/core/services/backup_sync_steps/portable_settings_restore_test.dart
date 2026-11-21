import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/databases/adapters/base_db_adapter.dart';
import 'package:storypad/core/databases/models/asset_db_model.dart';
import 'package:storypad/core/databases/models/base_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/tag_db_model.dart';
import 'package:storypad/core/databases/models/collection_db_model.dart';
import 'package:storypad/core/databases/models/preference_db_model.dart';
import 'package:storypad/core/objects/backup_file_object.dart';
import 'package:storypad/core/objects/backup_object.dart';
import 'package:storypad/core/objects/device_info_object.dart';
import 'package:storypad/core/objects/device_preferences_object.dart';
import 'package:storypad/core/repositories/backup_repository.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/backup_databases_to_backup_object_service.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/restore_backup_service.dart';
import 'package:storypad/core/storages/daily_scores_storage.dart';
import 'package:storypad/core/storages/device_preferences_storage.dart';
import 'package:storypad/core/storages/portable_settings.dart';
import 'package:storypad/core/storages/storage_adapters/share_preferences_storage_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => kDeviceInfo = DeviceInfoObject(model: 'source', id: 'source-id'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DevicePreferencesStorage.localeCodeNotifier.value = null;
  });
  tearDown(() {
    BackupRepository.overrideDatabases([]);
    SharePreferencesStorageAdapter.onLocalWrite = null;
  });

  for (final year in [null, BackupFileObject.kGlobalBackupYear]) {
    test('settings survive export, clean-device restore and a second import (bucket $year)', () async {
      final source = _Preferences();
      final storage = DevicePreferencesStorage(database: source);
      final settings = DevicePreferencesObject.fromJson({
        'font_family': 'Vazirmatn',
        'font_size': 'large',
        'font_weight_index': 5,
        'theme_mode': 'dark',
        'color_seed_value': 123,
        'color_by_day': {'6': 'red'},
        'voice_playback_speed': 1.5,
        'video_playback_speed': 2.0,
        'video_muted': true,
        'time_format': 'h24',
        'first_day_of_week': 'saturday',
        'calendar_system': 'persian',
        'weekend_days': [4, 5],
        'asset_compression': 'none',
        'media_sync': 'wifiOnly',
        'map_style': 'satellite',
        'map_renderer': 'flutterMap',
        'story_tile_preferences': {'photo_collage': true, 'display_character_count': 42},
        'default_story_preferences': {'default_color_seed_value': 345},
        'home_quick_actions': [
          {'label': 'کار', 'type': 'tag', 'tag_id': 12},
        ],
        'hidden_stats_sections': ['moods'],
        'enable_relax_sounds': true,
        'enable_period_calendar': true,
        'enable_daily_score': true,
        'enable_map': false,
        'sidebar_order': ['search', 'home'],
        'reminders': [
          {
            'id': 11,
            'type': 'custom',
            'enabled': true,
            'hour': 8,
            'minute': 45,
            'weekdays': [],
            'recurrence': 'monthly',
            'interval_months': 3,
            'anchor_date': '2026-11-20',
            'anchor_day': 29,
            'message': 'یادآوری',
            'tag_ids': [12],
            'gallery_template_id': 'gratitude',
          },
        ],
      });
      await storage.writeObject(settings);
      await storage.setLocaleCode('en');
      final now = DateTime.utc(2026, 11, 20);
      for (final (id, key, value) in [(2, 'nickname', 'آوا'), (5, 'gender', 'female')]) {
        await source.set(
          PreferenceDbModel(
            id: id,
            key: key,
            value: value,
            createdAt: now,
            updatedAt: now,
            lastSavedDeviceId: 'source-id',
            permanentlyDeletedAt: null,
          ),
        );
      }
      // Pre-upgrade scores exist only locally; later edits must update the seeded row.
      await DailyScoresStorage().writeScores({'2026-11-19': 0});
      expect(await storage.ensureBackupSnapshotExists(), isTrue);
      SharePreferencesStorageAdapter.onLocalWrite = (key, value) =>
          PortableSettings.record(key, value, database: source);
      await DailyScoresStorage().writeScores({'2026-11-19': 0, '2026-11-20': 98});
      expect(await storage.ensureBackupSnapshotExists(), isFalse);
      final backup = await BackupDatabasesToBackupObjectService.call(
        databases: [source],
        lastUpdatedAt: now,
        hasCompression: false,
        year: year,
      );
      final wire = BackupObject.fromContents(jsonDecode(jsonEncode(backup.toContents())));
      SharedPreferences.setMockInitialValues({});
      final destination = _Preferences();
      BackupRepository.overrideDatabases([destination]);
      final restored = DevicePreferencesStorage(database: destination);
      final service = RestoreBackupService()
        ..addListener(() async {
          await restored.restoreFromBackupRecord();
        });
      expect(await service.restoreOnlyNewData(backup: wire), 4);
      expect(await service.restoreOnlyNewData(backup: wire), 0);
      expect(await restored.ensureBackupSnapshotExists(), isFalse);
      expect((await restored.readObject())!.toJson(), settings.toJson());
      expect(restored.preferences.reminders!.single.anchorDay, 29);
      expect((await SharedPreferences.getInstance()).getString('locale'), 'en');
      expect(destination.rows[2]!.value, 'آوا');
      expect(destination.rows[5]!.value, 'female');
      expect(await DailyScoresStorage().readScores(), {'2026-11-19': 0, '2026-11-20': 98});
    });
  }

  test('explicit local import restores every portable store and keeps credentials on the target', () async {
    final db = _Preferences();
    final settings = DevicePreferencesStorage(database: db);
    final values = <String, dynamic>{
      'DailyScoresStorage': jsonEncode({'2026-11-20': 0}),
      'SearchFilterStorage': jsonEncode({
        'years': [1405],
        'types': [],
        'query': 'دفتر',
      }),
      'PreferredEmojiTabStorage': jsonEncode({'2': 'SMILEYS'}),
      'PreviouslyVisitedTemplateTabIndexStorage': 1,
      '_AppLogoStorage': 'AppLogo.storypad_2_0',
      'DimissedSurveysStorage': jsonEncode(['survey']),
      'NewBadgeStorage': jsonEncode({'badge': true}),
      'StoryWriteCountStorage': 12,
    };
    expect(values.keys.toSet(), PortableSettings.ids.keys.toSet());
    SharedPreferences.setMockInitialValues({
      for (final entry in values.entries) entry.key: jsonEncode({'data': entry.value}),
      'AppLockStorage': 'source secret',
    });
    await settings.syncLocaleCode('en', followDevice: true);
    await settings.ensureBackupSnapshotExists();
    final file = await BackupDatabasesToBackupObjectService.call(
      databases: [db],
      lastUpdatedAt: DateTime.now(),
      hasCompression: false,
    );
    expect(jsonEncode(file.toContents()), isNot(contains('source secret')));
    SharedPreferences.setMockInitialValues({'AppLockStorage': 'target secret', 'locale': 'en'});
    final target = _Preferences();
    BackupRepository.overrideDatabases([target]);
    final restored = DevicePreferencesStorage(database: target);
    final service = RestoreBackupService()
      ..addListener(() async {
        await restored.restoreFromBackupRecord();
      });
    await service.forceRestore(backup: BackupObject.fromContents(jsonDecode(jsonEncode(file.toContents()))));
    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      expect(jsonDecode(prefs.getString(entry.key)!)['data'], entry.value, reason: entry.key);
    }
    expect(prefs.getString('AppLockStorage'), 'target secret');
    expect(restored.followsDeviceLocale, isTrue);
    expect(prefs.containsKey('locale'), isFalse);
  });

  test('restoring twice keeps a Persian Markdown entry linked to its tag and media record', () async {
    final stories = _Rows('stories', StoryDbModel.fromJson);
    final tags = _Rows('tags', TagDbModel.fromJson);
    final assets = _Rows('assets', AssetDbModel.fromJson);
    const metadata = {'created_at': '2026-11-20T09:00:00Z', 'updated_at': '2026-11-20T09:00:00Z'};
    const body = '# خاطره\n\nیک روز بارانی';
    await stories.set(
      StoryDbModel.fromJson({
        ...metadata,
        'id': 1,
        'type': 'docs',
        'starred': true,
        'year': 2026,
        'month': 11,
        'day': 20,
        'tags': ['2'],
        'assets': [3],
        'latest_content': {
          ...metadata,
          'id': 4,
          'rich_pages': [
            {'id': 5, 'format': 'markdown_v1', 'markdown': body},
          ],
        },
      }),
    );
    await tags.set(TagDbModel.fromJson({...metadata, 'id': 2, 'version': 1, 'title': 'باران'}));
    await assets.set(
      AssetDbModel.fromJson({
        ...metadata,
        'id': 3,
        'type': 'image',
        'original_source': 'photo.jpg',
        'cloud_destinations': {
          'google_drive': {
            'account': {'file_id': 'remote-image'},
          },
        },
      }),
    );
    final file = await BackupDatabasesToBackupObjectService.call(
      databases: [stories, tags, assets],
      lastUpdatedAt: DateTime.now(),
      hasCompression: false,
    );
    final wire = BackupObject.fromContents(jsonDecode(jsonEncode(file.toContents())));
    stories.rows.clear();
    tags.rows.clear();
    assets.rows.clear();
    BackupRepository.overrideDatabases([stories, tags, assets]);
    final service = RestoreBackupService();
    expect(await service.restoreOnlyNewData(backup: wire), 3);
    expect(await service.restoreOnlyNewData(backup: wire), 0);
    final story = stories.rows[1]!;
    expect(story.latestContent!.richPages!.single.toJson()['markdown'], body);
    expect(tags.rows[int.parse(story.tags!.single)]!.title, 'باران');
    expect(
      assets.rows[story.assets!.single]!.cloudDestinations['google_drive']!['account']!['file_id'],
      'remote-image',
    );
  });

  test('old backups, corrupt optional values and untrusted keys leave local settings intact', () async {
    final db = _Preferences();
    final storage = DevicePreferencesStorage(database: db);
    expect(await storage.restoreFromBackupRecord(), isNull);
    await DailyScoresStorage().writeScores({'2026-11-20': 90});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('GoogleDesktopTokenStorage', 'local only');
    await storage.ensureBackupSnapshotExists();
    expect(db.rows.values.map((r) => r.key), isNot(contains('GoogleDesktopTokenStorage')));
    final score = db.rows[6]!;
    await PortableSettings.restore(score.copyWith(value: '{invalid'));
    await PortableSettings.restore(score.copyWith(key: 'GoogleDesktopTokenStorage'));
    expect(await DailyScoresStorage().readScores(), {'2026-11-20': 90});
    expect(prefs.getString('GoogleDesktopTokenStorage'), 'local only');
    await PortableSettings.restore(score.copyWith(permanentlyDeletedAt: DateTime.now()));
    expect(await DailyScoresStorage().readScores(), isEmpty);
  });
}

class _Preferences extends _Rows<PreferenceDbModel> {
  _Preferences() : super('preferences', PreferenceDbModel.fromJson);
}

class _Rows<T extends BaseDbModel> extends Fake implements BaseDbAdapter<T> {
  _Rows(this.tableName, this.decode);
  @override
  final String tableName;
  final T Function(Map<String, dynamic>) decode;
  final rows = <int, T>{};
  @override
  bool get isYearPartitioned => tableName != 'preferences' && tableName != 'tags';
  @override
  Future<T?> find(int id, {bool returnDeleted = false}) async => rows[id];
  @override
  Future<T?> set(T row, {bool runCallbacks = true}) async => rows[row.id] = row;
  @override
  T modelFromJson(Map<String, dynamic> json) => decode(json);
  @override
  Future<CollectionDbModel<T>> where({
    Map<String, dynamic>? filters,
    Map<String, dynamic>? options,
    bool returnDeleted = false,
  }) async => CollectionDbModel(items: rows.values.toList());
}
