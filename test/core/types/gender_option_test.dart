import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/types/app_logo.dart';
import 'package:storypad/core/types/gender_option.dart';

void main() {
  group('GenderOption', () {
    test('maps each choice to the corresponding profile illustration', () {
      expect(GenderOption.male.appLogo, AppLogo.storypad_2_0);
      expect(GenderOption.female.appLogo, AppLogo.storypad_1_0);
    });

    test('parses stored values and ignores unknown values', () {
      expect(GenderOption.fromStored('male'), GenderOption.male);
      expect(GenderOption.fromStored('female'), GenderOption.female);
      expect(GenderOption.fromStored('unknown'), isNull);
      expect(GenderOption.fromStored(null), isNull);
    });
  });
}
