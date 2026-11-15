# Architecture map

Canonical source: the project's own `README.md` and `CONTRIBUTING.md`. This file is
the practical cheat sheet for day-to-day work. Numbers were measured on 2026-11-15
(version 2.34.0).

## Basics

| Item | Value |
|---|---|
| Framework | Flutter (Dart SDK `^3.11.0`) |
| App version | `2.34.0+834` |
| Dart files | ~981 (excluding `build/`) |
| Tests | 92 files in `test/` + 57 in `packages/storypad_editor/test/` |
| Database | ObjectBox (legacy SQLite adapter still present) |
| State | Provider + ChangeNotifier, three levels: Global / View / Widget |
| Pattern | MVVM across 3–4 files: `Model` / `View` / `ViewContent` / `ViewModel` |
| i18n | `easy_localization`, 20 files in `translations/` |
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
`InAppPurchaseProvider`, `NicknameProvider`, `RelaxSoundsProvider` (lazy).

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

## Sensitive areas (think three times before touching)

1. `lib/core/databases/models/*` + `objectbox.g.dart` → real user-data migrations.
2. `lib/core/initializers/` + `lib/main.dart` → boot order breaks everything.
3. `lib/core/services/backups/*` → risk of data loss.
4. `lib/provider_scope.dart` and `RootProvider` → the entire navigation model.
5. `packages/storypad_editor` → the persisted content format (backward compatibility).
