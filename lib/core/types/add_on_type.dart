// ignore_for_file: constant_identifier_names

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:storypad/widgets/sp_icons.dart';

enum AddOnType {
  relax_sounds(icon: SpIcons.musicNote, weekdayColor: 4),
  map(icon: SpIcons.map, weekdayColor: 3),
  period_calendar(icon: SpIcons.waterDrop, designForFemale: true, weekdayColor: 7),
  daily_score(icon: SpIcons.gauge, weekdayColor: 2);

  final IconData icon;
  final bool designForFemale;
  final int weekdayColor;

  const AddOnType({
    required this.icon,
    required this.weekdayColor,
    this.designForFemale = false,
  });

  String get displayName {
    switch (this) {
      case AddOnType.relax_sounds:
        return tr("paywall_features.relax_sounds.title");
      case AddOnType.period_calendar:
        return tr("list_tile.period_calendar.title");
      case AddOnType.daily_score:
        return tr("list_tile.daily_score.title");
      case AddOnType.map:
        // The map's name already exists for its sidebar item and page title; a
        // second `map.title` key would be the same word twice.
        return tr('page.map.title');
    }
  }

  String get description {
    switch (this) {
      case AddOnType.relax_sounds:
        return tr('paywall_features.relax_sounds.subtitle');
      case AddOnType.period_calendar:
        return tr('list_tile.period_calendar.subtitle');
      case AddOnType.daily_score:
        return tr('list_tile.daily_score.subtitle');
      case AddOnType.map:
        return tr('list_tile.map.subtitle');
    }
  }
}
