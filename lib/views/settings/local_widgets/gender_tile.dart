import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/types/gender_option.dart';
import 'package:storypad/providers/gender_provider.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

class GenderTile extends StatelessWidget {
  const GenderTile({super.key, required this.weekday});

  final int weekday;

  @override
  Widget build(BuildContext context) {
    return Consumer<GenderProvider>(
      builder: (context, provider, child) {
        return ListTile(
          leading: SpSettingIconBadge(weekday: weekday, icon: SpIcons.person),
          title: Text(context.tr('page.gender.title')),
          subtitle: Text(
            provider.gender == null
                ? context.tr('page.gender.description')
                : context.tr(provider.gender!.translationKey),
          ),
          onTap: () => _showPicker(context, provider.gender),
        );
      },
    );
  }

  Future<void> _showPicker(BuildContext context, GenderOption? selected) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
                child: Text(context.tr('page.gender.title'), style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final option in GenderOption.values)
                ListTile(
                  leading: option.appLogo.asset.image(width: 36, height: 36),
                  title: Text(context.tr(option.translationKey)),
                  trailing: selected == option ? const Icon(SpIcons.check) : null,
                  onTap: () async {
                    await sheetContext.read<GenderProvider>().setGender(option);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
