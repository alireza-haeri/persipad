# Architecture map

Canonical source: the project's own `README.md` and `CONTRIBUTING.md`. This file is
the practical cheat sheet for day-to-day work. Numbers refreshed on 2026-11-16
(version `2.34.0+834`, Session 10).

## Basics

| Item | Value |
|---|---|
| Framework | Flutter **3.50.0** / Dart **3.14.0** (`.tool-versions`; `pubspec.yaml` declares `^3.11.0`) |
| App version | `2.34.0+834` |
| Dart files | ~1013 across `lib/` and `packages/` (excluding `build/`) |
| Tests | 110 files in `test/` + 57 in `packages/storypad_editor/test/` |
| Database | ObjectBox (`6.0.0-preview.6`; legacy SQLite adapter still present) |
| State | Provider + ChangeNotifier, three levels: Global / View / Widget |
| Pattern | MVVM across 3–4 files: `Model` / `View` / `ViewContent` / `ViewModel` |
| i18n | `easy_localization`, **21** files in `translations/` (628 keys each, `fa.json` added) |
| Codegen | `build_runner` → `json_serializable`, `copy_with_extension`, `objectbox_generator`, `flutter_gen` |

## Entry points and boot

```
lib/main.dart              → main() → App
lib/main_community.dart    → public flavor (the only one with public Firebase config)
lib/main_storypad.dart     → private flavor (gitignored, not needed)
bin/dev --community        → run command
```

`main.dart`: `SpSplashScreenWrapper` → `_initializeApp`, which calls these
initializers in order (add new ones here):

`Firebase → Crashlytics → RemoteConfig → EasyLocalization → Constants →
Database → AppLock → BackupRepository → Theme → LegacyStoryPad → Onboarding →
edge-to-edge → (Android) PhotoPicker → CloudStorage → Licenses`

Then `runApp(ProviderScope(child: App()))`.

## Global providers

`lib/provider_scope.dart` — full list:

`RootProvider` (navigation + sidebar), `BackupProvider`, `TagsProvider`,
`AppLockProvider`, `DevicePreferencesProvider`, `InAppUpdateProvider`,
`InAppPurchaseProvider`, `NicknameProvider`, `RelaxSoundsProvider` (lazy),
`DailyScoreProvider` (eager `lazy: false` — preloaded for the calendar).

> A new global provider is registered here. A screen-scoped provider is a
> `ChangeNotifierProvider` inside that screen's `XView`, not here.

## Navigation

- `lib/views/root/` — `RootView` + `RootContent` + `RootSideBar`.
- Every screen has an `XRoute extends BaseRoute`, usable from outside its folder.
- **Rule:** navigation from the sidebar always uses `RootProvider.navigate(route)`,
  never a raw `Navigator.push` (otherwise the sidebar selection desyncs).
- `BaseRoute.routeName != null` → `MaterialPageRoute` via `RootViewModel.generateRoute`.
  `routeName == null` → custom `buildRoute()` (sheets, custom transitions).
- `SpNestedNavigation` provides nested tabs (e.g. inside a tag screen).

## Data layer

```
lib/core/databases/
  adapters/objectbox/*.dart   ← boxes (StoriesBox, TagsBox, EventsBox, ...)
  adapters/sqlite/            ← legacy / migration path
  models/*_db_model.dart      ← models, each exposing a static `db`
  legacy/                     ← migration from old app versions
lib/core/storages/            ← lightweight SharedPreferences-backed state
                                (theme, onboarded, badges, ...)
```

Core models: `StoryDbModel` (year/month/day, `latestContent`, `draftContent`, tags,
assets, `pinned`, `starred`), `StoryContentDbModel` + `StoryPageDbModel`
(multi-page entries), `EventDbModel` (events such as `period`), `TagDbModel`,
`TemplateDbModel`, `AssetDbModel`, `PlaceDbModel`, `PreferenceDbModel`.

- Access pattern: `await StoryDbModel.db.where(...)`. Never touch a box from a view.
- Schema change → `objectbox-model.json` changes and `bin/build_runner --delete` is
  required. **Never change an ObjectBox model without a recorded decision.**

## Services (`lib/core/services/`)

The ones that matter most for us:

- `backups/` — `backup_cloud_service.dart` (interface) plus implementations:
  `google_drive_cloud_service`, `google_drive_linux_cloud_service` (Linux takes a
  separate path!), `dropbox_cloud_service`, `icloud_cloud_service`,
  `nextcloud_cloud_service` (WebDAV), and `sync_steps/`.
- `cloud_storage/adaptors/` — ObjectBox/file adaptors for assets.
- `notifications/`, `audio_player_service`, `voice_recorder_service` → audio and reminders.
- `quill/`, `export/`, `markdown_*`, `story_plain_text_exporter` → editor and export.
- `analytics/`, `error_reporting/`, `remote_config/` → all built via
  `Base*Adaptor.create()` and resolve to no-op adaptors on Linux.
- `platform_capabilities.dart` → **our addition.** Pure matrix of what can work where
  (cloud sync per service, per platform). Unit-tested; UI asks it before offering a
  feature. Add a new platform-dependent capability here, not with scattered `if (Platform...)`.
- `pro_entitlement_service.dart` → **our addition.** The single Pro/upsell policy
  (`unlockAll`, `showUpsell`). `InAppPurchaseProvider.isProUser` delegates to it, which is
  why ~30 feature gates all open together.

## Widgets

- Prefix **`Sp`** for project-wide widgets (`SpFilledButton`, `SpFloatingActionButton`, `SpAppBar`, ...).
- `lib/widgets/base_view/base_route.dart` — route base class.
- `lib/widgets/rich_editor/` — the editor UI, backed by the local package
  `packages/storypad_editor` (forked Quill + markdown/embed layer).
