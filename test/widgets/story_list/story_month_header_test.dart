import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/path_type.dart';
import 'package:storypad/widgets/story_list/local_widgets/story_month_header.dart';

/// Translations from memory: the test only needs `context.locale` to resolve,
/// and reading `translations/*.json` through the asset bundle is not something
/// the other tests rely on either (see `flutter_test_config.dart`).
class _MemoryAssetLoader extends AssetLoader {
  const _MemoryAssetLoader()
    : super(
        linkedFileResolver: const JsonLinkedFileResolver(fileLoader: RootBundleFileLoader()),
        fileLoader: const RootBundleFileLoader(),
      );

  @override
  Future<Map<String, dynamic>> load(String fullPath, Locale locale) async => const <String, dynamic>{};
}

/// The month header is the first thing every story list draws — on the home
/// screen, in the calendar's notes, in archives — and it is drawn inside a list,
/// where the height a row gets is unbounded.
///
/// That context is the point of this test: a month chip that sizes itself to the
/// biggest constraint it is given (an `OverflowBox`, say) resolves to
/// `Size(32, infinity)` there, fails layout, and takes the *whole* scroll view
/// down with it — the app showed a home screen with only its floating buttons and
/// an empty calendar notes tab. A header that lays out in an unbounded column,
/// in both directions and both calendars, is the guard against that returning.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();
  });

  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  final story = StoryDbModel(
    id: 1,
    type: PathType.docs,
    year: 2026,
    month: 11,
    day: 15,
    hour: null,
    minute: null,
    second: null,
    starred: false,
    pinned: false,
    feeling: null,
    tags: null,
    assets: null,
    latestContent: null,
    draftContent: null,
    createdAt: DateTime(2026, 11, 15),
    updatedAt: DateTime(2026, 11, 15),
    galleryTemplateId: null,
    templateId: null,
    movedToBinAt: null,
    lastSavedDeviceId: null,
    permanentlyDeletedAt: null,
  );

  Future<void> pump(WidgetTester tester, {required TextDirection direction}) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'translations',
        assetLoader: const _MemoryAssetLoader(),
        supportedLocales: const [Locale('fa')],
        fallbackLocale: const Locale('fa'),
        child: MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: SingleChildScrollView(
                // Unbounded height, as in a real story list.
                child: Column(
                  children: [
                    StoryMonthHeader(story: story, isFirstOfRun: true, showYear: true),
                    StoryMonthHeader(story: story, isFirstOfRun: false, showYear: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The locale loads in a microtask, then the tree builds once more.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lays out in an unbounded list, in LTR and RTL', (tester) async {
    await tester.runAsync(() async {
      await pump(tester, direction: TextDirection.ltr);
      expect(tester.takeException(), isNull);
      // One header for the first story of a run, one for a continuation.
      expect(find.byType(StoryMonthHeader), findsNWidgets(2));

      await pump(tester, direction: TextDirection.rtl);
      expect(tester.takeException(), isNull);
      expect(find.byType(StoryMonthHeader), findsNWidgets(2));
    });
  });

  testWidgets('the Shamsi chip spells the month out', (tester) async {
    CalendarConfig.apply(system: CalendarSystemOption.persian);

    await tester.runAsync(() async {
      await pump(tester, direction: TextDirection.rtl);

      expect(tester.takeException(), isNull);
      // 15 Nov 2026 is 24 Aban 1405; the chip must not print "آبا".
      expect(find.text('آبان'), findsWidgets);
      expect(find.text('آبا'), findsNothing);
    });
  });
}
