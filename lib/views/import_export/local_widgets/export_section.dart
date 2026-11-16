part of '../import_export_view.dart';

class _ExportSection extends StatefulWidget {
  const _ExportSection({
    required this.viewModel,
  });

  final ImportExportViewModel viewModel;

  @override
  State<_ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends State<_ExportSection> {
  late AppExportOption selectedOption = widget.viewModel.params.initialExportOption ?? .storyPadJson;

  @override
  Widget build(BuildContext context) {
    return RadioGroup(
      groupValue: selectedOption,
      onChanged: (AppExportOption? value) {
        if (value != null) {
          setState(() {
            selectedOption = value;
          });
        }
      },
      child: Column(
        children: [
          buildExportHeader(context),
          RadioListTile(
            secondary: const Icon(SpIcons.importOffline),
            title: Text(tr('list_tile.export_storypad_json.title')),
            subtitle: Text(tr('list_tile.export_storypad_json.subtitle')),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            value: AppExportOption.storyPadJson,
          ),
          RadioListTile(
            secondary: const Icon(SpIcons.text),
            title: Text(tr('list_tile.export_txt.title')),
            subtitle: Text(tr('list_tile.export_txt.subtitle')),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            value: AppExportOption.text,
          ),
          RadioListTile(
            secondary: const Icon(SpIcons.table),
            title: Text(tr('list_tile.export_csv.title')),
            subtitle: Text(tr('list_tile.export_csv.subtitle')),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            value: AppExportOption.csv,
          ),
          RadioListTile(
            secondary: const Icon(SpIcons.markdown),
            title: Text(tr('list_tile.export_markdown.title')),
            subtitle: Text(tr('list_tile.export_markdown.subtitle')),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            value: AppExportOption.markdown,
          ),
          Container(
            width: double.infinity,
            margin: MediaQuery.paddingOf(
              context,
            ).copyWith(top: 0.0, bottom: 0).add(const EdgeInsets.symmetric(horizontal: 16.0)),
            child: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: widget.viewModel.storyCount == null || widget.viewModel.storyCount == 0
                      ? null
                      : () => widget.viewModel.export(context, selectedOption),
                  child: Text(
                    [
                      tr('button.export'),
                      if (selectedOption == AppExportOption.markdown) '(.tar.gz)',
                    ].join(' '),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32.0),
          Container(
            width: double.infinity,
            margin: MediaQuery.paddingOf(
              context,
            ).copyWith(top: 0.0, bottom: 0).add(const EdgeInsets.symmetric(horizontal: 16.0)),
            child: TextButton.icon(
              icon: const Icon(SpIcons.photo),
              label: Text(tr('button.export_assets')),
              onPressed: () => const ExportAssetsRoute().push(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildExportHeader(BuildContext context) {
    return SpSectionTitle(
      title: tr('general.export'),
      trailing: SpTapEffect(
        onTap: () async {
          final result = await SearchFilterRoute(
            resetTune: widget.viewModel.initialExportFilter,
            initialTune: widget.viewModel.exportFilter,
            filterTagModifiable: true,
            multiSelectYear: true,
            submitButtonLabel: tr('button.select'),
          ).push(context);

          if (result is SearchFilterObject) {
            widget.viewModel.setExportFilter(result);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: .center,
          mainAxisAlignment: .center,
          spacing: 8.0,
          children: [
            Text(
              [
                plural('plural.entry', widget.viewModel.storyCount ?? 0),
                if (!widget.viewModel.filtered) '(${tr('general.all')})',
              ].join(' '),
            ),
            const Icon(SpIcons.tune),
          ],
        ),
      ),
    );
  }
}
