import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/databases/adapters/base_db_adapter.dart';
import 'package:storypad/core/databases/models/preference_db_model.dart';
import 'package:storypad/core/objects/search_filter_object.dart';
import 'package:storypad/core/storages/daily_scores_storage.dart';
import 'package:storypad/core/storages/previously_visited_template_tab.dart';
import 'package:storypad/core/types/app_logo.dart';

/// Each portable local store gets its own stable global row, so changing a
/// filter cannot overwrite another device's daily scores. Never snapshot all
/// SharedPreferences: sync cursors, device IDs and authentication are local.
class PortableSettings {
  static const ids = {
    'DailyScoresStorage': 6,
    'SearchFilterStorage': 7,
    'PreferredEmojiTabStorage': 8,
    'PreviouslyVisitedTemplateTabIndexStorage': 9,
    '_AppLogoStorage': 10,
    'DimissedSurveysStorage': 11,
    'NewBadgeStorage': 12,
    'StoryWriteCountStorage': 13,
  };

  static final scoresRestored = ValueNotifier<int>(0);

  static Future<void> record(String key, String? value, {BaseDbAdapter<PreferenceDbModel>? database}) async {
    final id = ids[key];
    if (id == null) return;
    final db = database ?? PreferenceDbModel.db;
    final old = await db.find(id, returnDeleted: true);
    if (value == null && (old == null || old.permanentlyDeletedAt != null)) return;
    if (old?.value == value && old?.permanentlyDeletedAt == null) return;
    final now = DateTime.now();
    await db.set(
      PreferenceDbModel(
        id: id,
        key: key,
        value: value ?? '',
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        lastSavedDeviceId: kDeviceInfo.id,
        permanentlyDeletedAt: value == null ? now : null,
      ),
    );
  }

  // Migrate pre-existing local choices only after remote rows have won.
  static Future<bool> seedMissing(BaseDbAdapter<PreferenceDbModel> db) async {
    final prefs = await SharedPreferences.getInstance();
    var changed = false;
    for (final entry in ids.entries) {
      final raw = prefs.get(entry.key);
      if (raw is! String || await db.find(entry.value, returnDeleted: true) != null) continue;
      await record(entry.key, raw, database: db);
      changed = true;
    }
    return changed;
  }

  static Future<void> restore(PreferenceDbModel row) async {
    if (ids[row.key] != row.id) return;
    final deleted = row.permanentlyDeletedAt != null;
    dynamic data;
    if (!deleted) {
      try {
        data = jsonDecode(row.value)['data'];
        switch (row.key) {
          case 'PreviouslyVisitedTemplateTabIndexStorage':
          case 'StoryWriteCountStorage':
            if (data is! int || data < 0) return;
          case '_AppLogoStorage':
            if (!AppLogo.values.any((logo) => logo.toString() == data)) return;
          case 'SearchFilterStorage':
            SearchFilterObject.fromJson(jsonDecode(data));
          case 'DimissedSurveysStorage':
            if (jsonDecode(data) is! List) return;
          default:
            if (jsonDecode(data) is! Map<String, dynamic>) return;
        }
      } catch (_) {
        return; // One malformed optional setting must not block a diary restore.
      }
    }
    // Bypass the write-through adapter: imports are not new local edits.
    final prefs = await SharedPreferences.getInstance();
    if (deleted) {
      await prefs.remove(row.key);
    } else {
      await prefs.setString(row.key, row.value);
    }
    if (row.key == 'PreviouslyVisitedTemplateTabIndexStorage') {
      PreviouslyVisitedTemplateTabIndexStorage.appInstance.currentIndex = data as int?;
    } else if (row.key == '_AppLogoStorage') {
      kAppLogo = AppLogo.values.firstWhere((logo) => logo.toString() == data, orElse: () => AppLogo.values.first);
    } else if (row.key == DailyScoresStorage().key) {
      scoresRestored.value++;
    }
  }
}
