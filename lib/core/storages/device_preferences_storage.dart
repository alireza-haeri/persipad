// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/databases/models/preference_db_model.dart';
import 'package:storypad/core/extensions/font_weight_extension.dart';
import 'package:storypad/core/objects/device_preferences_object.dart';
import 'package:storypad/core/storages/base_object_storages/object_storage.dart';
import 'package:storypad/core/storages/theme_storage.dart';

class DevicePreferencesStorage extends ObjectStorage<DevicePreferencesObject> {
  static DevicePreferencesStorage appInstance = DevicePreferencesStorage();

  /// Device preferences live locally for fast startup, and a snapshot is also
  /// stored in the non-yearly preferences table so the existing full backup and
  /// Google Drive sync carry the user's settings.
  static const int _backupRecordId = 1;
  static const String _backupRecordKey = 'device_settings';
  static final ValueNotifier<String?> localeCodeNotifier = ValueNotifier(null);

  DevicePreferencesObject get preferences => _preferences ?? DevicePreferencesObject.initial();
  DevicePreferencesObject? _preferences;

  Future<void> load() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    localeCodeNotifier.value = sharedPreferences.getString('locale');

    final legacyData = await ThemeStorage().readObject();
    if (legacyData != null) {
      ThemeStorage().remove();
      DevicePreferencesObject newData = DevicePreferencesObject.initial().copyWith(
        fontFamily: legacyData.fontFamily,
        fontWeightIndex: legacyData.fontWeight.weightIndex,
        themeMode: legacyData.themeMode,
        // ignore: deprecated_member_use
        colorSeedValue: legacyData.colorSeed?.value,
      );
      _preferences = newData;
      await super.writeObject(newData);
    }

    _preferences ??= await readObject();
    if (_preferences == null) {
      // ignore: deprecated_member_use
      _preferences = DevicePreferencesObject.initial().copyWith(colorSeedValue: kDefaultColorSeed.value);
      // Persist defaults locally, but do not create a cloud row until the user
      // changes settings. This lets an existing cloud backup win on a new device.
      await super.writeObject(_preferences!);
    }
  }

  @override
  Future<void> writeObject(DevicePreferencesObject object) async {
    _preferences = object;
    await super.writeObject(object);
    await _writeBackupSnapshot(object, localeCode: localeCodeNotifier.value ?? 'fa');
  }

  /// Called when the user selects a language. The language is part of the
  /// settings snapshot even though EasyLocalization stores it separately.
  Future<void> setLocaleCode(String code) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString('locale', code);
    await syncLocaleCode(code);
  }

  /// Updates the cloud snapshot while retaining EasyLocalization's existing
  /// "follow device locale" behavior (which removes its persisted locale key).
  Future<void> syncLocaleCode(String code) async {
    localeCodeNotifier.value = code;
    await _writeBackupSnapshot(preferences, localeCode: code);
  }

  /// Seeds the settings record just before a sync uploads database changes.
  /// Running this only after remote changes have been imported means a new
  /// device won't overwrite an existing cloud settings snapshot with defaults.
  Future<bool> ensureBackupSnapshotExists() async {
    final existing = await PreferenceDbModel.db.find(_backupRecordId, returnDeleted: true);
    if (existing?.key == _backupRecordKey && existing?.permanentlyDeletedAt == null) return false;

    await _writeBackupSnapshot(preferences, localeCode: localeCodeNotifier.value ?? 'fa');
    return true;
  }

  Future<void> _writeBackupSnapshot(DevicePreferencesObject object, {required String localeCode}) async {
    final now = DateTime.now();
    final previous = await PreferenceDbModel.db.find(_backupRecordId, returnDeleted: true);
    await PreferenceDbModel.db.set(
      PreferenceDbModel(
        id: _backupRecordId,
        key: _backupRecordKey,
        value: jsonEncode({'preferences': object.toJson(), 'locale': localeCode}),
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        lastSavedDeviceId: kDeviceInfo.id,
        permanentlyDeletedAt: null,
      ),
    );
  }

  /// Applies a settings snapshot imported by the normal backup merge. Does not
  /// write back to the database, so restoring does not create a sync loop.
  Future<DevicePreferencesObject?> restoreFromBackupRecord() async {
    final record = await PreferenceDbModel.db.find(_backupRecordId, returnDeleted: true);
    if (record == null || record.permanentlyDeletedAt != null || record.key != _backupRecordKey) return null;

    try {
      final decoded = jsonDecode(record.value);
      if (decoded is! Map<String, dynamic> || decoded['preferences'] is! Map<String, dynamic>) return null;
      final restored = DevicePreferencesObject.fromJson(decoded['preferences'] as Map<String, dynamic>);
      _preferences = restored;
      await super.writeObject(restored);

      final locale = decoded['locale'];
      if (locale is String && locale.isNotEmpty) {
        final sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences.setString('locale', locale);
        localeCodeNotifier.value = locale;
      }

      return restored;
    } catch (_) {
      // A malformed/old preference record should not prevent the rest of a
      // backup from restoring.
      return null;
    }
  }

  @override
  DevicePreferencesObject decode(Map<String, dynamic> json) => DevicePreferencesObject.fromJson(json);

  @override
  Map<String, dynamic> encode(DevicePreferencesObject object) => object.toJson();
}
