import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/providers/app_lock_provider.dart';
import 'package:storypad/providers/backup_provider.dart';
import 'package:storypad/providers/in_app_update_provider.dart';
import 'package:storypad/providers/nickname_provider.dart';
import 'package:storypad/providers/root_provider.dart';
import 'package:storypad/providers/tags_provider.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/providers/daily_score_provider.dart';

// global providers
class ProviderScope extends StatelessWidget {
  const ProviderScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ListenableProvider<RootProvider>(
          create: (context) => RootProvider(),
        ),
        ListenableProvider<BackupProvider>(
          create: (context) => BackupProvider(),
        ),
        ListenableProvider<TagsProvider>(
          create: (context) => TagsProvider(),
        ),
        ListenableProvider<AppLockProvider>(
          create: (context) => AppLockProvider(),
        ),
        ListenableProvider<DevicePreferencesProvider>(
          create: (context) => DevicePreferencesProvider(),
        ),
        ListenableProvider<InAppUpdateProvider>(
          create: (context) => InAppUpdateProvider(),
        ),
        ListenableProvider<NicknameProvider>(
          create: (context) => NicknameProvider(),
        ),
        // Loaded eagerly rather than lazily: the calendar's score segment can be
        // the first screen after a cold start (it is a segment of the calendar
        // sheet), and a lazily-created provider would paint an empty month first
        // and then pop the scores in.
        ListenableProvider<DailyScoreProvider>(
          lazy: false,
          create: (context) => DailyScoreProvider()..load(),
        ),
      ],
      child: child,
    );
  }
}
