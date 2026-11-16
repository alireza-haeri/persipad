import 'dart:ui' show Locale;

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

  test('labels follow the language digits', () {
    expect(DailyScoreScale.label(72, const Locale('en')), '72');
    expect(DailyScoreScale.label(72, const Locale('fa')), '۷۲');
    expect(DailyScoreScale.label(140, const Locale('en')), '100');
  });
}
