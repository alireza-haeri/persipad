import 'package:easy_localization/easy_localization.dart' show AssetLoader, EasyLocalization;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:provider/provider.dart';
import 'package:storypad/core/objects/device_preferences_object.dart';
import 'package:storypad/core/objects/reminder_object.dart';
import 'package:storypad/core/types/reminder_type.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/views/reminders/edit_custom_reminder/edit_custom_reminder_view.dart';
import 'package:storypad/views/reminders/edit_custom_reminder/edit_custom_reminder_view_model.dart';

class _MemoryAssetLoader extends AssetLoader {
  const _MemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => const {};
}

class _FakePreferences extends ChangeNotifier implements DevicePreferencesProvider {
  @override
  DevicePreferencesObject get preferences => DevicePreferencesObject.initial();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();
  });

  for (final code in ['en', 'fa']) {
    for (final isNew in [true, false]) {
      testWidgets('opens ${isNew ? 'new' : 'existing'} reminder with $code locale', (tester) async {
        final reminder = ReminderObject(id: 12, type: ReminderType.custom, message: isNew ? null : 'Reminder');
        await tester.pumpWidget(
          EasyLocalization(
            path: 'translations',
            assetLoader: const _MemoryAssetLoader(),
            saveLocale: false,
            supportedLocales: [Locale(code)],
            fallbackLocale: Locale(code),
            child: ChangeNotifierProvider<DevicePreferencesProvider>.value(
              value: _FakePreferences(),
              child: MaterialApp(home: EditCustomReminderView(reminder: reminder, isNew: isNew)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(EditCustomReminderView), findsOneWidget);
        final context = tester.element(find.byType(Form));
        expect(context.read<EditCustomReminderViewModel>().languageCode, code);
      });
    }
  }
}
