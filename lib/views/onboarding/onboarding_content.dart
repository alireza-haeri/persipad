part of 'onboarding_view.dart';

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent(this.viewModel);

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          forceMaterialTransparency: true,
          actions: [
            IconButton(
              tooltip: tr("page.language.title"),
              icon: const Icon(SpIcons.globe),
              onPressed: () => LanguagesRoute(
                showBetaBanner: false,
                fromOnboarding: true,
              ).push(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: buildContents(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildContents(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children:
          [
            Container(
              margin: const EdgeInsets.only(top: 36),
              width: double.infinity,
              child: (viewModel.selectedGender?.appLogo ?? kAppLogo!).asset.image(width: 120, height: 120),
            ),
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: Text(
                tr("dialog.what_should_i_call_you.title"),
                style: TextTheme.of(context).titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Text(
                tr("dialog.what_should_i_call_you.message"),
                style: TextTheme.of(context).bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 24),
              child: buildGenderPicker(context),
            ),
            Container(
              margin: const EdgeInsets.only(top: 24),
              child: _NicknameField(viewModel: viewModel),
            ),
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: _NextButton(viewModel: viewModel),
            ),
          ].asMap().entries.map((entry) {
            return SpFadeIn.fromTop(
              delay: Durations.medium1 * entry.key,
              duration: Durations.long3,
              child: entry.value,
            );
          }).toList(),
    );
  }

  Widget buildGenderPicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('page.gender.title'), style: TextTheme.of(context).titleMedium),
        const SizedBox(height: 4),
        Text(context.tr('page.gender.description'), style: TextTheme.of(context).bodySmall),
        const SizedBox(height: 12),
        Row(
          children: GenderOption.values.map((option) {
            final selected = viewModel.selectedGender == option;
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: option == GenderOption.male ? 8 : 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => viewModel.selectGender(option),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? ColorScheme.of(context).primary : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        option.appLogo.asset.image(width: 56, height: 56),
                        const SizedBox(height: 8),
                        Text(context.tr(option.translationKey)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
