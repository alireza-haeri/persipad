// `show tr`: easy_localization re-exports intl, whose `TextDirection` would
// shadow Material's and break `Directionality.of(context) == TextDirection.rtl`.
import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/views/calendar/trend/local_widgets/score_chart_card.dart';

/// The shown month's scores as a line, one point per **rated** day.
///
/// Unrated days are not plotted at all, so the line simply spans the gap between
/// two rated days instead of diving to zero — a missing day is missing
/// information, not a terrible one. The x axis keeps the month's real span
/// (day 1 … last day) so the gaps stay where they belong: a score on the 1st and
/// another on the 30th should not look like two consecutive days.
class ScoreMonthLineChart extends StatelessWidget {
  const ScoreMonthLineChart({
    super.key,
    required this.scores,
    required this.daysInMonth,
  });

  /// Rated days only: display day → score.
  final Map<int, int> scores;

  /// Length of the shown display month, so the axis spans the real month.
  final int daysInMonth;

  static const double _chartHeight = 148.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Locale locale = Localizations.localeOf(context);

    final List<({int day, int score})> points = [
      for (final entry in scores.entries) (day: entry.key, score: entry.value),
    ]..sort((a, b) => a.day - b.day);

    final double? average = points.isEmpty
        ? null
        : points.map((point) => point.score).reduce((a, b) => a + b) / points.length;

    return ScoreChartCard(
      title: tr('general.score_month_trend'),
      subtitle: average == null
          ? null
          : '${tr('general.score_average')} ${DailyScoreScale.label(average.round(), locale)}',
      child: points.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 26.0),
              child: Center(
                child: Text(
                  tr('general.score_none_yet'),
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : TweenAnimationBuilder<double>(
              // The key is the data: a new month (or a score being added) replays the
              // entrance, so the chart visibly redraws itself instead of snapping to
              // a new shape. Without it the tween would only ever run once per mount.
              key: ValueKey<String>(
                '${daysInMonth}|${points.map((point) => '${point.day}:${point.score}').join(',')}',
              ),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                return SizedBox(
                  height: _chartHeight,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ScoreLinePainter(
                      points: points,
                      daysInMonth: daysInMonth,
                      progress: progress,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                      textDirection: Directionality.of(context),
                      gridColor: colorScheme.onSurface.withValues(alpha: 0.08),
                      surfaceColor: colorScheme.surfaceContainerLow,
                      labelStyle:
                          theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant) ??
                          const TextStyle(fontSize: 10.0),
                      dayLabel: (day) => DateFormatHelper.number(day, locale),
                      scoreLabel: (score) => DailyScoreScale.label(score, locale),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ScoreLinePainter extends CustomPainter {
  _ScoreLinePainter({
    required this.points,
    required this.daysInMonth,
    required this.progress,
    required this.rtl,
    required this.textDirection,
    required this.gridColor,
    required this.surfaceColor,
    required this.labelStyle,
    required this.dayLabel,
    required this.scoreLabel,
  });

  final List<({int day, int score})> points;
  final int daysInMonth;

  /// 0 → the line lies flat on the baseline, 1 → its real values. Driven by a
  /// [TweenAnimationBuilder] in the widget, which is what makes the chart grow
  /// instead of appearing.
  final double progress;
  final bool rtl;
  final TextDirection textDirection;
  final Color gridColor;
  final Color surfaceColor;
  final TextStyle labelStyle;
  final String Function(int day) dayLabel;
  final String Function(int score) scoreLabel;

  static const double _topPadding = 12.0;
  static const double _bottomPadding = 22.0;
  static const double _labelStrip = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    // The y labels sit on the side the axis starts from: right in Persian, left
    // otherwise. A plot drawn under them would collide, so the strip is reserved.
    final Rect plot = Rect.fromLTRB(
      rtl ? 2.0 : _labelStrip,
      _topPadding,
      rtl ? size.width - _labelStrip : size.width - 2.0,
      size.height - _bottomPadding,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    // The curve rises from the baseline: every point's height is interpolated,
    // not just its opacity, which is what makes the entrance read as drawing.
    double yOf(int score) {
      final double target = plot.bottom - plot.height * DailyScoreScale.clamp(score) / DailyScoreScale.max;
      return plot.bottom + (target - plot.bottom) * progress;
    }

    double xOf(int day) {
      final double t = daysInMonth <= 1 ? 0.5 : (day - 1) / (daysInMonth - 1);
      return rtl ? plot.right - plot.width * t : plot.left + plot.width * t;
    }

    _paintGrid(canvas, plot, xOf);

    final List<Offset> offsets = [
      for (final point in points) Offset(xOf(point.day), yOf(point.score)),
    ];

    final int average = (points.map((point) => point.score).reduce((a, b) => a + b) / points.length).round();
    final Color accent = DailyScoreScale.colorOf(average);

    // Dots arrive after the line, with a small overshoot, so the eye follows the
    // curve and then lands on the values.
    final double dotScale = Curves.easeOutBack.transform(((progress - 0.45) / 0.55).clamp(0.0, 1.0).toDouble());

    if (offsets.length == 1) {
      // One rated day has no line to draw; a single dot still answers "what did
      // I score this month".
      _paintDot(canvas, offsets.first, points.first.score, dotScale);
      return;
    }

    final List<_LineSegment> segments = _monotoneSegments(offsets);

    // Everything below the curve is a wash of the month's own average colour.
    final Path fill = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final segment in segments) {
      fill.cubicTo(segment.c1.dx, segment.c1.dy, segment.c2.dx, segment.c2.dy, segment.p1.dx, segment.p1.dy);
    }
    fill
      ..lineTo(offsets.last.dx, plot.bottom)
      ..lineTo(offsets.first.dx, plot.bottom)
      ..close();

    canvas.save();
    canvas.clipRect(plot.inflate(8.0));
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.26 * progress), accent.withValues(alpha: 0.0)],
        ).createShader(plot),
    );

    // Each stretch takes the colour of the two scores it joins, so the line reads
    // as the palette the slider taught: red stretches are bad days.
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < segments.length; i++) {
      final _LineSegment segment = segments[i];
      final int midScore = ((points[i].score + points[i + 1].score) / 2).round();
      canvas.drawPath(
        Path()
          ..moveTo(segment.p0.dx, segment.p0.dy)
          ..cubicTo(segment.c1.dx, segment.c1.dy, segment.c2.dx, segment.c2.dy, segment.p1.dx, segment.p1.dy),
        stroke..color = DailyScoreScale.colorOf(midScore),
      );
    }
    canvas.restore();

