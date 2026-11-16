part of "../day_colors_view.dart";

class _DayColorTile extends StatelessWidget {
  const _DayColorTile({
    required this.weekday,
  });

  final int weekday;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DevicePreferencesProvider>(context);
    final String? currentName = provider.preferences.colorByDay?[weekday];
    final bool customized = currentName != null;

    return SpAdaptivePopUpButton(
      floatingBuilder: (close, openAbove) {
        return SpColorPicker(
          isDarkMode: AppTheme.isDarkMode(context),
          position: openAbove ? SpColorPickerPosition.bottom : SpColorPickerPosition.top,
          currentColor: _highlightColor(context, currentName),
          level: SpColorPickerLevel.one,
          onPickedColor: (color) async {
            await close();
            if (!context.mounted) return;

            final name = _nameFromColor(color);
            if (name == null) return;

            if (name == currentName) {
              provider.resetColorForDay(weekday);
            } else {
              provider.setColorForDay(weekday, name);
            }
          },
        );
      },
      builder: (void Function() open) {
        return ListTile(
          contentPadding: const EdgeInsets.only(left: 16, right: 8),
          title: Text(_weekdayLabel(context)),
          subtitle: Text(customized ? tr("general.custom") : tr("general.default")),
          leading: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: ColorFromDayService(context: context).get(weekday),
              ),
            ),
          ),
          trailing: customized
              ? IconButton(
                  tooltip: tr("button.reset"),
                  icon: const Icon(SpIcons.refresh),
                  onPressed: () => provider.resetColorForDay(weekday),
                )
              : null,
          onTap: () => open(),
        );
      },
    );
  }

  String _weekdayLabel(BuildContext context) {
    final localeName = context.locale.toLanguageTag();
    return DateFormat.EEEE(localeName).format(DateTime(2024, 1, weekday));
  }

  Color? _highlightColor(BuildContext context, String? currentName) {
    if (currentName == null) return null;
    if (currentName == kBlackWhiteColorName) {
      return Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    }
    return kMaterialColorsByName[currentName]?[500];
  }

  String? _nameFromColor(Color color) {
    // ignore: deprecated_member_use
    if (color.value == 0xFF000000 || color.value == 0xFFFFFFFF) return kBlackWhiteColorName;

    for (final entry in kMaterialColorsByName.entries) {
      // ignore: deprecated_member_use
      if (entry.value == color || entry.value.value == color.value) return entry.key;
    }
    return null;
  }
}
