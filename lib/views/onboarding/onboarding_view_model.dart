import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/databases/models/preference_db_model.dart';
import 'package:storypad/core/types/gender_option.dart';
import 'package:storypad/providers/gender_provider.dart';
import 'package:storypad/providers/nickname_provider.dart';
import 'package:storypad/views/onboarding/steps/onboarding_hello_view.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'onboarding_view.dart';

class OnboardingViewModel extends ChangeNotifier with DisposeAwareMixin {
  final OnboardingRoute params;

  OnboardingViewModel({
    required this.params,
    required this.genderProvider,
  }) : selectedGender = genderProvider.gender;

  final GenderProvider genderProvider;
  final TextEditingController controller = TextEditingController(text: PreferenceDbModel.db.nickname.get());
  GenderOption? selectedGender;
  bool _savingGender = false;
  bool get canProceed => selectedGender != null && !_savingGender;

  Future<void> selectGender(GenderOption value) async {
    if (selectedGender == value || _savingGender) return;
    selectedGender = value;
    _savingGender = true;
    notifyListeners();
    try {
      await genderProvider.setGender(value);
    } finally {
      _savingGender = false;
      notifyListeners();
    }
  }

  void next(BuildContext context) {
    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('page.gender.required'))),
      );
      return;
    }

    if (Form.of(context).validate()) {
      String nickname = controller.text.trim();
      context.read<NicknameProvider>().setNickname(nickname);
      OnboardingHelloRoute(nickname: nickname).push(context);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
