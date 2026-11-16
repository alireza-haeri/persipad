# Project analysis — what could be better next

**Measured:** 2026-11-16 (session 11) on `a238698`, i.e. the Session-10 code base plus docs.
**Note:** a parallel session continues on `arena/e3e3866a-notely` (latest seen `929719c`,
Android `:jni`/NDK work). Facts it changes are called out where they touch a finding.
**Rule (D-041):** every finding here carries *evidence* and a *way to re-measure it*. Nothing
here is a commitment — scheduling happens by moving an item into `BACKLOG.md`/`PROGRESS.md`.
Findings that stop being true are deleted, not left to rot.

> How this was measured: `find`/`wc` over the tree, a dependency-import scan over
> `lib/` + `packages/*/lib`, and reading the specific files named under each finding. No
> claim below comes from memory of an earlier session. Nothing was executed — the sandbox
> still has no Flutter SDK (see `ENVIRONMENT.md`).

---

## 0. The shape of the code base (context for everything else)

| Fact | Value | Re-measure with |
|---|---|---|
| Dart files (`lib/` + `packages/`) | 1013 | `find lib packages -name '*.dart' -not -path '*/build/*' &#124; wc -l` |
| Dart LOC (same scope) | ~116k (109k excluding `.g.dart`) | `find lib packages -name '*.dart' &#124; xargs wc -l &#124; tail -1` |
| Screens | 33 folders in `lib/views/` | `ls lib/views &#124; wc -l` |
| ViewModels | 63 | `find lib/views -name '*_view_model.dart' &#124; wc -l` |
| Root test files | 110 (1062 `test(` cases) | `find test -name '*_test.dart' &#124; wc -l` |
| Editor-package test files | 57 (390 cases) | `find packages/storypad_editor/test -name '*_test.dart' &#124; wc -l` |
| Direct dependencies | 74 runtime + 7 dev | `sed -n '/^dependencies:/,/^dev_dependencies:/p' pubspec.yaml &#124; grep -cE '^  [a-z_0-9]+:'` |
| Translation files | 21 × 626 keys | `python3 -c "import json;print(len(json.load(open('translations/en.json'))))"` |
| Biggest hand-written files | `stories_box.dart` 892, `google_drive_cloud_service.dart` 802, `raw_editor.dart` 752, `home_view_model.dart` 716 | `find … &#124; xargs wc -l &#124; sort -rn` |

The code is in good shape for a fork of this size: it compiles under a pinned SDK, the DB layer
is behind models with static `db` boxes, and the fork's own additions (calendar display layer,
score add-on, platform capabilities, entitlements) are small, dependency-free and unit-tested.
The gaps below are mostly *coverage* and *product surface*, not structural rot.

---

## 1. Highest-value finding: the editor package's 390 tests never run in CI

- **Evidence:** `.github/workflows/linux.yml` runs `flutter test` from the repo root only
  (test job, line ~220: `flutter test --reporter json "${selected[@]}"`). `bin/changed_tests`
  mirrors `lib/**` → `test/**` and has no `packages/**` mapping
  (`grep -n 'packages/' bin/changed_tests` → nothing). Nothing in `.github/workflows/`
  mentions `packages/`. Yet `packages/storypad_editor/test/` holds **57 files / 390 cases**,
  and `packages/storypad_editor` is the package that owns the persisted content format —
  the one thing `ARCHITECTURE.md` calls most dangerous to break.
- **Why it matters:** this is not "more tests"; it is *existing* protection that is switched
  off. A change to the editor's markdown/embed layer can regress silently even though a test
  for exactly that exists, because the suite never runs it.
- **Cost:** small. One extra CI step (`flutter test` inside `packages/storypad_editor`) plus a
  `packages/` branch in `bin/changed_tests` (any `packages/**` change → run that package's
  suite; it is 390 cases and should be well under a minute).
- **Risk if done carelessly:** none to the app; the package tests do not need the app's
  ObjectBox DB. Run them as their own job so a failure is unambiguous.
- **Note on parallel work:** `bin/changed_tests` and `linux.yml` are files the other session
  also edits (Android tooling lives in `bin/`). Coordinate before touching them, or make the
  change additive.
- **Backlog id:** new — see `BACKLOG.md` T-9.

## 2. Backup/sync merge correctness is the least-tested thing that can lose data

- **Evidence:** the merge decision lives in
  `lib/core/services/backups/sync_steps/utils/restore_backup_service.dart`
  (`restoreOnlyNewData`: newer `updatedAt` wins; if the device is newer it calls `db.touch()`
  to keep the row marked unsynced). `test/core/services/backup_sync_steps/` contains exactly
  one file (`backup_images_uploader_service_test.dart`). There is **no test** for the
  three-way case (device newer / backup newer / equal) and no test that `touch()` really keeps
  a row eligible for the next upload.
