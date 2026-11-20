import 'package:storypad/core/types/app_logo.dart';

enum GenderOption {
  male,
  female;

  AppLogo get appLogo => switch (this) {
    GenderOption.male => AppLogo.storypad_2_0,
    GenderOption.female => AppLogo.storypad_1_0,
  };

  String get translationKey => switch (this) {
    GenderOption.male => 'page.gender.male',
    GenderOption.female => 'page.gender.female',
  };

  static GenderOption? fromStored(String? value) {
    for (final option in values) {
      if (option.name == value) return option;
    }
    return null;
  }
}
