import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/app_theme.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/gen/fonts.gen.dart';

void main() {
  group('AppTheme offline dual-font resolution', () {
    test('Persian resolves to Vazirmatn and English resolves to Quicksand', () {
      expect(AppTheme.fontFamilyForLanguageCode('fa'), FontFamily.vazirmatn);
      expect(AppTheme.fontFamilyForLanguageCode('en'), FontFamily.quicksand);
      expect(AppTheme.fontFamilyForLanguageCode('en'), kDefaultFontFamily);
    });

    test('getTheme applies the resolved font family and script fallback chain', () {
      final enTheme = AppTheme.getTheme(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: AppTheme.fontFamilyForLanguageCode('en'),
        fontWeight: FontWeight.w400,
      );
      final faTheme = AppTheme.getTheme(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: AppTheme.fontFamilyForLanguageCode('fa'),
        fontWeight: FontWeight.w400,
      );

      expect(enTheme.textTheme.bodyMedium?.fontFamily, 'Quicksand');
      expect(enTheme.textTheme.bodyMedium?.fontFamilyFallback, kScriptFontFamilyFallback);
      expect(faTheme.textTheme.bodyMedium?.fontFamily, 'Vazirmatn');
      expect(faTheme.textTheme.bodyMedium?.fontFamilyFallback, kScriptFontFamilyFallback);
    });

    test('both font families exist as non-empty offline assets in assets/fonts/', () {
      const requiredAssets = <String>[
        'assets/fonts/Quicksand-Variable.ttf',
        'assets/fonts/Vazirmatn-Regular.ttf',
        'assets/fonts/Vazirmatn-Medium.ttf',
        'assets/fonts/Vazirmatn-SemiBold.ttf',
        'assets/fonts/Vazirmatn-Bold.ttf',
      ];

      for (final assetPath in requiredAssets) {
        final file = File(assetPath);
        expect(file.existsSync(), isTrue, reason: 'missing offline font asset: $assetPath');
        expect(file.lengthSync(), greaterThan(10000), reason: 'truncated font asset: $assetPath');
      }
    });
  });
}