- **Why it matters:** "which side wins" is the one bug class that silently destroys notes, and
  it is pure logic over two timestamps — the cheapest possible thing to test properly.
- **Cost:** low, but **not free like the calendar tests were** — one small seam is needed first.
  `RestoreBackupService.restoreOnlyNewData` iterates `BackupRepository.databases`, which is
  `static final List<BaseDbAdapter> databases = [PreferenceDbModel.db, StoryDbModel.db, …]`
  (`lib/core/repositories/backup_repository.dart`, line 76). The list is mutable, so a test
  *can* replace its contents — but evaluating the initializer touches eight `*.db` getters,
  each of which opens the real ObjectBox store (native libs, no store in a widget-less test).
  So the honest order is: (a) add an overridable seam (e.g. a `@visibleForTesting` setter or a
  constructor-injected `List<BaseDbAdapter>`), (b) then the three-case table test with a fake
  adapter. Both are small, but pretending it is a zero-seam change would be wrong.
- **Also worth one test each, same area:** `BackupLatestCheckerService`'s
  "older app on another device" detection, and `BackupObject.fromContents` version handling
  (v2/v3/v4) which `BACKLOG.md` already flags as the manual cross-app migration path.
- **Backlog id:** new — see `BACKLOG.md` T-10.

## 3. Search is a linear scan with a leftover per-open reindex, and has no tests

- **Evidence:** `StoryObjectBox.searchMetadata` is a nullable `String` with **no `@Index()`**
  (`lib/core/databases/adapters/objectbox/entities.dart`, line 94), and queries use
  `…searchMetadata.contains(query.toLowerCase(), caseSensitive: false)`
  (`stories_box.dart`, ~line 798) — a case-insensitive substring scan over every story.
  Separately, `SearchViewModel`'s constructor calls
  `StoryDbModel.db.reindexSearchMetadata().then((_) => load())` **on every open**
  (`lib/views/search/search_view_model.dart`, line 31); that method queries every story whose
  metadata is null and rebuilds it in `Isolate.run` batches of 50 — correct as a lazy backfill,
  pointless once the backfill has run.
  **No file under `test/` mentions `SearchFilterObject` except
  `test/core/services/calendar/calendar_display_test.dart`**, and there is no
  `*search*` test at all.
- **Why it matters:** search is the second-most-used surface of a journal after writing. Today
  it is O(stories) per keystroke (debounced), and the filter object that the calendar work made
  load-bearing (`date_ranges`, display years, `encode`) is untested directly.
- **Cost:** medium. Two separable pieces:
  1. *Cheap, do first:* `SearchFilterObject.encode/decode` + `buildQuery` filter mapping tests
     (pure maps, no DB). This protects the Gregorian/Shamsi boundary that D-025–D-029 rest on.
  2. *Later:* make the reindex conditional (e.g. a stored "backfill done" flag, or only when a
     `null` count query says there is something to do) and only then look at indexing/search
     quality (prefix/FTS-style) — ObjectBox has no full-text index, so this needs its own
     decision, not a drive-by change.
- **Backlog id:** new — see `BACKLOG.md` T-11.

## 4. The "lightweight phone build" (A-3) has far less fat than expected

The user's next planned track is a leaner phone APK. Measured reality:

| Dependency | Files importing it | Verdict |
|---|---|---|
| `cloud_firestore` | **1** | effectively dead in this fork (no Firestore-backed feature in `lib/`) |
| `flutter_material_design_icons` | 1 | one icon set, replaceable |
| `audio_service`, `quick_actions`, `in_app_update`, `local_auth`, `dynamic_color`, `dismissible_page`, `flutter_custom_tabs`, `volume_controller`, `open_location_code`, `csv` | 1 each | each is one feature; removing one *removes* that feature |
| `google_maps_flutter_ios_sdk10` | 0 (iOS-only, and iOS is out of scope) | removable |
| `cupertino_icons` | 0 | removable |
| `purchases_flutter` (RevenueCat) | 2 | no store in this fork (`ProEntitlementService.unlockAll`) — see D-011 |
| `in_app_review`, `support_us` screen | 2 | no store listing → nothing to review |
| `timezone` + `flutter_timezone` + `flutter_local_notifications` | 1–2 | used only by reminders |

- **Evidence for the "fat isn't the problem" conclusion:** `assets/` is **2.0 MB** total
  (`du -sh assets`), `translations/` 920 KB, committed `*.g.dart` 344 KB. The 138 MB debug APK
  is essentially Flutter's debug runtime + ObjectBox + the plugin
  `classes.dex`/`libflutter.so` payload. A **release** build (AOT, tree-shaken icons) is the
  single biggest size lever, and it needs the keystore secrets that D-038 already documents.
