import 'package:flutter/material.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';

/// Picking a 0–100 score by dragging a bar, not by typing a number.
///
/// It is deliberately shaped like a **progress bar** rather than a Material
/// [Slider]: the whole track is the 0–100 palette (red at 0, orange at 50, green
/// at 100), the filled part is the value, and the thumb is tinted with the value's
/// colour. Dragging therefore *shows* the colour the user is choosing, which a
/// plain slider cannot do.
///
/// Direction comes from the ambient [Directionality]: in Persian the bar starts
/// at the right, so 0 is on the right and the fill grows leftwards, matching how
/// the number is read everywhere else in the app.
class SpDailyScoreBar extends StatelessWidget {
  const SpDailyScoreBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.trackHeight = 18.0,
    this.thumbSize = 32.0,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double trackHeight;
  final double thumbSize;

  /// The thumb is taller than the track, so the gesture area gets padding on both
  /// sides. The whole padded box is tappable (`HitTestBehavior.opaque`), which is
  /// also what makes a thin 18px track comfortable to grab on a phone.
  static const double _verticalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final int clamped = DailyScoreScale.clamp(value);
    final double ratio = clamped / DailyScoreScale.max;
    final Color highlight = DailyScoreScale.colorOf(clamped);
    final ColorScheme colorScheme = ColorScheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth - thumbSize;

        void updateFromDx(double dx) {
          if (trackWidth <= 0) return;
          // Distance from the "0" end of the track, then normalised: in RTL the
          // 0 end is the right edge.
          final double fromStart = rtl ? constraints.maxWidth - thumbSize / 2 - dx : dx - thumbSize / 2;
          final double nextRatio = (fromStart / trackWidth).clamp(0.0, 1.0);
          final int next = (nextRatio * DailyScoreScale.max).round();
          if (next != clamped) onChanged(next);
        }

        return Semantics(
          slider: true,
          value: '${DailyScoreScale.clamp(clamped)}',
          increasedValue: '${DailyScoreScale.clamp(clamped + 1)}',
          decreasedValue: '${DailyScoreScale.clamp(clamped - 1)}',
          onIncrease: () => onChanged(DailyScoreScale.clamp(clamped + 1)),
          onDecrease: () => onChanged(DailyScoreScale.clamp(clamped - 1)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => updateFromDx(details.localPosition.dx),
            onHorizontalDragStart: (details) => updateFromDx(details.localPosition.dx),
            onHorizontalDragUpdate: (details) => updateFromDx(details.localPosition.dx),
            child: SizedBox(
              height: thumbSize + _verticalPadding * 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: thumbSize / 2,
                    right: thumbSize / 2,
                    top: _verticalPadding + (thumbSize - trackHeight) / 2,
                    height: trackHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                      child: Stack(
                        children: [
                          // The full palette, always visible: it is the legend.
                          Positioned.fill(
                            child: DecoratedBox(decoration: BoxDecoration(gradient: DailyScoreScale.gradient())),
                          ),
                          // Everything beyond the value is washed out towards the
                          // surface colour, so the filled part reads as the value
                          // without ever changing the palette's own colours.
                          Positioned.fill(
                            child: FractionallySizedBox(
                              widthFactor: 1 - ratio,
                              alignment: rtl ? Alignment.centerLeft : Alignment.centerRight,
                              child: ColoredBox(color: colorScheme.surface.withValues(alpha: 0.78)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    top: _verticalPadding,
                    left: thumbSize / 2 + trackWidth * (rtl ? 1 - ratio : ratio) - thumbSize / 2,
                    width: thumbSize,
                    height: thumbSize,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surface,
                        border: Border.all(color: highlight, width: 3.0),
                        boxShadow: [
                          BoxShadow(
                            color: highlight.withValues(alpha: 0.35),
                            blurRadius: 8.0,
                            spreadRadius: 1.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
