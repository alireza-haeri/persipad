import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/helpers/date_format_helper.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_single_state_widget.dart';

class MonthPickerResult {
  final int month;
  final int year;

  MonthPickerResult({
    required this.month,
    required this.year,
  });
}

class MonthPickerService {
  final BuildContext context;
  final int month;
  final int year;

  /// When set, the picker scrolls are clamped so users cannot navigate
  /// outside the range of months that actually have story entries.
  final DateTime? minimumDate;
  final DateTime? maximumDate;

  MonthPickerService({
    required this.context,
    required this.month,
    required this.year,
    this.minimumDate,
    this.maximumDate,
  });

  MonthPickerResult get initialMonth => MonthPickerResult(month: month, year: year);

  Future<MonthPickerResult?> showPicker() async {
    if (CalendarDisplay.isPersian) return _showDisplayCalendarPicker();
    if (kIsCupertino) {
      return _showCupertinoTimePicker();
    } else {
      return _showMaterialTimePicker();
    }
  }

  /// Month/year picker for the Shamsi calendar.
  ///
  /// `CupertinoDatePicker(mode: monthYear)` draws Gregorian month names in the
  /// device language and offers no way to feed it Jalali months, so this lists the
  /// twelve display months itself next to a year stepper. The returned
  /// (year, month) are display values, exactly like the picker's input.
  Future<MonthPickerResult?> _showDisplayCalendarPicker() {
    return showModalBottomSheet<MonthPickerResult>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (context) {
        var current = initialMonth;

        return StatefulBuilder(
          builder: (context, setState) {
            void select({int? year, int? month}) {
              setState(() {
                current = MonthPickerResult(year: year ?? current.year, month: month ?? current.month);
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: null,
                          onPressed: () => select(year: current.year - 1),
                          icon: const Icon(SpIcons.keyboardLeft),
                        ),
                        Expanded(
                          child: Text(
                            DateFormatHelper.number(current.year, context.locale),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: null,
                          onPressed: () => select(year: current.year + 1),
                          icon: const Icon(SpIcons.keyboardRight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var month = 1; month <= 12; month++)
                          ChoiceChip(
                            label: Text(DateFormatHelper.monthName(month, context.locale)),
                            selected: current.month == month,
                            onSelected: (_) => select(month: month),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    FilledButton(
                      child: Text(tr("button.done")),
                      onPressed: () => Navigator.pop(context, current),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<MonthPickerResult?> _showMaterialTimePicker() async {
    return showModalBottomSheet<MonthPickerResult>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (context) {
        return SpSingleStateWidget<MonthPickerResult?>(
          initialValue: initialMonth,
          builder: (context, notifier) {
            return Column(
              mainAxisSize: .min,
              children: [
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    initialDateTime: DateTime(year, month),
                    minimumDate: minimumDate,
                    maximumDate: maximumDate,
                    mode: CupertinoDatePickerMode.monthYear,
                    selectionOverlayBuilder: (context, {required int columnCount, required int selectedIndex}) {
                      return Container(
                        margin: EdgeInsets.only(right: selectedIndex == columnCount - 1 ? 0.0 : 8.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      );
                    },
                    onDateTimeChanged: (DateTime value) {
                      notifier.value = MonthPickerResult(
                        month: value.month,
                        year: value.year,
                      );
                    },
                  ),
                ),
                FilledButton(
                  child: Text(tr("button.done")),
                  onPressed: () => Navigator.pop(context, notifier.value),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            );
          },
        );
      },
    );
  }

  Future<MonthPickerResult?> _showCupertinoTimePicker() {
    return showCupertinoModalPopup<MonthPickerResult>(
      context: context,
      builder: (BuildContext context) {
        return SpSingleStateWidget<MonthPickerResult?>(
          initialValue: initialMonth,
          builder: (context, notifier) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16.0,
                left: MediaQuery.of(context).padding.left,
                right: MediaQuery.of(context).padding.right,
              ),
              margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCupertinoNavigator(context, notifier),
                    SizedBox(
                      height: 216,
                      child: CupertinoDatePicker(
                        initialDateTime: DateTime(year, month),
                        minimumDate: minimumDate,
                        maximumDate: maximumDate,
                        mode: CupertinoDatePickerMode.monthYear,
                        onDateTimeChanged: (DateTime value) {
                          notifier.value = MonthPickerResult(
                            month: value.month,
                            year: value.year,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCupertinoNavigator(BuildContext context, CmValueNotifier<MonthPickerResult?> notifier) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(tr("button.cancel")),
        ),
        CupertinoButton(
          child: Text(tr("button.done")),
          onPressed: () => Navigator.pop(context, notifier.value),
        ),
      ],
    );
  }
}