- **Concurrent-session correction (2026-11-16, commit `929719c` on `arena/e3e3866a-notely`):**
  a parallel session discovered that `jni 1.0.3` (transitive via `path_provider_android 2.3.1`)
  **does** compile C (`dartjni.c` → `libdartjni.so`) with CMake, so D-040's "nothing in
  `pubspec.lock` compiles C/C++" is no longer true and `--no-ndk` now only applies when `:jni`
  is absent. Read `ai/DECISIONS.md` on that branch for the current text — this is exactly the
  kind of fact this file must not freeze. Two consequences for the lightweight-build track:
  1. "No NDK needed" is **not** a property of this project any more (unless `jni` is removed),
     so a trimmed build would have to keep provisioning NDK+CMake or drop the dependency that
     pulls `jni` in.
  2. It is further evidence for order-of-operations: measure a release build first, because the
     same rebuild may change which plugins are even present.
- **Recommendation (a real scope proposal, not a code change):**
  1. **First lever: ship a release-signed APK** (4 GitHub secrets, ~30 min of setup) — do this
     before deleting any feature. Deleting code is irreversible; shrinking a build is not.
  2. **Then the honest trim list:** `cloud_firestore`, `google_maps_flutter_ios_sdk10`,
     `cupertino_icons`, plus the paywall/review/RevenueCat surfaces (`purchases_flutter`,
     `in_app_review`, `views/paywall`, `views/support_us`). Each is unreachable or
     iOS-only in this product, so nothing the user can see disappears.
  3. **Do *not* trim** `google_maps_flutter`, `record`, `video_compressor_plus`, `just_audio`,
     `relax_sounds` — they are *features*, and the map is deliberately default-on (D-035 §3).
     Turning them off is an add-on toggle the user already has, not a build-time cut.
  4. **Locales:** 21 × 626 keys are ~44 KB of JSON each — noise for APK size, but real
     maintenance cost. If the "fa + en only" question (`GOAL.md` open question 4) is ever
     answered, drop the other 19 files; it is a translation-parity test change plus 19 deletes.
- **Backlog id:** A-3 (already open) — this section is the measured input for that decision.

## 5. Perceived speed / polish items found while reading

- **Theme fonts are fetched at runtime.** `AppTheme` builds its text theme with
  `GoogleFonts.getTextTheme(...)` (`lib/app_theme.dart`, line 155), and the font picker screen
  calls `GoogleFonts.getFont(...)` to draw previews. `google_fonts` downloads missing families
  over the network on first use; nothing in the repo sets `allowRuntimeFetching` or bundles the
  default family (`kDefaultFontFamily = 'Quicksand'`, `app_constants.dart` line 50). Consequence:
  the app's typography depends on a network fetch the first time, which contradicts the
  offline-first promise (`GOAL.md`) and can look like a font "flash" on a fresh install.
  Cheap fix: bundle the family the app actually uses by default (plus anything offered as
  "free" in the picker — `FontsViewModel` shows at most 5 per group) and set
  `GoogleFonts.config.allowRuntimeFetching = false`; the rest of the catalogue can stay
  network-only behind an explicit "download" affordance. **Medium impact, small cost.**
- **Home prefetches every page eagerly.** `HomeViewModel.reload()` awaits page 1 then
  `unawaited(_prefetchRemainingPages(generation))` loops until `_hasMoreStories` is false
  (`home_view_model.dart`, ~line 318). Deliberate (comment says so), but it means opening the
  app on a big year reads *all* stories and preloads every asset aspect ratio. On a phone with
  thousands of entries that is real start-up work for data the user cannot see yet. Worth
  measuring on a large DB before changing anything — this is a "measure first" item, not a fix.
- **One `Semantics` and 4 `Tooltip`s in the whole app** (`grep -rn 'Semantics(' lib` → 1,
  `Tooltip(` → 4). Flutter's default semantics cover most things, but the calendar cell, the
  score bar and the story-list rail — our own custom widgets — are exactly where a screen
  reader gets nothing. Cheap to add where it matters and invisible where it doesn't.
- **Three bare `print()` calls** outside guarded code: `app_logger.dart` (guarded by
  `kDebugMode`, fine), `base_storage_adapter.dart:27` (`"ERROR: read $e"`, **unguarded** — the
  only one that can reach a release log), and `base_story_view_model.dart:368` (guarded).
  Worth routing the unguarded one through `AppLogger`, which already respects `kDebugMode`.

## 6. Build/CI health (the rules we already have, and where they leak)

