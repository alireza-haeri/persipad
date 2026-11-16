import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/widgets/dialogs/sp_date_picker_dialog.dart';
import 'package:storypad/widgets/sp_single_state_widget.dart';

class DatePickerService {
  final BuildContext context;
  final DateTime currentDate;

  DatePickerService({
    required this.context,
    required this.currentDate,
  });

  Future<DateTime?> show() async {
    DateTime? date;
    final bool hasMousePointer = RendererBinding.instance.mouseTracker.mouseIsConnected;

    final firstDate = DateTime(1900);
    final lastDate = DateTime.now().add(const Duration(days: 100 * 365));

    if (CalendarConfig.isPersian) {
      // Flutter's pickers can only draw a Gregorian grid (they take it from
      // MaterialLocalizations/DateUtils), so with the Shamsi calendar the user
      // would be choosing from a Gregorian month while all dates around it read
      // Shamsi. The custom dialog draws the display calendar and still returns
      // a Gregorian DateTime — nothing is ever stored differently.
      date = await SpDatePickerDialog.show(
        context: context,
        initialDate: currentDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );
    } else if (kIsCupertino && !hasMousePointer) {
      date = await _showCupertinoDatePicker();
    } else {
      date = await showDatePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: currentDate,
      );
    }

    if (date == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      currentDate.hour,
      currentDate.minute,
      currentDate.second,
    );
  }

  Future<DateTime?> _showCupertinoDatePicker() async {
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return SpSingleStateWidget<DateTime?>(
          initialValue: currentDate,
          builder: (context, notifier) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
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
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: currentDate,
                        onDateTimeChanged: (date) => notifier.value = date,
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

  Widget _buildCupertinoNavigator(BuildContext context, CmValueNotifier<DateTime?> notifier) {
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
