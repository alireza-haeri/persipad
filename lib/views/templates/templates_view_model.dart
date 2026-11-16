import 'package:flutter/material.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/storages/previously_visited_template_tab.dart';
import 'templates_view.dart';

class TemplatesViewModel extends ChangeNotifier with DisposeAwareMixin {
  final TemplatesRoute params;

  late int initialTabIndex;

  TemplatesViewModel({
    required this.params,
    required BuildContext context,
  }) {
    final int? currentIndex = PreviouslyVisitedTemplateTabIndexStorage.appInstance.currentIndex;
    initialTabIndex = currentIndex ?? 1;
  }

  void setCurrentIndex(int index) {
    PreviouslyVisitedTemplateTabIndexStorage.appInstance.write(index);
  }
}