- **The Android workflow has no `paths-ignore`** (`linux.yml` has one for `ai/**`, `**/*.md`).
  Every docs push still evaluates the Android job; it skips, but it costs a run slot and, worse,
  it is the thing that once cancelled an in-flight `[apk]` build (D-039). Cheap: add the same
  `paths-ignore` to `android.yml`, keeping the `[apk]` marker as the only real trigger.
- **`bin/changed_tests` treats `packages/**` as "unmapped"** → any editor-package change forces
  the *whole* root suite, which is the slowest possible response to the most likely-to-need-tests
  change. Fixing §1 and this together is one small commit.
- **Formatting is still advisory** (`BACKLOG.md` T-7) and the CI formatter disagrees with
  untouched files. That is a real risk of "fix formatting → touch 40 files nobody meant to
  change". Keep it advisory until someone runs `bin/format` once deliberately on a clean tree.
- **No coverage reporting.** `linux.yml` never collects `--coverage` (only the upstream `ci.yml`
  does, and that workflow targets `develop` and is effectively dead). We cannot tell whether the
  110 root test files cover 20% or 60% of `lib/`. Cheap: add `--coverage` and upload the
  `lcov.info` as an artifact on `[full]`; no new service, no threshold enforcement.

## 7. Product ideas that fit *this* code base

These are ranked by "uses what already exists" rather than by novelty:

| Idea | Why it is cheap here | Cost |
|---|---|---|
| **Local folder backup / Markdown mirror** (`BACKLOG.md` F-2) | `ExportStoriesToMarkdownService` already exists; a folder watcher is a `dart:io` loop. This is also the Linux answer to "Drive appDataFolder is app-scoped" (D-021) | medium |
| **Reminders on Linux** (`I-12`) | `flutter_local_notifications_linux` **is** in `pubspec.lock` (transitive) — the plugin supports Linux; only `LocalNotificationService.supported` excludes it. A real scheduler is still needed for the "no scheduling support" gap, but the platform is not the blocker it was believed to be | medium |
| **Encrypted local export** | Backups are gzipped JSON (`GzipService`), not encrypted. A password-protected `.tar.gz` (AES-GCM via `crypto`+`pointycastle` or the existing `cryptography` path) makes an exported archive safe to store anywhere | medium |
| **Streaks / writing stats** (`F-4`) | `MonthlyStoryStatsService` + `DailyScoreProvider` already compute per-day data for the calendar and the trend charts; a streak is one more derived number on the same data | low |
| **Focus mode** (`F-9`) | The editor already has a toolbar/`SpEditorToolbar`; hiding chrome is a boolean + a route | low |
| **Windows tray / launch-at-startup** (`F-8`-adjacent) | Needs `window_manager` + `tray_manager` (new deps, Linux+Android support must be checked first per RULES §3) | medium |

## 8. Explicitly **not** recommended right now

- **A "feature-based layering" refactor** (`BACKLOG.md` T-1). 1013 files is unpleasant to
  discover, but the MVVM layout is consistent and the CI scoper, the calendar display layer and
  the DB models all depend on those paths. The gain is navigability; the risk is every open
  branch. Do it only when a feature forces the boundary.
- **Migrating off `objectbox 6.0.0-preview.6`** before a stable release exists (T-0). Preview is
  ugly but working; a migration is a schema change, and schema changes are the #1 sensitive area.
- **Deleting the `storypad` flavor / macOS / iOS / web trees.** Explicitly out of scope to
  touch (`GOAL.md`), and dead code costs nothing at runtime.

---

## 9. If we only do three things (the short list)

Ordered by *risk removed per hour spent*, not by ambition:

1. **Turn on the editor package's 390 tests** (`BACKLOG.md` T-9) — the persisted content
   format is the most dangerous area and its suite is currently never executed. ~1 commit,
   no product change.
2. **Test the backup merge decision** (`BACKLOG.md` T-10) — needs a tiny test seam first
   (see §2), then a three-case table. This is the only failure mode in the app that can
   silently destroy notes.
3. **Ship a release-signed APK instead of trimming features** (`ANALYSIS.md` §4, D-038) —
   the 138 MB is a debug-build artifact, not a fat-codebase verdict. Four secrets, one
   documented workflow, and every "lightweight" question can then be answered with numbers.

Everything else (search quality, fonts offline, accessibility, coverage, Linux reminders,
Markdown folder binding) is real but should wait for a decision rather than be bundled in.

---

## How this file stays honest

1. Re-measure a claim before acting on it; update the number here in the same commit.
2. A finding that gets fixed moves to `PROGRESS.md` (with its commit) and is **deleted** here.
3. A finding that needs a decision gets a `⏸` entry in `BACKLOG.md` and a pointer from here.
