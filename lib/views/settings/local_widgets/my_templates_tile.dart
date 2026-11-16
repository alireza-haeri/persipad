import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/views/templates/templates_view.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

class MyTemplatesTile extends StatelessWidget {
  const MyTemplatesTile({
    super.key,
    required this.weekday,
  });

  final int weekday;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SpSettingIconBadge(weekday: weekday, icon: SpIcons.book),
      title: Text(context.tr('general.my_templates')),
      onTap: () => const TemplatesRoute(onlyMyTemplates: true).push(context),
    );
  }
}
