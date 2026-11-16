import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';

/// The 0–100 scale a day's score lives on, and the single place that decides
/// what a value *looks* like.
///
/// Every surface (the input bar, the calendar cell, both charts) colours a score
/// through [colorOf], so a 30 is the same orange everywhere and the user learns
/// the palette once. Nothing here is theme-dependent: "red is a bad day, green is
/// a good one" is the point of the feature, not a design accent that should
/// follow the app theme.
class DailyScoreScale {
  const DailyScoreScale._();

  static const int min = 0;
  static const int max = 100;
  static const int defaultValue = 50;

  static int clamp(int value) => value < min ? min : (value > max ? max : value);

  /// A bare score in the language's digits (`۷۲` for Persian, `72` elsewhere).
  static String label(int score, Locale locale) => DateFormatHelper.number(clamp(score), locale);

  // Deep red → orange → deep green. Interpolated in HSV, not RGB: a plain
  // `Color.lerp(red, green, .5)` passes through muddy brown, and 50 is the value
  // a "how was today" scale is read at most often.
  static final HSVColor _low = HSVColor.fromAHSV(1.0, 0.0, 0.78, 0.85);
  static final HSVColor _mid = HSVColor.fromAHSV(1.0, 30.0, 0.88, 0.95);
  static final HSVColor _high = HSVColor.fromAHSV(1.0, 145.0, 0.72, 0.58);

  static HSVColor hsvOf(int score) {
    final double t = clamp(score) / max;
    return t <= 0.5
        ? HSVColor.lerp(_low, _mid, t * 2)!
        : HSVColor.lerp(_mid, _high, (t - 0.5) * 2)!;
  }

  static Color colorOf(int score) => hsvOf(score).toColor();

  /// The whole scale as a gradient, for the input bar that teaches the palette.
  ///
  /// Sampled at 21 stops rather than two, because two RGB stops would draw a
  /// straight line through colour space and reintroduce the brown middle that
  /// [hsvOf] exists to avoid. `LinearGradient` resolves left→right through the
  /// ambient [TextDirection], so in Persian the ramp runs red-on-the-right to
  /// green-on-the-left, matching the bar's own direction.
  static LinearGradient gradient({double opacity = 1.0, bool vertical = false}) {
    return LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [
        for (int i = 0; i <= 20; i++) colorOf(i * 5).withValues(alpha: opacity),
      ],
    );
  }
}
