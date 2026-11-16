// `show tr`: easy_localization re-exports intl, whose `TextDirection`/`Locale`
// would fight Material's. The locale itself comes from `Localizations.localeOf`.
import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/constants/app_constants.dart' show kIsCupertino;
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/providers/daily_score_provider.dart';
import 'package:storypad/widgets/bottom_sheets/base_bottom_sheet.dart';
import 'package:storypad/widgets/scores/sp_daily_score_bar.dart';

/// Rate one day from 0 ("terrible") to 100 ("great").
///
/// The sheet writes straight through [DailyScoreProvider] and pops — it returns
/// nothing, because there is nothing for the caller to do: the calendar and both
/// charts listen to the provider and repaint themselves.
class SpDailyScoreSheet extends BaseBottomSheet {
  const SpDailyScoreSheet({required this.date});

  /// The day being rated, as a stored (Gregorian) date. Display conversion for
  /// the header happens here, so callers never have to think about calendars.
  final DateTime date;

  @override
  bool get fullScreen => false;

  @override
  Widget build(BuildContext context, double bottomPadding) {
    return _SpDailyScoreSheetBody(date: date, bottomPadding: bottomPadding);
  }
}

class _SpDailyScoreSheetBody extends StatefulWidget {
  const _SpDailyScoreSheetBody({required this.date, required this.bottomPadding});

  final DateTime date;
  final double bottomPadding;

  @override
  State<_SpDailyScoreSheetBody> createState() => _SpDailyScoreSheetBodyState();
}

class _SpDailyScoreSheetBodyState extends State<_SpDailyScoreSheetBody> {
  late final DailyScoreProvider _provider = context.read<DailyScoreProvider>();
  late final int? _original = _provider.scoreOf(widget.date);
  late int _value = _original ?? DailyScoreScale.defaultValue;

  Future<void> _save() async {
    await _provider.setScore(widget.date, _value);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await _provider.setScore(widget.date, null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color valueColor = DailyScoreScale.colorOf(_value);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 0.0),
            child: Column(
              children: [
                Text(
                  DateFormatHelper.yMMMd(widget.date, Localizations.localeOf(context)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2.0),
                Text(
                  tr('general.score_of_day'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          // The number is the answer; it changes colour with the thumb while
          // dragging, so the "how good is 30?" question is answered before
          // saving rather than after.
          AnimatedDefaultTextStyle(
            duration: Durations.short4,
            style: theme.textTheme.displayMedium!.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: Text(
              DailyScoreScale.label(_value, Localizations.localeOf(context)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SpDailyScoreBar(
              value: _value,
              onChanged: (next) => setState(() => _value = next),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DailyScoreScale.label(DailyScoreScale.min, Localizations.localeOf(context)),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  DailyScoreScale.label(DailyScoreScale.max, Localizations.localeOf(context)),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSaveButton(context),
          ),
          // Only offered when there is something to remove: an empty "Remove" is
          // a dead control that reads as a bug.
          if (_original != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: TextButton(
                onPressed: _remove,
                child: Text(tr('button.remove_score')),
              ),
            ),
          SizedBox(height: widget.bottomPadding + 16.0),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    if (kIsCupertino) {
      return CupertinoButton.filled(
        sizeStyle: CupertinoButtonSize.medium,
        onPressed: _save,
        child: Text(tr('button.save')),
      );
    } else {
      return FilledButton(
        onPressed: _save,
        child: Text(tr('button.save')),
      );
    }
  }
}