    for (int i = 0; i < offsets.length; i++) {
      _paintDot(canvas, offsets[i], points[i].score, dotScale);
    }
  }

  void _paintGrid(Canvas canvas, Rect plot, double Function(int day) xOf) {
    final Paint line = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (final int score in const [0, 50, 100]) {
      final double y = plot.bottom - plot.height * score / DailyScoreScale.max;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);

      final TextPainter label = _text(scoreLabel(score));
      label.paint(
        canvas,
        Offset(
          rtl ? plot.right + 6.0 : plot.left - 6.0 - label.width,
          y - label.height / 2,
        ),
      );
    }

    // Four day ticks, evenly spread over the month. They label the axis, not the
    // data, so they appear whether or not those days were rated.
    final Set<int> ticks = {
      1,
      if (daysInMonth >= 4) (daysInMonth / 3).round(),
      if (daysInMonth >= 4) (daysInMonth * 2 / 3).round(),
      daysInMonth,
    };

    for (final int day in ticks) {
      final TextPainter label = _text(dayLabel(day));
      final double centered = xOf(day) - label.width / 2;
      // Clamp only when there is room to clamp: `num.clamp` throws if the lower
      // bound is above the upper one, which happens on very narrow plots.
      final double minX = plot.left - 4.0;
      final double maxX = plot.right + 4.0 - label.width;
      label.paint(canvas, Offset(maxX > minX ? centered.clamp(minX, maxX).toDouble() : centered, plot.bottom + 5.0));
    }
  }

  void _paintDot(Canvas canvas, Offset offset, int score, double scale) {
    if (scale <= 0) return;
    canvas.drawCircle(offset, 5.0 * scale, Paint()..color = surfaceColor);
    canvas.drawCircle(offset, 3.6 * scale, Paint()..color = DailyScoreScale.colorOf(score));
  }

  TextPainter _text(String value) {
    return TextPainter(
      text: TextSpan(text: value, style: labelStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
  }

  /// Monotone cubic (Fritsch–Carlson) tangents.
  ///
  /// Chosen over Catmull-Rom because it cannot overshoot: a spline that dips
  /// below 0 or above 100 between two real points would draw a score the user
  /// never entered.
  List<_LineSegment> _monotoneSegments(List<Offset> offsets) {
    final int count = offsets.length;
    if (count < 2) return const [];

    final List<double> widths = [
      for (int i = 0; i < count - 1; i++) offsets[i + 1].dx - offsets[i].dx,
    ];
    final List<double> slopes = [
      for (int i = 0; i < count - 1; i++) widths[i] == 0 ? 0.0 : (offsets[i + 1].dy - offsets[i].dy) / widths[i],
    ];

    final List<double> tangents = List<double>.filled(count, 0.0);
    tangents[0] = slopes.first;
    tangents[count - 1] = slopes.last;

    for (int i = 1; i < count - 1; i++) {
      if (slopes[i - 1] * slopes[i] <= 0) {
        tangents[i] = 0.0;
      } else {
        final double w1 = 2 * widths[i] + widths[i - 1];
        final double w2 = widths[i] + 2 * widths[i - 1];
        tangents[i] = (w1 + w2) / (w1 / slopes[i - 1] + w2 / slopes[i]);
      }
    }

    return [
      for (int i = 0; i < count - 1; i++)
        _LineSegment(
          p0: offsets[i],
          c1: Offset(
            offsets[i].dx + widths[i] / 3,
            offsets[i].dy + tangents[i] * widths[i] / 3,
          ),
          c2: Offset(
            offsets[i + 1].dx - widths[i] / 3,
            offsets[i + 1].dy - tangents[i + 1] * widths[i] / 3,
          ),
          p1: offsets[i + 1],
        ),
    ];
  }

  @override
  bool shouldRepaint(covariant _ScoreLinePainter oldDelegate) {
    return oldDelegate.daysInMonth != daysInMonth ||
        oldDelegate.progress != progress ||
        oldDelegate.rtl != rtl ||
        oldDelegate.gridColor != gridColor ||
        !listEquals(oldDelegate.points, points);
  }
}

class _LineSegment {
  const _LineSegment({
    required this.p0,
    required this.c1,
    required this.c2,
    required this.p1,
  });

  final Offset p0;
  final Offset c1;
  final Offset c2;
  final Offset p1;
}
