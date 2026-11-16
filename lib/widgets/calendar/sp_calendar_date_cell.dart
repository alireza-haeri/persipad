import 'package:flutter/material.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/widgets/sp_fade_in.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_tap_effect.dart';

/// A single date cell in the calendar — **the** calendar cell, used by every
/// segment, so the grid looks the same wherever the user meets it.
///
/// What it can show, in the order they were added:
///
///  * the day number (always, in one form or another),
///  * the day's feeling emoji, or a check when the day has stories but no feeling,
///  * the day's score as a tint of the whole cell (its ring on the day badge too),
///  * selection and "today".
///
/// A feeling used to *replace* the day number, which turned the grid into a wall of
/// emoji with no reference points. Now the emoji keeps the middle of the cell and
/// the number sits under it in a small circle (D-033).
class SpCalendarDateCell extends StatelessWidget {
  const SpCalendarDateCell({
    super.key,
    required this.feelingVisibleIndexNotifier,
    required this.date,
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedDay,
    required this.feelings,
    required this.isDisplayMonth,
    required this.onTap,
    this.score,
    this.onLongPress,
  });

  final ValueNotifier<int> feelingVisibleIndexNotifier;
  final DateTime date;
  final int selectedYear;
  final int selectedMonth;
  final int? selectedDay;
  final List<String>? feelings;
  final bool isDisplayMonth;
  final VoidCallback? onTap;

  /// The day's score (0–100) when the daily-score add-on is on and the day was
  /// rated. Null means "not rated" — never zero.
  final int? score;

  /// Long press, used by the calendar to open the score sheet: tapping a day
  /// already means "show that day's stories", so rating must not steal the tap.
  final VoidCallback? onLongPress;

  bool get hasFeelings =>
      isDisplayMonth && feelings != null && feelings!.any((feeling) => feeling != 'exist_but_not_set');

  bool get hasStoriesButNoFeelings =>
      isDisplayMonth && feelings != null && feelings!.every((feeling) => feeling == 'exist_but_not_set');

  @override
  Widget build(BuildContext context) {
    return SpTapEffect(
      effects: [.scaleDown, .touchableOpacity],
      scaleActive: 0.9,
      onTap: onTap,
      onLongPressed: onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isToday)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            // A stable key even when there is no tint: swapping the key on the way
            // from "unrated" to "rated" would rebuild the box and snap the colour in
            // instead of fading it.
            key: const ValueKey('calendar-cell-background'),
            duration: Durations.medium2,
            curve: Curves.easeOut,
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: 56),
            margin: const EdgeInsets.all(2.0),
            decoration: score == null
                ? null
                : BoxDecoration(
                    color: DailyScoreScale.colorOf(score!).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
            child: _buildDateContent(context),
          ),
        ],
      ),
    );
  }

  bool get isSelected {
    if (selectedDay == null) return false;

    // Compared in the display calendar: the grid pages Shamsi months, where the
    // stored Gregorian day/month of a cell are different numbers.
    return CalendarDisplay.dayOf(date) == selectedDay &&
        CalendarDisplay.monthOf(date) == selectedMonth &&
        CalendarDisplay.yearOf(date) == selectedYear;
  }

  bool get isToday {
    final now = DateTime.now();
    return date == DateTime(now.year, now.month, now.day);
  }

  Widget _buildDateContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? backgroundColor = isSelected ? colorScheme.primary.withValues(alpha: 0.1) : null;

    // Weekends are user-defined (Friday for Iranian users, Saturday+Sunday for
    // most of Europe), so the highlight asks the preferences instead of
    // assuming a pair of days. Selection still wins over the weekend tint.
    late Color foregroundColor;
    if (isSelected) {
      foregroundColor = colorScheme.primary;
    } else if (CalendarConfig.isWeekend(date)) {
      foregroundColor = colorScheme.error;
    } else {
      foregroundColor = colorScheme.onSurface;
    }

    if (!isDisplayMonth) {
      foregroundColor = foregroundColor.withValues(alpha: 0.5);
    }

    if (hasFeelings || hasStoriesButNoFeelings) {
      // The emoji (or check) keeps the middle of the cell and the day number
      // moves into a small circle underneath it, so a month of feelings is still
      // a calendar. The number is no longer sacrificed to the emoji.
      return Container(
        key: ValueKey(hasFeelings ? 'has-stories-has-feeling' : 'has-stories-no-feeling'),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Padding(
                // Room for the badge, which overlaps the emoji's bottom edge.
                padding: const EdgeInsets.only(bottom: 12.0),
                child: FittedBox(
                  child: hasFeelings
                      ? buildFeelings(
                          feelings: feelings!.where((feeling) => feeling != 'exist_but_not_set').toList(),
                        )
                      : Icon(SpIcons.check, color: foregroundColor),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildDayBadge(context, foregroundColor: foregroundColor),
            ),
          ],
        ),
      );
    } else {
      return AnimatedContainer(
        key: const ValueKey('no-stories'),
        duration: Durations.medium1,
        curve: Curves.ease,
        margin: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            DateFormatHelper.d(date, Localizations.localeOf(context)),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: foregroundColor,
            ),
          ),
        ),
      );
    }
  }

  /// The day number of a day that already has an emoji or a check.
  ///
  /// Small and circular so it reads as a stamp rather than competing with the
  /// emoji, and its ring is the day's score colour when the day was rated — a
  /// month whose scores are good is green even when every cell has a face on it.
  Widget _buildDayBadge(BuildContext context, {required Color foregroundColor}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int? value = score;

    return Container(
      width: 19.0,
      height: 19.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? colorScheme.primary : colorScheme.surface.withValues(alpha: 0.92),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : value == null
              ? foregroundColor.withValues(alpha: 0.3)
              : DailyScoreScale.colorOf(value),
          width: value == null && !isSelected ? 1.0 : 1.6,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Text(
            DateFormatHelper.d(date, Localizations.localeOf(context)),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isSelected ? colorScheme.onPrimary : foregroundColor,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFeelings({
    required List<String> feelings,
  }) {
    if (feelings.length == 1) {
      return Text(
        feelings.first,
        strutStyle: const StrutStyle(
          fontSize: 56,
          height: 1.0,
        ),
        style: const TextStyle(
          fontSize: 56,
          height: 1.0,
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: feelingVisibleIndexNotifier,
      builder: (context, visibleIndex, child) {
        int index = visibleIndex % feelings.length;
        final emoji = feelings[index];

        return KeyedSubtree(
          key: ValueKey(emoji),
          child: SpFadeIn.flip(
            duration: const Duration(seconds: 1),
            child: Text(
              emoji,
              strutStyle: const StrutStyle(
                fontSize: 56,
                height: 1.0,
              ),
              style: const TextStyle(
                fontSize: 100,
                height: 1.0,
              ),
            ),
          ),
        );
      },
    );
  }
}
