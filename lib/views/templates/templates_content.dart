part of 'templates_view.dart';

class _TemplatesContent extends StatelessWidget {
  const _TemplatesContent(this.viewModel);

  final TemplatesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.params.viewingArchives) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr('general.path_type.archives')),
        ),
        body: TemplatesTab(params: viewModel.params),
      );
    }

    if (viewModel.params.onlyMyTemplates) {
      return TemplatesTab(params: viewModel.params);
    }

    return DefaultTabController(
      length: 2,
      initialIndex: viewModel.initialTabIndex,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: buildAppBar(context),
            body: buildBody(context),
          );
        },
      ),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        viewModel.params.pickMode ? tr("button.choose_template") : tr("general.templates"),
      ),
      bottom: TabBar(
        onTap: (index) => viewModel.setCurrentIndex(index),
        tabs: [
          Tab(text: tr('general.my_templates')),
          Tab(text: tr('general.gallery')),
        ],
      ),
    );
  }

  Widget buildBody(BuildContext context) {
    return TabBarView(
      children: [
        TemplatesTab(params: viewModel.params),
        GalleryTab(params: viewModel.params),
      ],
    );
  }
}
