import 'package:flutter/material.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/databases/models/preference_db_model.dart';
import 'package:storypad/core/services/app_logo_service.dart';
import 'package:storypad/core/types/gender_option.dart';
import 'package:storypad/providers/backup_provider.dart';

class GenderProvider extends ChangeNotifier {
  GenderOption? _gender = GenderOption.fromStored(PreferenceDbModel.db.gender.get());
  GenderOption? get gender => _gender;

  late final Future<void> Function() _restoreListener = _reloadAfterRestore;

  GenderProvider() {
    BackupProvider.repoInstance.restoreService.addListener(_restoreListener);
    _applyProfileIllustration();
  }

  Future<void> setGender(GenderOption value) async {
    if (_gender == value) return;

    final now = DateTime.now();
    final previous = await PreferenceDbModel.db.find(PreferenceDbModel.genderPreferenceId, returnDeleted: true);
    await PreferenceDbModel.db.set(
      PreferenceDbModel(
        id: PreferenceDbModel.genderPreferenceId,
        key: 'gender',
        value: value.name,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        lastSavedDeviceId: kDeviceInfo.id,
        permanentlyDeletedAt: null,
      ),
    );

    _gender = value;
    await _applyProfileIllustration();
    notifyListeners();
  }

  Future<void> _reloadAfterRestore() async {
    final restored = GenderOption.fromStored(PreferenceDbModel.db.gender.get());
    if (_gender == restored && (restored == null || kAppLogo == restored.appLogo)) return;

    _gender = restored;
    await _applyProfileIllustration();
    notifyListeners();
  }

  Future<void> _applyProfileIllustration() async {
    final selected = _gender;
    if (selected != null) await AppLogoService().setProfileIllustration(selected.appLogo);
  }

  @override
  void dispose() {
    BackupProvider.repoInstance.restoreService.removeListener(_restoreListener);
    super.dispose();
  }
}
