import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum CalendarSegmentId {
  mood,
  period,
  score;

  String translatedName(BuildContext context) {
    switch (this) {
      case CalendarSegmentId.mood:
        return tr('general.mood');
      case CalendarSegmentId.period:
        return tr('list_tile.period_calendar.title');
      case CalendarSegmentId.score:
        return tr('general.score');
    }
  }
}
