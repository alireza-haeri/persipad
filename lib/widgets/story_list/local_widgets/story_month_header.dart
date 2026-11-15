import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/widgets/story_list/sp_story_tile.dart';

class StoryMonthHeader extends StatelessWidget {
  const StoryMonthHeader({
    super.key,
    required this.isFirstOfRun,
    required this.story,
    required this.showYear,
  });

  final bool isFirstOfRun;
  final StoryDbModel story;
  final bool showYear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 0.0, top: isFirstOfRun ? 8.0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 16.0),
          _MonthChip(story: story),
          if (showYear) ...[
            const SizedBox(width: 7.0),
            Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorScheme.of(context).onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 7.0),
            Text(
              // Display calendar: 1404 in Shamsi mode, 2025 in Gregorian.
              DateFormatHelper.number(CalendarDisplay.yearOf(story.displayPathDate), context.locale),
              style: TextTheme.of(
                context,
              ).labelSmall?.copyWith(color: ColorScheme.of(context).onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.story,
  });

  final StoryDbModel story;

  @override
  Widget build(BuildContext context) {
    // The month in full, never abbreviated: Persian months have no short form
    // ("آبا" is a stem of آبان, آذر and اردیبهشت alike). The box stays one
    // monogram wide so the timeline rail keeps running through its centre, and
    // the label is allowed to grow symmetrically around that centre instead of
    // being shrunk into illegibility.
    final String label = DateFormatHelper.monthName(
      CalendarDisplay.monthOf(story.displayPathDate),
      context.locale,
    );

    return SizedBox(
      width: SpStoryTile.monogramSize,
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: 140.0,
        child: CustomPaint(
          painter: _MonthChipBoxPainter(
            fillColor: Theme.of(context).colorScheme.surface,
            borderRadius: 8.0,
            borderWidth: 1,
            borderColor: Theme.of(context).dividerColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextTheme.of(context).labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthChipBoxPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

  _MonthChipBoxPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    double extraPadding = 4;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -extraPadding,
        0,
        size.width + extraPadding * 2,
        size.height,
      ),
      Radius.circular(borderRadius),
    );

    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
