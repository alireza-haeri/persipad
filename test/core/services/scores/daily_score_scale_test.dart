import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';

void main() {
  group('the palette', () {
    test('runs red → orange → deep green', () {
      // The three anchors the user asked for, by hue rather than by hex: the
      // exact colours may be tuned, the *order and identity* must not be.
      expect(DailyScoreScale.hsvOf(0).hue, closeTo(0.0, 2.0));
      expect(DailyScoreScale.hsvOf(50).hue, closeTo(30.0, 2.0));
      expect(DailyScoreScale.hsvOf(100).hue, closeTo(145.0, 2.0));
    });

    test('is saturated everywhere, so the middle is orange and not beige', () {
      for (final int score in [0, 10, 25, 50, 75, 90, 100]) {
        expect(
          DailyScoreScale.hsvOf(score).saturation,
          greaterThan(0.6),
          reason: 'a washed-out $score would read as "no data"',
        );
      }
    });

    test('moves monotonically from red towards green', () {
      double previous = DailyScoreScale.hsvOf(0).hue;
      for (int score = 5; score <= 100; score += 5) {
        final double hue = DailyScoreScale.hsvOf(score).hue;
        expect(hue, greaterThanOrEqualTo(previous));
        previous = hue;
      }
    });
  });

  group('bounds', () {
    test('clamps instead of throwing', () {
      expect(DailyScoreScale.clamp(-10), 0);
      expect(DailyScoreScale.clamp(1000), 100);
      expect(DailyScoreScale.colorOf(-5), DailyScoreScale.colorOf(0));
      expect(DailyScoreScale.colorOf(500), DailyScoreScale.colorOf(100));
    });

    test('the default value sits in the middle so a fresh day starts neutral', () {
      expect(DailyScoreScale.defaultValue, 50);
    });
  });

  test('the gradient keeps 21 stops of the same ramp', () {
    final colors = DailyScoreScale.gradient().colors;

    expect(colors.length, 21);
    expect(colors.first, DailyScoreScale.colorOf(0));
    expect(colors.last, DailyScoreScale.colorOf(100));
    // A two-stop RGB gradient would put a different colour in the middle; the
    // sampled one must still match `colorOf`.
    expect(colors[10], DailyScoreScale.colorOf(50));
  });

  group('the gradient runs from 0 to 100 in reading order', () {
    test('left to right in LTR', () {
      final gradient = DailyScoreScale.gradient();

      expect(gradient.begin, Alignment.centerLeft);
      expect(gradient.end, Alignment.centerRight);
      expect(gradient.colors.first, DailyScoreScale.colorOf(0));
      expect(gradient.colors.last, DailyScoreScale.colorOf(100));
    });

    test('right to left in RTL, so 0 is red on the right like the bar reads it', () {
      final gradient = DailyScoreScale.gradient(rtl: true);

      // The bar puts 0 at the right edge in Persian; the palette has to agree, or
      // 100 comes out red and 0 green. The ends are swapped here rather than left
      // to the ambient TextDirection, which is what caused that bug.
      expect(gradient.begin, Alignment.centerRight);
      expect(gradient.end, Alignment.centerLeft);
      expect(gradient.colors.first, DailyScoreScale.colorOf(0));
      expect(gradient.colors.last, DailyScoreScale.colorOf(100));
    });

    test('vertical keeps its top-to-bottom ends whatever the direction', () {
      expect(DailyScoreScale.gradient(vertical: true, rtl: true).begin, Alignment.topCenter);
      expect(DailyScoreScale.gradient(vertical: true, rtl: true).end, Alignment.bottomCenter);
    });
  });

  test('labels follow the language digits', () {
    expect(DailyScoreScale.label(72, const Locale('en')), '72');
    expect(DailyScoreScale.label(72, const Locale('fa')), '۷۲');
    expect(DailyScoreScale.label(140, const Locale('en')), '100');
  });
}