- `packages/adaptive_dialog` — iOS/Android adaptive dialogs.

## Screen map (`lib/views/`)

| Folder | Role | Files |
|---|---|---|
| `home/` | main timeline + years | 27 |
| `stories/` | create/edit/show/changes for an entry | 29 |
| `onboarding/`, `settings/`, `templates/` | core flows | 24–26 |
| `backup_services/`, `import_export/` | backup & portability | 17 + 10 |
| `calendar/`, `search/`, `tags/`, `library/`, `stats/`, `throwback/`, `map/` | tools | 3–12 |
| `paywall/`, `relax_sounds/`, `reminders/`, `app_locks/` | Pro / security features | 8–12 |

32 screen folders in total.

## Tests

- `test/` mirrors `lib/core` (models, services, adapters, repositories).
- The editor package has its own suite: `packages/storypad_editor/test/`.
- Follow the existing conventions; a new test goes into the matching topical folder.

## Fork additions & key subsystems (Sessions 2–10)

Quick map of everything we added or rewired on top of StoryPad `v2.34.0`:

- **Linux desktop & entitlements:**
  - `lib/core/services/pro_entitlement_service.dart` (`unlockAll` switch opening ~30 Pro gates; `showUpsell`).
  - `lib/core/services/platform_capabilities.dart` (capability matrix for Firebase, sync backends, etc.).
  - `lib/core/services/backups/google_drive_auth_strategy.dart` + `google_desktop_oauth_service.dart` + `google_drive_linux_cloud_service.dart` (loopback PKCE OAuth2 on Linux; `bin/setup_sync`).
  - Desktop media picking in `AppFilePickerService` via `file_picker`.
- **Persian (fa), bundled font & RTL:**
  - `translations/fa.json` + all 21 locales kept in exact 628-key parity (`unused_translations_test.dart`).
  - `assets/fonts/Vazirmatn-*.ttf` + `OFL.txt` + `kScriptFontFamilyFallback` in `lib/core/constants/app_constants.dart`.
  - RTL helpers: `SpIcons.previous(context)` / `SpIcons.next(context)`, `AppTheme.rtl(context)`, `RootPagesMediaQuery`, full Persian month names (never abbreviated).
- **Shamsi (Solar Hijri) display calendar (`D-024`…`D-029`):**
  - Storage & ObjectBox columns stay **Gregorian**. Conversion happens only at display/query boundaries.
  - `lib/core/services/calendar/` (`persian_calendar.dart`, `calendar_display.dart`, `calendar_config.dart`, `weekday_name_service.dart`), `DateFormatHelper`, `SpDatePickerDialog`, `DateRangeFilterObject`, `SearchFilterObject.encode`, and `date_range`/`date_ranges` filters on `StoriesBox` & `EventsBox`.
  - User-defined `firstDayOfWeek`, `weekendDays`, and `calendarSystem` (`DevicePreferencesObject`).
- **Daily Score add-on, unified calendar & add-on controls (`D-031`…`D-037`):**
  - `lib/core/services/scores/daily_score_scale.dart` (HSV red→orange→green scale, explicit `gradient(rtl:)`), `DailyScoreProvider` (`yyyy-MM-dd` Gregorian `MapStorage`), `lib/widgets/scores/` (`SpDailyScoreBar`, `SpDailyScoreSheet`, `SpScoreCallout`), `lib/views/calendar/trend/` (`ScoreTrendView` + animated hand-painted charts).
  - Unified `SpCalendarDateCell`: mood emoji/check + circled day number + score background tint + long-press rating (`D-033`), animated row entrance & selection (`D-037`).
  - `AddOnType` (`relax_sounds`, `map`, `period_calendar`, `daily_score`) and configurable `SidebarItemId` / `sidebarOrder` (`lib/core/types/`).
- **Android toolchain & local/CI APK (`D-038`…`D-040`):**
  - `android/gradle/wrapper/gradle-wrapper.properties` (Gradle `9.3.1`), `android/settings.gradle.kts` (AGP `9.1.1`, Kotlin `2.2.20`, FlutterFire plugins).
  - `android/build.gradle.kts` (`notelyNdkVersion=none` → `flutter.installedNdkVersions` bypass for `forceNdkDownload`; `LibraryExtension.compileSdk >= 36` floor; `notelyCompileSdkMinor` propagation) and `android/app/build.gradle.kts` (`compileSdk`/`compileSdkMinor`, `ndkVersion`, `manifestPlaceholders`, `compilerOptions.jvmTarget`).
  - `.github/workflows/linux.yml` (`Scope` via `bin/changed_tests` + `Analyze` + sharded `Test` + `[build]`), `android.yml` (`[apk]` pre-releases), `codegen.yml` (`[codegen]`), plus `bin/dev`, `bin/setup_linux`, `bin/build_apk`, `bin/android_doctor`, `bin/ci`.

## Sensitive areas (think three times before touching)

1. `lib/core/databases/models/*` + `objectbox.g.dart` → real user-data migrations (requires `[codegen]` if schema/`@CopyWith` classes change).
2. `lib/core/initializers/` + `lib/main.dart` → boot order breaks everything.
3. `lib/core/services/backups/*` → risk of data loss.
4. `lib/provider_scope.dart` and `RootProvider` → the entire navigation model.
5. `packages/storypad_editor` → the persisted content format (backward compatibility).
6. `android/build.gradle.kts`, `android/app/build.gradle.kts`, `bin/build_apk`, `bin/android_doctor` → local Fedora build relies on `notelyCompileSdkMinor`, `flutter.installedNdkVersions`, and Groovy mirror rewriting (`D-040`).
