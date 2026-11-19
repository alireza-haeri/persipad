# Status

**Last updated:** 2026-11-19 (session 21)
> Historical integration notes and branch snapshots below describe earlier work; Arena's latest session context is authoritative for the active branch.

**Current session:** session 21 — gender selection mapped to in-app illustration and included in backup/sync (`D-063`)
**Branch:** `arena/7ba21f51-notely`, branched from `main` at `a87f0147ad786e37c7c38255c24d1cfe1171469c`
**Phase:** 🚧 Implementation and translation parity checks pass; Flutter/Dart tests and formatting are pending because the SDK is unavailable in the sandbox. The user verifies on the Android phone using a Debug APK; Release was confirmed faster and is not the current dev loop.

---

## 🤝 Handoff Snapshot (start here if you are a new agent/session)

1. **What exists right now:**
   - **Streamlined cross-platform core (`D-047`, confirmed in `N-020`):** Removed Maps/Location/Geocoding, Relax Sounds (`audio_service`), Period Calendar, Add-ons screen, Fonts picker (`google_fonts`), In-App Purchases/Paywall/Support Us (`purchases_flutter`), non-Drive cloud providers (`Nextcloud`/`Dropbox`/`iCloud`/`webdav_client`/`dio`/`flutter_web_auth_2`), and 19 non-EN/FA translation locales (14 dependencies removed).
   - **Unified Google Drive sync (Linux + Android):** Both platforms authenticate through `GoogleDesktopAuthStrategy` (`GOOGLE_DESKTOP_CLIENT_ID` / `GOOGLE_DESKTOP_CLIENT_SECRET`, wrapped in `SpAppLockWrapper.disableAppLockIfHas`), sharing the same `appDataFolder`.
   - **Two locales & 100% offline dual-font typography (`D-048`):** `translations/en.json` and `translations/fa.json` (`485` keys in exact parity), using bundled `Quicksand` (`Quicksand-Variable.ttf`) for English and bundled `Vazirmatn` for Persian (`AppTheme.fontFamilyForLocale` / `fontFamilyForLanguageCode`), with zero network font fetching.
   - **Performance, tests, CI & DST-safe calendar (`D-042`..`D-046`, `D-049`):** Non-blocking search reindex (`count()` probe), backup merge unit tests (`BackupRepository.overrideDatabases`), `SearchFilterObject` tests, calendar cell accessibility semantics, DST-safe civil/UTC date math (`Asia/Tehran` verified), editor package test job (`390` cases) + `Coverage` job (`14.7%`) in `linux.yml`, fail-closed `apksigner` signature check + `[apk-test]` mode in `android.yml`, and `bin/local_verify` for one-command local Linux + Android verification.
   - **Daily Score in Settings:** Daily Score toggle lives in Settings → Stories (`list_tile.daily_score.{title,subtitle}`); all remaining features are unlocked directly without paywall indirection.
   - **Runtime defects from real Fedora/Android logs (`D-050`..`D-055`):** Linux voice notes play through a system CLI player (`LinuxVoicePlayerBackend`), no-op syncs no longer reload the home screen, story lists watch a filter notifier, a missing artwork submodule is a codegen *skip*, and an **unreachable Google is a network error** — `signIn` shows `snack_bar.no_internet`, `refresh` marks the service `noInternet`, `restore()` keeps the account while offline, and app startup cannot throw because of it. The AVD now gets a working resolver by itself (`bin/build_apk` reads `resolvectl dns` when the host uses the `127.0.0.53` stub) and an already-running emulator with broken DNS is named as such before you install.
   - **Android (`community` flavor, local Fedora & CI verified):** `bin/android_doctor` + `bin/build_apk` confirmed working end-to-end on Fedora (`NDK 28.2.13676358` + `CMake 3.22.1` + `android-36.1` + Tencent Maven mirror → APK built in `1m32s`), alongside `.github/workflows/android.yml` on GitHub Actions.
2. **Verified metrics (2026-11-16):**
   - **Fedora local (`bin/local_verify`):** `analyze` PASS (`12s`), `root tests` PASS (`+1087`, `56s`), `editor tests` PASS (`+11088` steps / 57 files, `24s`), `linux build` PASS (`13s`), `android apk` PASS (`1m32s`).
   - **GitHub Actions CI:** Linux (`43868965727` on `15b28ac`, the session-13 commit): `Scope`, `Analyze`, `Test (1)`, `Test (2)`, `Editor package tests`, `Build Linux desktop` all green; `Coverage` (advisory) was still running when the session ended. Earlier full runs: Linux `43854176350` 7/7; Android `43849981463` APK build + signature verification green.
3. **What is planned next:**
   - **👤 One emulator sign-in attempt** — `bin/build_apk --install --avd=storypad_dev` (no flags: the resolver is automatic now) → Settings → Backup → Google Drive → sign in. This is the only open question in the sync path, and it needs your machine.
   - **Real-device Google Drive OAuth E2E check:** configure `GOOGLE_DESKTOP_CLIENT_ID` / `GOOGLE_DESKTOP_CLIENT_SECRET` via `bin/setup_sync` and test sign-in + sync between Linux desktop and Android phone.
   - **Release keystore secrets (optional):** add `ANDROID_KEYSTORE_*` secrets in GitHub Settings if smaller, updatable release-signed APKs are wanted from `[apk]`.
4. **Hard rules & invariants for any agent touching this repo:**
   - **No Flutter/Dart in sandbox; no `pub.dev` / `dl.google.com` access.** Rely on `.github/workflows/linux.yml` / `android.yml` or user's `bin/local_verify` / `bin/dev -t`.
   - **Never leave `HEAD` depending on un-generated `*.g.dart`:** changing `@CopyWith` or ObjectBox models requires `.github/workflows/codegen.yml` (`[codegen]`) first (`D-016`).
   - **Keep Gregorian storage / Shamsi display boundary intact** (`CalendarDisplay`, `DateRangeFilterObject`, `SearchFilterObject.encode`, `D-025`..`D-029`) and never step calendar dates with `Duration(days:)` on local `DateTime` (`D-049`).
   - **Keep `translations/en.json` and `translations/fa.json` key sets identical** (`485` keys, enforced by `unused_translations_test.dart`).
   - **Keep both fonts 100% offline (`D-048`):** `Vazirmatn` (`fa`) and `Quicksand` (`en`) in `assets/fonts/`; never reintroduce runtime network font fetching.
   - **Preserve RTL invariants** (`SpIcons.previous/next`, `AppTheme.rtl`, never abbreviate Persian month names, never wrap row widgets in `OverflowBox`, `DailyScoreScale.gradient(rtl:)`, `D-030`/`D-035`).
   - **Preserve Fedora Android build hooks** in `android/build.gradle.kts`, `android/app/build.gradle.kts`, `bin/build_apk`, and `bin/android_doctor` (`notelyCompileSdkMinor`, `notelyNdkVersion`, `LibraryExtension.compileSdk >= 36`, Groovy mirror init script — `D-040`).

---

## ✅ Done

### Session 1 — foundation
- [x] Imported StoryPad v2.34.0 (`cffda48`) into `alireza-haeri/notely`.
- [x] `ai/` memory folder, architecture map, English docs (D-006).

### Session 2 — Linux dev loop
- [x] App runs on Linux (verified by you on Fedora).
- [x] Toolchain baseline: Flutter 3.50.0 / Dart 3.14.0 (D-008).
- [x] SDK-driven dependency bumps committed (D-009).
- [x] `bin/dev --community-linux` + `bin/setup_linux` (D-010).
- [x] Platform scope: Linux only, Android parked (D-007).

### Session 3 — feature parity on Linux
- [x] **Every Pro feature unlocked** through one reversible switch
      (`ProEntitlementService.unlockAll`, D-011). This also unlocks Nextcloud and
      Dropbox sync, which were Pro-only.
- [x] Upsell surfaces (paywall entries, Pro badge, pro banner) are now driven by
      `kShowProUpsell` instead of "is the store enabled" — they hide when there is
      nothing to buy.
- [x] **Dead "Connect Google Drive" tile removed from Linux:** a platform-capability
      matrix (`PlatformCapabilities`) disables the tile with an explanation, so Linux
      keeps Dropbox (loopback OAuth) + Nextcloud (WebDAV) as working sync backends (D-012).
- [x] New translations for the "not available on this platform" subtitle in all 20 locales.
- [x] **GitHub Actions CI** (`.github/workflows/linux.yml`): Test (blocking), Build Linux
      desktop (blocking), Analyze (advisory), running on every push (D-013).
- [x] 13 new unit tests: entitlement resolution policy + platform capability matrix,
      including a regression guard that Linux always keeps a working sync backend.
- [x] **Desktop media picking fixed** (D-015): `pickVideo` and `pickMultipleMedia` threw
      `UnimplementedError` on Linux because `image_picker_linux` handles a single image
      only. Linux/Windows now open the OS file dialog via `file_picker`.
- [x] 5 more tests pinning the media extension lists to `AssetFileTypeService` (a video
      picked from disk used to be insertable as an image).

### Session 8 — Persian locale
- [x] `translations/fa.json`: all 602 keys translated (key-set parity enforced by the tests).
- [x] Registered `fa` for the app picker, Android per-app languages and iOS.
- [x] Date locale data is initialized at startup; Arabic-script font fallback added.
- [ ] User review of the wording/glossary — it is one file, cheap to iterate on.

### Session 9 — Persian font bundled + calendar settings
- [x] **Vazirmatn bundled in the app** (4 faces, 492 KB, OFL included) and kept as the first
      Arabic-script fallback, so Persian text is identical on every OS instead of depending on
      whatever the distro has installed (D-023).
- [x] **Any first day of the week** (Monday…Sunday; Saturday was missing before).
- [x] **User-defined weekend days** — a `weekendDays` preference plus a settings screen, and the
      calendar header/day cells now colour *the user's* weekend instead of a hard-coded
      Saturday+Sunday (D-024). Iran: Friday (or Thursday+Friday); Europe: Saturday+Sunday.
- [x] `CalendarConfig` — one place to publish session-wide calendar settings for widgets that
      have no `Provider` (the calendar grid), filled before the first frame.
- [x] **Shamsi (Solar Hijri) conversion engine** (`PersianCalendar`, hand-written because pub.dev
      is unreachable) with known-vector, leap-year and 45-year day-by-day round-trip tests.
- [x] **Shamsi as the displayed calendar (reading flow)** — a `calendarSystem` preference plus
      `CalendarDisplay` (D-025): storage and queries stay Gregorian, the story list groups by the
      displayed month, month chips/monogram days/full dates render in Shamsi, and a Shamsi year or
      month is converted back into an exact Gregorian day range (`date_range` DB filter) before
      querying.
- [x] **Shamsi date picker** (`SpDatePickerDialog`, D-026): the story date picker draws the display
      calendar (grid, header, first day of week, weekend colours) and returns a Gregorian date.
- [x] **Switching calendar re-anchors on today** instead of keeping a year number that means a
      different span in the other calendar.
- [x] Day numbers are now explicit per calendar (`d` / `dayNumber` / `gregorianDay`), which fixed
      "15 آبان ۱۴۰۵" for a story dated 24 Aban and kept the Gregorian mood grid printing Gregorian days.
- [x] **Year filters follow the display calendar** (D-027): archive/tag/year tabs and the search
      filter chips show display years, counted exactly; `CalendarDisplay.yearsFilter` converts them
      to Gregorian years + `date_ranges` at the query boundary. Calendar switch clears the saved
      search filter so a stale display year can't empty the list.
- [x] **Year numerals + a stale-year comparison**: the app-bar year, the empty-state year, the
      story month header year and the tile monogram day print in the locale's digits
      (`DateFormatHelper.number`). `onAStoryReloaded` compared a display year with the stored
      Gregorian year, so an edited story was dropped from (or kept in) the wrong list.
- [x] **Calendar screen in Shamsi** (D-028): grid (`CalendarDisplay.monthGridDates` through
      `CalendarDaysGenerator`), header, month picker, day numbers, feelings (`getStoryFeelingByMonth`
      by range, keyed by display day), period events (`EventsBox` gained `date_range`) and the story
      lists (`DateRangeFilterObject`). Fixed the `Instance of 'DateTime'` crash by encoding filter
      maps with `SearchFilterObject.encode` instead of `jsonEncode`.
- [x] **Stats screen in Shamsi** (D-029): `StatsRange` snaps to display months/years (its
      start/end/month/years/label/previous/next all go through `CalendarDisplay`), the tab labels and
      the twelve trend bars count display months, the year picker lists display years, and story
      queries use exact day ranges.
- [x] **Month recap tiles in Shamsi** (closes `BACKLOG.md` C-1h): `MonthlyStoryStatsService` groups by
      display month, counts active days by display day and scores against the display month's length
      (Aban = 30 days), so the home list shows recaps in both calendars instead of skipping them.
      Nothing in the app aggregates by the Gregorian `month` column any more.
- [x] 2 new translation keys in all 21 locales.

### Session 7 — Google Drive works on Linux
- [x] `GoogleDriveAuthStrategy` split out; mobile keeps `google_sign_in` unchanged (D-019).
- [x] Loopback OAuth2 client for Google (`GoogleDesktopOAuthService`) — no new dependencies.
- [x] `GoogleDriveLinuxCloudService` is no longer a stub: it is the real Drive service with
      the desktop auth strategy.
- [x] Drive tile enabled on Linux; a missing client id shows a setup checklist instead of a
      broken browser page.
- [x] `bin/setup_sync` writes/merges/masks the credentials in gitignored `private_keys/`.
- [ ] Real end-to-end run with actual credentials (waiting on the user).
- [ ] Dropbox stays dead until `DROPBOX_APP_KEY` is set — same script, same file.

### Session 6 — CI levels + the app actually boots on Linux
- [x] **Fixed the crash that prevented the app from starting on Linux** (D-018):
      `DefaultFirebaseOptions.currentPlatform` throws on Linux and was read eagerly in
      `main_community`, so `runApp` never happened. Now guarded by a tested capability.
- [x] CI split into opt-in jobs (D-017): plain push = Analyze only (~2 min); `[test]`,
      `[build]`, `[full]` add the rest. `build_runner` removed from every job.
- [x] My own loop: no more long polling of runs — one check later, work in between.

### Session 5 — the fresh-clone run failure
- [x] Diagnosed your `loadObjectBoxLibraryAndroidCompat` error: the committed
      `lib/objectbox.g.dart` was generated by objectbox 5.x while the pin is
      6.0.0-preview.6 (D-009 fallout). Regenerated it on a real toolchain via the new
      `Codegen` workflow, reviewed the diff, and committed it (D-016).
- [x] `pubspec.lock` refreshed too (it had been stale by design since D-009).
- [x] `bin/dev` now names this failure in 1 second instead of letting a build die later;
      a missing stamp on a fresh clone only prints a note, never blocks.
- [x] CI reports (advisory) when committed generated code drifts from a fresh run.

### Session 4 — speed
- [x] CI no longer blocks me: docs-only commits are skipped (`paths-ignore`), the codegen
      asset graph is cached, and I keep working while a run is in flight (D-014).
- [x] Formatting gate is advisory again (see "Known debt" below).
- [x] `bin/check` — local pre-push equivalent of the CI gates (format + analyze + test),
      so the slow path is the exception.
- [x] VS Code: a **Community (Linux)** launch config, so F5 runs the app with no terminal
      command and no `--flavor` mistake.

## 🔄 In progress

- [ ] **First local Fedora APK build (`d3d534e`):** `bin/build_apk --install --avd=storypad_dev -v`
      actively running on user's Fedora machine via Tencent mirror (NDK `forceNdkDownload` hang
      confirmed resolved; Gradle downloading/configuring plugin subprojects). Awaiting final
      build + `storypad_dev` AVD install outcome.
- [ ] **Next planned track (`A-3` / `N-015`):** once the local APK build is verified on device/AVD,
      scope and build a **lightweight phone version** of the app with the user.

## ⏳ Remaining (roadmap)

### Phase 1 — verify current Android & Linux builds
- [x] CI green on `arena/e3e3866a-notely` (`Linux` `43823502245`, `Android` `43812916947`).
- [ ] Finish running `bin/build_apk --install --avd=storypad_dev -v` on Fedora and verify basic
      flows on `storypad_dev` / physical Android phone (install, boot, Persian/Shamsi UI, calendar/scores).
- [ ] On Linux desktop (`bin/dev --community-linux`), verify real Google Drive OAuth credentials
      (`bin/setup_sync`), Nextcloud bridge (`I-12`), and wording review of `translations/fa.json`.

### Phase 2 — lightweight phone build & Linux gaps
- [ ] **Lightweight mobile/phone APK (`A-3` / `N-015`):** decide with the user which heavy modules/plugins
      or locales to keep vs strip/gate for a smaller, faster phone APK.
- [ ] Reminders/notifications on Linux (`BACKLOG.md` I-12 — needs an app-side scheduler).

### Phase 3 — first new product features / personal redesign
- [ ] Pick from `BACKLOG.md` (`F-1`…`F-10`); the redesign list is still yours to write.

### Parked / out of scope (do not spend time on)
- `storypad` upstream flavor (needs `private_keys/`).
- macOS / Windows / iOS / Web targets.
- Camera, quick actions, and video compression on Linux (stay guarded behind platform checks).

## 🧹 Known debt (small, tracked)

- ~~Committed `*.g.dart` is stale~~ — **fixed**: regenerated on a real toolchain and merged
  (D-016). `flutter run` works on a fresh clone again.
- **Formatting gate is advisory** even though it is currently green (`BACKLOG.md` T-7). The
  sandbox cannot run `dart format`, so a blocking gate would cost a full round trip per
  line-break guess.
- **Desktop multi-select** degrades to a single file dialog (`BACKLOG.md` T-8).

## 📊 Metrics

| Metric | Value |
|---|---|
| Dart files (`lib/` + `packages/`) | 1013 |
| Locale files (`translations/`) | 21 (628 keys each, `fa.json` added) |
| Active platform targets | **2** (Linux desktop + Android `community` APK) |
| CI on a plain push | `Scope` (~6s) + `Analyze` (~85s) + scoped `Test` (~1–3 min); `[build]`/`[apk]`/`[codegen]` opt-in |
| Test files | 110 in `test/` + 57 in `packages/storypad_editor/test/` |
| Pro feature gates opened by one switch | ~30 call sites (`ProEntitlementService.unlockAll`) |

## 🧾 Test log

| Date | Task | Verified by | Result |
|---|---|---|---|
| 2026-11-15 | Base app runs as Linux desktop on Fedora | you | ✅ runs; ObjectBox + features work (N-006) |
| 2026-11-15 | Pro unlock + capability layer + CI | GitHub Actions | ✅ Test + Build green (run `43712927893`) |
| 2026-11-15 | Desktop media picking (`file_picker`) | GitHub Actions | ✅ all three jobs green (run `43716086122`) |
| 2026-11-15 | Bundled font + calendar settings (weekends, any first day) | GitHub Actions | ✅ Analyze 80s, Test ×2, Build Linux (run `43727580987`) |
| 2026-11-15 | Shamsi display mode, picker, filters, calendar, stats, recaps | GitHub Actions | ✅ green across rounds (`43731618364`…`43748544073`) |
| 2026-11-15 | RTL layout/icons/month-chip + blank home fix | GitHub Actions | ✅ Analyze + Test ×2 green (`43751115475`, `43796471061`) |
| 2026-11-15 | Daily score add-on + CI scoper (`bin/changed_tests`) | GitHub Actions | ✅ Scope + Analyze + Test ×2 + Build (`43798528975`) |
| 2026-11-15 | Unified calendar (`SpCalendarDateCell` + `ScoreTrendView`) | GitHub Actions | ✅ Scope + Analyze + Test ×2 (`43800211911`) |
| 2026-11-16 | Motion polish, day score callout, map add-on, sidebar order, `bin/dev -t` | GitHub Actions | ✅ green (`43801222059`, `43803014131`, `43803391050`, `43803970360`, `43804325119`) |
| 2026-11-16 | Android `community` arm64 debug APK (138 MB, `f258929`) | GitHub Actions | ✅ build + `aapt2`/`apksigner` verify green (`43812916947`) |
| 2026-11-16 | Local Android APK scripts + `forceNdkDownload`/`36.1` fixes (`d3d534e`) | GitHub Actions + Sandbox | ✅ Linux CI Scope + Analyze + Test ×2 full suite green (`43823502245`); sandbox `bash -n` + stubbed `flutter`/`curl`/`adb`/`emulator` tests pass |
| 2026-11-16 | First local Fedora build (`bin/build_apk --install --avd=storypad_dev -v` on `d3d534e`) | you (live) | 🟡 in progress (NDK hang fixed; Gradle past `:google_sign_in_android` via Tencent mirror) |

> ⚠️ I cannot run `flutter analyze` / `flutter test` in my sandbox (no SDK, pub.dev
> blocked). CI (`.github/workflows/linux.yml`, `android.yml`) and your Fedora box
> (`bin/dev -t`, `bin/build_apk`) are the verifiers — see D-013, D-032, D-036, D-040.

### What to run now

```bash
# On Fedora — Android local build/install (currently running for d3d534e)
bin/android_doctor --mirror                    # only once if dl.google.com is blocked
bin/build_apk --install --avd=storypad_dev -v  # builds against local android-36.1 without NDK

# On Fedora — Linux desktop dev & local test gate
bin/setup_linux                                # only after fresh clone or pubspec changes
bin/dev --community-linux                      # launch desktop app
bin/dev -t                                     # fast local analyze + scoped test + build check
```

### Run log — 2026-11-15 (third round: picker, re-anchor, year filters)
- `e6eba30` Shamsi date picker + `resetToToday()` on calendar change + per-calendar day
  numbers — CI `43744135219` green (Analyze 85s, Test (1) 212s, Test (2) 202s).
- `53c0cf8` year filters in the display calendar (D-027) — CI `43744666417` green
  (Analyze 76s, Test (1) 161s, Test (2) 199s).
- `dd445d2`/`42f0b2b` locale digits for year labels + display-year reload check. The first
  attempt at these broke four files: a sort helper replaced an import window with a list one
  entry longer than the window, so each file lost its last import (12 analyzer errors, CI
  `43745093530` red on Analyze).
- `ff7652d` restores those imports and inserts the new one at its sorted position — CI
  `43745523681` green (Analyze 81s, Test (1) 213s, Test (2) 212s).
- Lesson for the next batch: never rewrite an import block by zipping it against a longer
  list; insert the single new line and leave the existing order alone.

### Run log — 2026-11-15 (fourth round: the whole calendar in Shamsi)
- `815c5f4` calendar screen pages the display calendar + `SearchFilterObject.encode` fix for the
  `Instance of 'DateTime'` crash — first CI run (`43746566927`) red on one of the new tests
  (`years` also contains the second Gregorian year a Shamsi year touches); fixed in `fb5368c`,
  CI `43746943704` green (Analyze 69s, Test (1) 215s, Test (2) 152s).
- `0a5f768`/`8181159` stats screen in the display calendar (D-029) — the first run failed Analyze on
  a missing `easy_localization` import; CI `43747645118` green (Analyze 92s, Test (1) 218s,
  Test (2) 227s).
- `9fddf0a`/`d5501ed` month recap tiles in the display calendar (C-1h) — first run failed Analyze
  because a nullable field is not promoted when indexed (`monthlyStats[...]`); fixed by copying it
  to a local. CI `43748544073` green (Analyze 68s, Test (1) 162s, Test (2) 222s).
- Every screen now reads the display calendar; the Gregorian `year`/`month`/`day` columns are only
  ever a storage detail.

### Run log — 2026-11-15 (fifth round: RTL as a first-class direction)
Your six reports (swapped month arrows, plain Shamsi picker, timeline rail stuck left, `آبا`
instead of `آبان`, swapped caret buttons, drawers running off the left edge) all came from code
that hardcoded *left* where it meant *start* or *back*. D-030 records the rules; the code is
`73fe70b` + three follow-ups.
- `73fe70b` the six fixes: `SpIcons.previous/next(context)` (reading-order chevrons everywhere
  the arrow means back/forward), the story-list rail placed by `AppTheme.rtl`, Persian month names
  never abbreviated (the month chip grows around the rail, the stats bars scale their labels),
  caret buttons that act on the side they show, root sidebar + page insets mirrored in RTL, end
  drawers that keep their own safe area, and the Shamsi picker rebuilt as a Material date picker
  (rounded sheet, tinted date header, month/year row opening the Shamsi month picker, scrollable
  body).
- `820bead` the page-insets widget reads the direction with `Directionality.maybeOf` (its own
  test pumps it without a `Directionality`), and that test now asserts the RTL mirror.
- First CI run (`43750284373`) was red on Analyze with three errors: the editor package shadows
  `TextDirection` in `sp_editor_toolbar.dart`, the caret builder needed `actions` (local to
  `_buildButtons`), and `BorderRadius.circular` is a factory so it cannot be `const`. Fixed in
  `4d10e24` — CI `43750757764` green on Analyze (75s). That commit's message had no `[test]`
  marker, so the suite had not run; `b143fc6` (stats trend labels scaling) carried the marker.
- CI `43751115475` green: Analyze 83s, Test (1) 212s, Test (2) 204s.
- The "Verify formatting" step stays advisory and now lists files nobody touched in this round
  (`stories_box.dart`, `home_view_model.dart`, …), i.e. it is the CI formatter version disagreeing
  with the committed style, not this change.

### Incident — 2026-11-15: the blank home screen (fixed in `573024a`)
- After the RTL round every story list rendered nothing: the home screen showed only the
  timeline side bar and the FAB (its app bar lives in the same viewport, so it went too), and
  the calendar's notes tab was white.
- Cause: `_MonthChip` (the month badge on a story-list header) was wrapped in an `OverflowBox`
  so a full Persian month name could grow symmetrically around the rail. `OverflowBox` defaults
  to `OverflowBoxFit.max`, which is `sizedByParent` — it takes `constraints.biggest` — and a list
  gives its rows unbounded height, so the box resolved to `Size(32, infinity)` and failed layout.
  A failing child takes the whole viewport with it, which is why the app bar vanished too.
- Fix: the chip is back to the plain `Container` + `FittedBox(scaleDown)` the tile always used,
  now with the full month name. `test/widgets/story_list/story_month_header_test.dart` pumps two
  headers in a `SingleChildScrollView` (unbounded height) in LTR and RTL and asserts the Shamsi
  chip reads `آبان` — that test fails with the old widget.
- Two follow-up CI rounds were spent on the *test*, not the fix: `context.locale` comes from
  `EasyLocalization` and throws without that widget, and easy_localization re-exports `intl`,
  whose `TextDirection` has no `.ltr`/`.rtl` and shadows Material's. Both are now encoded in the
  test's imports (`show AssetLoader, EasyLocalization`) and its in-memory `AssetLoader`.
- CI `43796471061` green: Analyze 83s, Test (1) 197s, Test (2) 207s.

### Add-on — 2026-11-15: daily score (rating each day 0–100) and a CI that only runs what it must
- Shipped the requested add-on (D-031): a toggleable `AddOnType.daily_score` that adds a «امتیاز»
  segment to the calendar. Rating a day is one drag on `SpDailyScoreBar` — a progress-shaped bar
  whose track *is* the red→orange→green palette, filled to the value, thumb tinted by the value,
  mirrored in RTL so 0 is on the right — never a number field. A rated day shows its score on a
  wash of its own colour; an unrated day shows only the day number (no zero). Two charts, both
  hand-painted (no chart dependency): this month's line (monotone-cubic, x-spanned over the real
  month so gaps stay put, segments coloured by the values they join) and the monthly averages
  (one bar per month that has data). `TodayScoreTile` above the grid rates today in one tap.
- Storage is `yyyy-MM-dd` keyed Gregorian in a `MapStorage` (D-025), with `DailyScoreProvider`
  loading it once at startup; display-calendar grouping happens at read time.
- Tests: `test/providers/daily_score_provider_test.dart` (storage keys, tolerant decode, clamping,
  "unrated is null not 0", monthly grouping/limit, and the Shamsi mapping of 2026-11-15 →
  1405/8/24), `test/widgets/scores/sp_daily_score_bar_test.dart` (no `TextInput` on screen, ends
  report 100/0, every reported value inside 0..100, mirrored in RTL),
  `test/views/calendar/score/...` (a rated cell shows day + score, an unrated one shows one `Text`,
  gapped/single-point/RTL line charts paint, monthly bars are named in full), and
  `test/core/services/scores/daily_score_scale_test.dart` (the palette is red→orange→green, stays
  saturated, is monotone, and clamps).
- **Mistake, and its cost:** `17e84fe` added `enableDailyScore` to the `@CopyWith` object and used
  it immediately, but the generated `.g.dart` can only be produced by the Codegen workflow (no Dart
  in this sandbox). The branch tip was therefore unbuildable for ~10 minutes: CI said so (Analyze,
  one error, `43797852596`), and the user hit it locally first:
  `No named parameter with the name 'enableDailyScore'`. The generated file was fetched from
  `ci/codegen` (`43797852564`, 140s) and landed in `48694a9`. Rule learned: **never leave the tip
  depending on a generated file that is still in flight** — either push the field-free code, or
  trigger codegen on an earlier commit and merge the `.g.dart` before any code uses it.
- CI scoped to the change (D-032 / supersedes half of D-017): `bin/changed_tests` + a `scope` job
  publish `mode`/`build`/`shards`/`paths`; the test matrix is one shard for a scoped run and two for
  a full one, and a docs-only change starts no test job at all. Verified green on `48694a9`
  (`43798528975`): Scope 5s, Analyze 82s, Test (1) 162s, Test (2) 167s, Build 128s — Build only
  because that commit's *body* mentioned `[build]`, which is why markers are now read from the
  subject line alone.

### Incident — 2026-11-15: two calendars, and a cell that hid its own date (fixed in this round)
- User feedback: "I want my calendar to be one — emojis *and* the score in the main calendar. And
  the day number disappearing behind an emoji is wrong: keep the emoji, put the number in a small
  circle underneath, and pick the day's colour from its score."
- Both complaints were mine: the score add-on had introduced a second grid, and the mood cell had
  always replaced the day number with the feeling emoji, so a month of faces showed no dates at all.
- Fix (D-033): `SpCalendarDateCell` is now the only calendar cell — emoji/check in the middle, the
  day number in a small circle below it (ringed in the score's colour), and the whole cell tinted
  by the score. The add-on's grid is gone; its segment is «روند» (`ScoreTrendView`: today's rating,
  the month line, the monthly averages) and the app has one calendar again. Tap still selects a day
  (stories), long press now rates it, with a one-line hint in the trend segment until the first
  score exists.
- Tests: `test/widgets/calendar/sp_calendar_date_cell_test.dart` (a feeling day keeps *both* the
  emoji and the number, a check day keeps both, a plain day stays one `Text`, the tint appears only
  when rated, tap and long press stay separate with counts). The deleted
  `sp_score_calendar_date_cell_test.dart` went with its widget.
- Keys: `general.score` → `general.trend` (the segment is charts now) and a new
  `general.score_long_press_hint`; all 21 locale files kept in lockstep (621 keys).
- Two stumbles on the way, both caught by CI rather than by the user this time:
  `git mv` of `views/calendar/score` → `views/calendar/trend` left the package URIs *inside* the
  moved chart files pointing at the old folder (`Target of URI doesn't exist`, 13 analyze errors);
  swept lib/ and test/ for the old path (`af6d2ef`). And for two runs `actions/checkout` failed with
  `repository 'https://github.com/alireza-haeri/notely/' not found` in *every* job — not the code: a
  rerun went through and produced the real errors. When every job fails in ~30s at checkout, read it
  as infrastructure and rerun before changing anything.
- CI `43800211911` green on `af6d2ef`: Scope 5s, Analyze 74s, Test (1) 201s, Test (2) 165s (223s
  total, full suite via `[test]` — the scoped run is for the small follow-ups).

### 2026-11-16 — «قشنگتر»: motion, insets, and a score card over the day's stories (D-034)
- The calendar worked; it did not look deliberate. Three fixes, all of them the user could see:
  - **The trend segment was cropped by the sidebar.** `RootPagesMediaQuery` folds the 88pt sidebar
    into `padding.left/right`, and the segment's `ListView` ignored it, so the charts ran under the
    rail on a wide window. It now takes those insets (the mood segment already did, via its
    `SliverPadding`).
  - **Both charts appeared fully drawn.** Now they draw themselves: the line interpolates every
    point's height from the baseline (700ms, `easeOutCubic`), its wash fades with the same progress,
    and the dots land with a small `easeOutBack` overshoot after 45%; the monthly bars grow bottom-up
    with a stagger (750ms). Each tween is keyed on the *data*, so rating a new day replays the
    entrance instead of the chart sitting there with stale-looking numbers.
  - **The score tint snapped in.** `Container` → `AnimatedContainer` (`Durations.medium2`) with one
    stable key. The lesson is in D-034 §4: keying that container by state (`score == null ? null :
    ValueKey('score-tint')`) rebuilds it instead of animating it.
- New: a score card above the story list for the selected day — date, score (or "no score yet") and
  the day's tint, tapping which opens the same `SpDailyScoreSheet` the long press does. Gated on the
  add-on being on, absent on the "all stories" page. `SpScoreCallout` is the shared shell, and
  `TodayScoreTile` in the trend segment is now a thin wrapper around it (`lib/widgets/scores/`), so
  the two cards cannot drift apart.
- Tests: `test/widgets/scores/sp_score_callout_test.dart` (the number when rated, an add icon — never
  a `0` — when not, one tap opens the sheet, a long title ellipsises instead of overflowing, RTL,
  tint follows the score, out-of-range score is clamped); the chart tests now settle the entrance and
  assert the bars start at zero height and end at their real value.
- Stumbles, both caught by CI before the user saw anything: the new callout test bound `_borderColor`'s
  `Color?` to a `Color` (2 analyze errors, `5aa04f5`); everything else in the round — the chart tweens,
  the record-destructuring bar loop, the promoted `selectedDay` in the mood column — analyzed clean on
  the first try. Running it scoped (`mode=changed`, 4 test files, 1 shard) meant the failure came back
  in ~90s instead of ~3.5 minutes.
- CI `43801222059` green on the fix (`5aa04f5`…): Scope 4s, Analyze ✓, Test (1) ✓ (1m15s, 4 scoped
  files), 85s total. Formatting stayed advisory and still lists untouched files
  (`stories_box.dart`, `search_filter_object.dart`, …) — the CI formatter's tall style does not match
  the repo's existing formatting, so `bin/format` cannot be reproduced without a local SDK.

### 2026-11-16 — RTL palette, a real switch for the map, and an order for the sidebar (D-035)
- Four things the calendar got wrong in daily use, plus one new capability the user asked for:
  - **The score bar read backwards in Persian**: 100 was red and 0 green, while the thumb and the
    labels read forwards. Cause: the bar maps 0 to the right edge in RTL, but the ramp's ends were
    resolved by the ambient `TextDirection`, so one half of the widget described the opposite scale.
    `DailyScoreScale.gradient(rtl:)` now swaps its own ends and `SpDailyScoreBar` paints the ramp under
    an explicit LTR `Directionality` — the direction is the caller's statement, not the tree's
    (D-035 §1). Pinned by two unit tests on the ends plus one on the inner direction.
  - **Turning the score add-on off left the grid tinted.** `scoresByDay` is now empty unless
    `enableScores` is on, so tint, long press and day card switch off together (D-035 §2).
  - **The map is an add-on** (`AddOnType.map`, `enableMap`, on unless turned off). Off means: no
    sidebar item, no mobile timeline item, no map-provider setting, no `places`/`countries` stats, and
    in notes no location pin and no "add current location" (D-035 §3). Stored places are untouched.
  - **Sidebar order is a preference**: `SidebarItemId` + `sidebarOrder`, stored as names and repaired
    on read (`parse`: unknown dropped, missing appended), with a reorder screen in Settings that greys
    out (but keeps the slot of) items an add-on currently hides (D-035 §4).
  - **The 12px yellow-and-black strip** around the score card in a short window: a fixed-height
    sibling above a list that can shrink to zero. The card is skipped below 140pt of body height,
    where it would be the only thing on screen (D-035 §5).
- Tests: `test/core/types/sidebar_item_id_test.dart`, `test/widgets/side_items/side_items_test.dart`
  (stored order, map off, relax-sounds needs pro *and* the add-on, labels/icons from the ids), the
  gradient ends in both directions, and the bar's inner `Directionality`.
- Stumble worth remembering: the first commit added `AddOnType.map` while `toggleAddOn`'s switch still
  had no `.map` case — and that case could not be written until the regenerated `copyWith` existed, so
  the push went red on a non-exhaustive switch (`65d0763`, Analyze). The `.g.dart` landed in the very
  next commit (`411291a`) with the setters, and the tip has been green since. The rule: a new enum
  value and an exhaustive switch over it are one atomic change, so the regeneration has to be fetched
  *before* the enum grows, not after.
- CI `43803014131` green on `411291a`: Scope 6s, Analyze ✓, Test (1) ✓ in 2m31s over 40 scoped files,
  162s total. (`flutter test failed but the JSON reporter reported no failing test` is the same
  pre-existing annotation the previous green run carries; the job exits success.)
- Follow-up while auditing "not a trace of the map": the story-tile preferences sheet still offered a
  "show location" switch whose reader no longer draws anything. Hidden with the add-on (`cb7411e`),
  preference preserved. CI `43803391050` green: Scope ✓, Analyze ✓, Test (1) ✓ 1m53s, 123s total.

### 2026-11-16 — A local gate, and motion for the calendar (D-036, D-037)
- **`bin/dev -t`**: the loop no longer has to wait for CI. `-t` (also `--test`, and
  `-t full` for everything) is stripped before the flavor parsing and, instead of
  `flutter run`, runs analyze → `bin/changed_tests`' scoped tests → `flutter build linux
  --debug`, then prints one short report (a line per gate; analyzer errors, failing test
  blocks and compiler errors when something broke) with full logs in `bin/.tmp/verify/`.
  A dirty working tree falls back to the whole suite, because an uncommitted edit makes the
  scoper's selection a guess. Verified with a stubbed `flutter` on PATH: both the failing and
  the passing report render as intended, and `--community-linux -t` parses correctly.
- **Motion in the calendar (D-037)** — the mood segment did not animate at all:
  - the month grid now arrives row by row: one 420ms controller for the whole grid, each
    row an interval inside it, each cell faded + lifted 6pt with the cell passed as
    `AnimatedBuilder`'s `child` so it is not rebuilt per frame;
  - the month title in the app bar cross-fades and slides up when the grid pages under it,
    keyed on the label (not the widget);
  - mood ↔ trend ↔ period cross-fade instead of cutting;
  - the day badge grows 19→22pt and fills on selection, and the "today" ring thickens,
    both as `AnimatedContainer`s on the same widget rather than a swapped one;
  - the day's score card is wrapped in `AnimatedSize`, so selecting a day pushes the story
    list down over 200ms instead of in a single frame.
- Deliberately not animated: nothing loops (a repeating animation would fight the charts'
  data-keyed entrances from D-034 and hang every `pumpAndSettle`), and impulse curves stay
  in the charts where a dot landing is the point.
- CI for the round: `43803970360` green on `3a08255` (Scope 6s, Analyze ✓, Test 1 1m30s over the
  two calendar files the scoper picked, 136s total); `43804325119` green on `e96106b` (92s) — a
  `bin/` + `ai/` change correctly ran Analyze only and skipped the tests entirely (`mode=none`).

### 2026-11-16 — The first APK on GitHub Actions (D-038, D-039)
- `.github/workflows/android.yml` builds the `community` flavor when the commit subject carries
  `[apk]` (or by hand from the Actions tab) and publishes an `apk-<UTC date>-<sha7>` pre-release.
  Every secret-free build says so in its notes.
- Getting there took five failures, all recorded in D-039 because each one is a rule now:
  the wrapper was below Flutter 3.50.0's minimum (Gradle 9.2.0 → 9.3.1), AGP was below it too
  (8.11.1 → 9.1.1), AGP 9 makes `kotlinOptions { jvmTarget }` a compile *error*, AGP 9's legacy
  DSL rejects `resValue` (both strings are manifest placeholders now), and two runs were SIGTERMed
  at ~9 minutes because the Gradle/pub caches filled the runner's 14 GB `/` — they live on `/mnt`
  (70 GB) now.
- Measured: `43808298535` green, 18 minutes, 207 MB multi-ABI debug APK. After pointing the caches
  at `/mnt` and restricting to arm64: `43812916947` green, 17 minutes, **138 MB**, asset
  `storypad-community-debug-2.34.0+834.apk`, package `com.tc.writestory.community`, minSdk 24,
  targetSdk 36, `lib/arm64-v8a/libapp.so` present.
- Two papercuts found by reading the published release rather than the build: `gh release create
  <file>#<label>` keeps the *file's* name (the notes promised a name the asset did not have), and
  `gh release list --json` is not a flag this `gh` understands — the "superseded by" note on the
  older release was written twice because of it.
- Added a verification step: `aapt2 dump badging` + `apksigner verify` on the runner, asserted and
  re-emitted as annotations, since the artifact cannot be downloaded from this workspace to check
  it locally.
- Still manual, by nature: the release keystore (four `ANDROID_KEYSTORE_*` secrets) and installing
  the APK on a phone.

### 2026-11-16 — Local APK loop (`bin/build_apk`, `bin/android_doctor`)
- Added `bin/build_apk` (ABI-aware `--abi auto`, `--install`, `--compile-sdk=`, `--no-ndk` /
  `notelyNdkVersion=none`) and `bin/android_doctor` (pinned SDK/AGP/Gradle check, `dl.google.com`
  direct vs proxy probe, `--mirror` init script, `--fix` with `SDK_TEST_BASE_URL` mirror) up through
  `67bac3c` (build against the installed `android-<n>` platform instead of failing on missing `android-37`).
- Fixed two blockers hit on Fedora when running `emulator -avd storypad_dev &` + `bin/build_apk --install`:
  - `bin/build_apk` ran under `set -euo pipefail`, and `device_abi()` piped `adb shell getprop`
    without `|| true`, so whenever `adb` was present and 0 (or 2+) devices were attached,
    `DEV=$(device_abi)` aborted silently with exit code 1 before printing anything.
  - `emulator` and `adb` inside `$SDK/{emulator,platform-tools}` are normally not on `PATH` on
    Fedora; `bin/build_apk` now resolves both (and `FLUTTER_BIN` / `~/development/flutter_stable`),
    adds `--avd [name]` to boot and wait for `sys.boot_completed` automatically before ABI
    detection, and waits on `offline` devices before `--install`.
  - `bin/android_doctor` now resolves `$SDK/platform-tools/adb` too and parses `compileSdk` from
    the `?: 37` expression added in `67bac3c`.
- Fixed the Gradle 9.3.1 init-script compile error from `notely-google-mirror.gradle.kts` (which
  used Groovy-style `{ settings -> }` / `{ project -> }` lambdas in Kotlin DSL):
  - `bin/android_doctor --mirror` now probes Aliyun/Tencent/Huawei mirrors for AGP 9.1.1,
    `google-services:4.4.4` (both `.gradle.plugin` marker and JAR POM) and `crashlytics:3.0.6`,
    prefers 4/4 `200` mirrors (skipping Aliyun when it returns 502 on `.gradle.plugin`), writes
    Groovy `~/.gradle/init.d/notely-google-mirror.gradle` (rewriting `dl.google.com` in-place via
    `repositories.all` + mapping `google-services` and `crashlytics` via `eachPlugin`), removes
    `.gradle.kts`, and `bin/build_apk` guards against it and accepts `-v`/`--verbose`.
  - `bin/android_doctor --fix` resolves missing `platforms`/`build-tools` against `sdkmanager --list`
    (so missing `android-37` on a mirror falls back to `android-36`), skips the optional 1 GB NDK,
    and `bin/build_apk` warns when the local platform is below 36 (required by plugin subprojects).
- Fixed two Fedora build failures hit once Maven plugin resolution succeeded (`assembleCommunityDebug`
  hanging 5m34s at `android/build.gradle.kts:31` on `sdkmanager` exit 1):
  - **Flutter 3.50 `forceNdkDownload` NDK provisioning hang:** Flutter's Gradle plugin ignores
    omitted `ndkVersion` (AGP defaults to `28.2.13676358`) and invokes `sdkmanager --install
    ndk;28.2.13676358` unless `flutter.installedNdkVersions` contains that version. When
    `notelyNdkVersion=none`, `android/build.gradle.kts` now sets `flutter.installedNdkVersions` on
    `:app` (`extraProperties`) and `android/app/build.gradle.kts` sets the matching placeholder
    `ndkVersion` so `forceNdkDownload` returns immediately without running `sdkmanager` or
    injecting synthetic CMake.
  - **Minor SDK platform (`android-36.1`) selection:** `bin/build_apk` now detects `android-<N>.<M>`
    platforms alongside `android-<N>` (preferring `36.1` over `34`), passes `notelyCompileSdk` +
    `notelyCompileSdkMinor`, and `android/app/build.gradle.kts` + `android/build.gradle.kts` apply
    `compileSdkMinor` (via `com.android.build.api.dsl.LibraryExtension` on matching plugin
    subprojects) so AGP compiles against `platforms/android-36.1` instead of invoking `sdkmanager`
    for missing `android-36`.
- Verified in sandbox against stubbed `flutter`/`java`/`adb`/`emulator`/`sdkmanager`/`curl`
  (`bash -n`, `--help`, 0-device `--abi auto`, missing `PATH` tools, `--avd --install`, mirror
  502/200 selection, `android-34` + `android-36.1` platform selection + `--compile-sdk=36.1`,
  `notelyNdkVersion=none` + `notelyCompileSdkMinor` env forwarding) and committed/pushed at
  `d3d534e`. `Linux` CI (`43823502245`) passed full suite (`Scope` + `Analyze` + `Test (1)` +
  `Test (2)`).
- Live Fedora check (`bin/build_apk --install --avd=storypad_dev -v` on `d3d534e` with Tencent
  mirror):
  - Confirmed the 5m34s `:app` `sdkmanager` NDK hang was eliminated and all Maven/Kotlin dependencies
    cached in `~/.gradle/caches/` (initial cold fetch `33m 15s`; retry #1 reached `:jni` in `8.9s`).
  - Failed configuring subproject `:jni` (`NDK not configured. Preferred NDK version is '28.2.13676358'`)
    because transitive `jni` (`1.0.3`, brought in by `path_provider_android` `2.3.1`) genuinely builds
    `libdartjni.so` via CMake + NDK (`externalNativeBuild { cmake { path = "../src/CMakeLists.txt" } }`),
    while Fedora had neither `ndk` nor `cmake` installed.
- Fix applied: `bin/android_doctor` now marks missing NDK/CMake as `MISSING` when `jni` is in
  `pubspec.lock` and falls back to the best available `ndk;*` / `cmake;*` in the SDK mirror catalogue
  during `--fix`; `bin/build_apk` fails fast with `bin/android_doctor --fix` when NDK/CMake is missing
  for `:jni` and otherwise exports whichever valid NDK (`source.properties`) is on disk as
  `notelyNdkVersion`; `android/build.gradle.kts` forwards `notelyNdkVersion` to `:app`
  (`flutter.installedNdkVersions`) and `LibraryExtension` plugins (aligning `:jni`) and clamps
  `compileSdk` to `notelyCompileSdk`. Next step: run `bin/android_doctor --fix` and re-run
  `bin/build_apk --install --avd=storypad_dev`; then proceed to the lightweight phone build (`A-3`).

### Session 12 — Fedora/Android runtime logs: fixes (2026-11-16)

The user ran both commands from Session 11 on their Fedora 44 box and pasted the full
logs (`bin/dev --community-linux`, `bin/build_apk --install --avd=storypad_dev`). Both
worked — the app booted, loaded `fa`, rendered 11 stories in Shamsi `1405`, and synced
Google Drive — but the logs exposed seven defects. All are fixed on
`arena/446a6eb3-notely`; see `DECISIONS.md` D-050…D-052 for the two design-shaped ones.

| # | Symptom in the log | Cause | Fix |
|---|---|---|---|
| 1 | `MissingPluginException ... com.ryanheise.just_audio.methods`, twice per mounted voice note | `just_audio` 0.10.6 has no Linux backend; `SpVoicePlayer` built `AudioPlayer()` eagerly | `LinuxVoicePlayerBackend` (system CLI player) on Linux; `AudioPlayer` never constructed there (**D-050**) |
| 2 | Voice-note length shown as ~50 minutes right after recording | `sp_voice_recording_sheet.dart` passed `Duration(seconds: durationInMs)` | `Duration(milliseconds: recordingResult!.durationInMs)` |
| 3 | Voice-note progress bar filled from the left in Persian | `Positioned(left: 0)` | `Positioned.directional(textDirection: ..., start: 0)` |
| 4 | `The target platform "linux" is not yet supported by this package.` + `💫 App Update Status: null null` | `InAppUpdateProvider` probed Play/App Store on Linux | `PlatformCapabilities.storeUpdates` gate: the check is Android/iOS only, and is now skipped — not failed — elsewhere |
| 5 | Raw `{ALTERNATIVE_TO_URL, ..., RELAX_SOUND_FREE_SET_VARIANT, ...}` dumped on every start | `RemoteConfigService` printed every fetched key, including ones this build dropped | Filter to registered keys, log through `AppLogger.d` |
| 6 | `Everything is up to date` was followed by `Reload home from HomeViewModel#_listenToRestoreService` | step 3 reported "did import" while importing 0 records | `didImport = step3Result.data == true` (**D-051**) |
| 7 | `📂 Load SpStoryListWithQuery` logged twice on opening the mood calendar | the list watched the whole view model, which notifies when `DailyScoreProvider` finishes loading | `storyFilterNotifier` (**D-052**) |

Also, from the same two commands:
- `bin/dev` now resolves `$FLUTTER_BIN` / `~/development/flutter_stable` itself (the user
  had to prepend `PATH=`), and no longer prints the two-line "no codegen stamp" note when
  the committed generated files are present.
- `bin/build_apk --install --launch` launches the app after installing (the log ended with
  a hand-written `adb shell monkey -p ...`).
- `bin/setup_linux` no longer asks for `webkit2gtk4.1-devel` (nothing links WebKitGTK any
  more) and now reports which CLI player will play voice notes, with the `dnf` line when
  there is none.
- Video attachments on Linux/Windows: static tiles + "Open in the system player" instead of
  a `MissingPluginException` (`video_player` has no backend there either).
- `show_tag` / `throwback` `goToNewPage` only refresh when a story was actually saved.

Not fixed, on purpose: the `Gtk-WARNING ... 'border-spacing' is not a valid property name`
lines come from the user's GTK theme, and the Gradle 9.3.1 / AGP 9.1.1 / Kotlin 2.4.10
"will soon be dropped" warnings are genuine upgrade work (`BACKLOG`), not runtime bugs —
passing `--android-skip-build-dependency-validation` would only hide them.

### Session 13 — Emulator sign-in failure: it was DNS (2026-11-16)

The user tried to sign in to Google Drive inside `storypad_dev` on their Fedora box and got:

```
Sign-in failed: ClientException with SocketException: Failed host lookup:
'oauth2.googleapis.com' (OS Error: No address associated with hostname, errno = 7)
```

Diagnosis: the AVD had no usable resolver (the host resolves through systemd-resolved's
`127.0.0.53` stub, which the guest does not follow). Nothing was wrong with the OAuth
client, the account or the consent screen — but three layers of code turned a DNS failure
into an auth-looking screen, and the same failure could throw during app start-up.

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | Raw `ClientException with SocketException … errno = 7` shown as a sign-in failure | `GoogleDesktopOAuthService` let `package:http` transport errors escape; everything non-auth became `AuthException(signInFailed)` | one `_send` wrapper with a 30s timeout → `GoogleOAuthException(error: 'offline')`; strategy maps it to `NetworkException`, `BackupProvider` shows `snack_bar.no_internet` and marks the service `noInternet` (**D-053**) |
| 2 | Losing the account (or throwing out of `_initializeApp`) when the token refresh cannot reach Google | `restore()` rethrew, `_renew` → `_forget()` on any failure, `GoogleDriveCloudService.initialize` had no guard | offline keeps the stored account; `initialize` catches and leaves the account unauthenticated (**D-053**) |
| 3 | AVD has no working DNS and nothing said so | `bin/build_apk` booted the emulator with no `-dns-server` | `--dns-server=<ip>` / `NOTELY_DNS_SERVER`, a stub-resolver warning, and a post-boot `ping oauth2.googleapis.com` from the guest; `bin/local_verify` forwards the flag (§2.2c) |
| 4 | `Directory ../static/sources/story_backgrounds not found` then `err build_runner failed` | the artwork submodule is not checked out; the generator treated that as fatal | the generator skips and keeps the committed `lib/gen/story_backgrounds.dart` (**D-054**) |

To retry sign-in on the emulator:

```bash
bin/build_apk --install --avd=storypad_dev --dns-server=8.8.8.8
adb shell ping -c1 oauth2.googleapis.com     # must answer before the app can sign in
```

The remaining log noise (GTK `border-spacing` / cursor theme, Impeller, Gradle/AGP
deprecations) is unchanged and still benign or backlogged as noted in Session 12.

### Session 14 — Session 13 finished, and the AVD fixes its own DNS (2026-11-16)

Session 13's AI stopped right after its commit (`15b28ac`); the code, the tests and the
`ENVIRONMENT.md` section were in, but `PROGRESS.md` still said "session 12", `NEXT.md` was
written before the DNS finding, and `CHANGES.md` had no entry. This session finished that
bookkeeping and closed the one real gap left in the fix.

| # | Gap after `15b28ac` | Fix |
|---|---|---|
| 1 | The AVD only got a working resolver if a human remembered `--dns-server=8.8.8.8` | `bin/build_apk` reads the stub-resolver state and passes the host's real upstream (`resolvectl dns`, else `8.8.8.8,1.1.1.1`) automatically; `--dns-server` still wins, `--no-dns-server` opts out (**D-055**) |
| 2 | An AVD started from Android Studio can never be repaired by a boot flag, and its broken DNS surfaces minutes later as a "sign-in failure" | after `--install`, an attached emulator (`ro.kernel.qemu=1`) that cannot resolve `oauth2.googleapis.com` is reported with the exact one-line recovery (`adb -s <serial> emu kill && bin/build_apk --install --avd=<name>`) |
| 3 | Docs were half-updated after the crash | `NEXT.md` rewritten to the two questions that are actually open, `CHANGES.md` §8 tells session 13's story, `notes/user-instructions.md` N-021, `ENVIRONMENT.md` §2.2c documents the automatic behaviour, `D-055`, handoff snapshot refreshed |

**What the app does now** (unchanged by this session, worth restating because it is what you
will see): with no network, sign-in says "No internet connection!" instead of printing
`ClientException … errno = 7`, the stored Google account is *not* thrown away when a token
refresh fails offline, and app startup cannot fail because Google is unreachable.

**Verification** — `bash -n bin/build_apk`, the new `host_upstream_dns` helper against a fake
`resolvectl` (stub + link + IPv6 line → `192.168.1.1,1.1.1.1`) and against a `PATH` with no
resolver tool at all (empty output, no `set -e` abort), then the whole script against stubbed
`flutter`/`java`/`adb`/`emulator`/`resolvectl`:

| Scenario | Observed |
|---|---|
| stub-resolver host, `--avd` | `emulator -avd storypad_dev -dns-server 192.168.1.1,1.1.1.1` |
| same, `--no-dns-server` | `emulator -avd storypad_dev` (no flag), message says so |
| same, `--dns-server=9.9.9.9` | `-dns-server 9.9.9.9` — the explicit flag wins |
| booted AVD that still cannot resolve | `still cannot resolve oauth2.googleapis.com … --dns-server=1.1.1.1` |
| already-running emulator, broken DNS, no `--avd` | `adb -s emulator-5554 emu kill && bin/build_apk --install --avd=storypad_dev` |
| already-running emulator, healthy DNS | silent (no false alarm) |

No Dart/Flutter in the sandbox, so nothing app-side was rebuildable here; the test suite you
run is the proof.

### Session 15 — The first real sign-in attempt: the AVD resolves Google to a fake IP (2026-11-16)

The user ran `bin/build_apk --install --avd=storypad_dev` on the branch, installed on
`emulator-5554`, and tried to sign in. Result, in order:

1. **The old failure is gone.** No `Failed host lookup`, no raw `ClientException`.
2. The browser opened and the Google account was accepted.
3. The app then said **"No internet connection!"** — the translated
   `snack_bar.no_internet`, i.e. `BackupErrorType.network` (D-053) working as designed.
4. `adb shell ping -c1 oauth2.googleapis.com` → **`198.18.0.60`, ttl 255, 1.05 ms**, and
   Chrome is installed (`com.android.chrome`).

**Diagnosis.** `198.18.0.0/15` is the benchmarking range that Clash/mihomo-style proxies use
as their default fake-IP pool, and `ttl 255 / 1 ms` says the answer came from the local
fake-IP layer, not from Google. So: the redirect and the loopback callback worked (that is
why the app got as far as the token exchange), and the **token exchange** is the call that
died — the system resolver handed `dart:io` a fake address. Chrome succeeded because it
resolves through its own secure DNS, bypassing the host's fake-IP answers.

The AVD could not be repaired automatically because it was **already running** when the build
started (D-055's limit), and D-055's health check did not notice anyway: it only asked
whether `ping` exited 0, and a fake-IP layer answers ICMP itself.

**Fixed here (tooling only — the app needed nothing):** `emulator_dns_verdict` classifies the
resolved address (`ok` / `fake` / `unresolvable`) and `explain_dns_verdict` prints the
remedy for each case: proxy `fake-ip-filter`/`redir-host`, the guest's Private DNS setting
(no reboot), or an explicit `--dns-server` (**D-056**). Verified against a stubbed `adb` in
all three cases.

**Open, and it is on the network side, not in Dart:** the guest must resolve Google to a real
address before a successful sign-in is possible. `NEXT.md` §1 lists the three ways, cheapest
first.

**Addendum (session 15, after the sign-in attempt):** the user asked how to get the APK onto a
real phone. The answer is now `ENVIRONMENT.md` §2.2e, because the trap is easy to miss: the
ABI defaults to *whatever is attached*, so a build made next to the emulator is `x86_64` and
a phone rejects it with `INSTALL_FAILED_NO_MATCHING_ABIS` — the artifact name
(`app-community-debug.apk`) says nothing about the ABI.

### Session 16 — "Can the final app be lighter?" Measure, then cut the build type (2026-11-16)

`--abi all` produced **238 MB**, and the honest answer is that almost none of it is features:
`assets/` is 2.0 MB, `translations/` 920 KB, committed `.g.dart` 344 KB. What the number
contains is four copies of the Flutter engine (one per ABI), a Dart **kernel snapshot** with
no AOT code, no minification, and ~40 plugins' Java/Kotlin. `ANALYSIS.md` §4 had already
predicted this; what was missing was a way to *prove* it on this machine without spending an
afternoon.

| Added | What it answers |
|---|---|
| `bin/apk_report [apk]` | where the megabytes are: grouped by `lib/<abi>` / `dex` / `res/` / `assets/flutter_assets/` (Dart) / `assets/` (app files), plus the biggest files, a **debug-only total** (kernel snapshot + Vulkan validation layer) and the ABI count |
| `bin/build_apk --release --sign-debug` | a real release build signed with the existing `~/.android/debug.keystore`, so the size question is answerable today without creating a keystore |
| R8 + `isShrinkResources` for release | removes unused Java/Kotlin + resources that Dart's AOT tree-shaking cannot see (`-PnotelyMinify=false` is the documented escape hatch) |
| `--split-debug-info=build/symbols` | keeps the Dart symbol table out of the APK (it is only needed by `flutter symbolize`) |
| `--abi arm64/arm/armv7` | **bug fix:** the values `--help` advertises fell through to `unknown --abi` |

**Measured on the user's Fedora box** (`bin/apk_report` on the real artifact, 2026-11-16):

| Group | Unpacked | Share | Notes |
|---|---|---|---|
| `assets/flutter_assets/` | 158.7 MB | **48.9%** | of which `kernel_blob.bin` **142.2 MB** and `isolate_snapshot_data` 11.1 MB — the Dart VM's snapshot, debug-only |
| `lib/arm64-v8a` | 53.8 MB | 16.6% | engine ×1 of 3, incl. `libVkLayer_khronos_validation.so` **15.0 MB** (debug-only) |
| `lib/x86_64` | 39.7 MB | 12.2% | a second engine for a phone that has none |
| `dex` | 37.2 MB | 11.5% | four `classesN.dex`, R8 has not touched them |
| `lib/armeabi-v7a` | 32.8 MB | 10.1% | a third engine |
| app assets (`assets/`) | ~2 MB | 0.2% | the pictures and fonts everyone blames: 0.2% |

The APK was 237.3 MB on disk / 324.6 MB unpacked; 3 ABIs, not 4.

Expected ladder — 237 MB (debug, 3 ABIs, measured) → ~120 MB (debug, 1 ABI, measured earlier)
→ roughly 25–40 MB (release, 1 ABI, R8; **expectation**: `kernel_blob`, the snapshots and the
Vulkan validation layer all disappear, three engines become one, and R8 shrinks 37 MB of dex). The first number is a *measurement*, the last is an
*expectation* until someone runs it: no SDK here, so `--release` is unverified in the sandbox,
which is exactly why `-PnotelyMinify=false` exists.

**Verification:** `bash -n` on both scripts; `bin/apk_report` exercised on a synthetic APK with
four ABIs, `dex`, `assets/` and empty directory entries; `bin/build_apk` against stubbed
`flutter`/`java`/`adb`/`emulator` for the ABI aliases (7 values + one invalid), the
release-without-keystore message, `--sign-debug` (debug key exported, warning printed),
`--split-debug-info` reaching Flutter, and `--target-platform=android-arm64` for `--abi arm64`, and `-Pname=value` in both spellings
(`-Pfoo=1` / `-P foo=1`) with two rejection cases.

### Session 17 — Phone sign-in hangs on the loopback redirect address (2026-11-16)

Reported: on the **phone**, after choosing the Google account, Chrome sat on
`http://127.0.0.1:44399/?state=…&code=4/0AUn6…&scope=…` and never finished. That URL is the
app's own loopback server, and it was not answering.

**Cause (a real ordering bug, not a network problem):** `authenticate()` bound the HTTP
server, opened the browser, and only then called `_awaitRedirect` — which is what attaches
`server.listen`. A redirect arriving in that window is accepted by the kernel (so Chrome shows
a spinner rather than an error) and then waits with nobody to serve it. The emulator never
showed this because its Chrome was cold; a phone with a warm browser and an account one tap
away sends the redirect almost immediately.

| Change | Why |
|---|---|
| listener attached **before** `_openBrowser`, `_awaitRedirect` → `_listenForRedirect` | the redirect can arrive while the tab loads |
| `redirectTimeout` timer starts only once a browser exists | a failed launch no longer leaves a 5-minute timer running |
| `AppLogger.d` per loopback request (`code:`, `error:`, `alreadyCompleted:` — never the code) | separates "never reached the app" from "reached it and failed", from a logcat |
| two tests that redirect from inside `openBrowser`, via a raw socket | the first deadlocks under the old order; `HttpClient` would have been answered by `flutter_test`'s HttpOverrides with 400 and hidden the bug |

**Honest limits:** if the phone *freezes* the app while the browser is foreground (some OEMs)
or its VPN refuses loopback, no ordering fix helps — the log line will say no request ever
arrived, and the remedy is a paste-the-URL fallback that is not written yet.

### Session 18 — Release size measured: 237 MB → 40.5 MB (2026-11-16)

The user's first release build on Fedora, `bin/build_apk --release --sign-debug --abi arm64`:

| Artifact | Size | Note |
|---|---|---|
| debug, 3 ABIs (previous) | **237.3 MB** | 168.2 MB of it debug-only payload |
| release, ≈1 ABI (this build) | **40.5 MB** | 5.9x smaller; `libapp.so` 14.9 MB, engine 10.8 MB, dex 5.6 MB after R8 |
| release, strictly 1 ABI (expected next) | ~36 MB | the remaining `x86_64` + `armeabi-v7a` ObjectBox JNI libs (`D-059`) |

`bin/apk_report` on the release build also confirmed the tooling works on a real artifact:
it reported the leftover ABIs, which is what produced `D-059` (Gradle `abiFilters`). R8 did
not need any keep rule — `proguard-rules.pro` is still just the line-number attributes.
Tree-shaking of the three icon fonts also showed up in the log (99.7% / 99.6% / 98.9%).

**Open at the time of writing:** the release APK was built from `a7a7def`, i.e. **before**
`D-058`; the phone sign-in fix still has to be rebuilt and tried on the device.

### Session 19 — Phone sign-in: the fallback that always works (2026-11-16)

The phone still parked Chrome on `http://127.0.0.1:33509/?code=…` after `D-058`. Two facts
came out of that round, and both are recorded rather than argued:

1. **The retest was not a retest.** `bin/build_apk --install --abi arm64` printed
   `nothing attached` — the phone was not visible to `adb` — so the build with `D-058` was
   never installed. (The `--install` message now says how to fix that: USB debugging, the
   on-device prompt, and `adb devices` showing `device`, not `unauthorized`.)
2. **Even a correct ordering cannot cover every device.** An OEM that freezes background apps
   the moment the browser comes forward, or a phone-side VPN owning the routing table, can stop
   the redirect from ever arriving. The user then holds a valid `code` in an address bar and
   has nowhere to put it.

So `D-060` adds the escape hatch: after 12 s without a redirect, the app offers a dialog with
one text field ("paste the address from the browser"). It races the loopback server — whichever
arrives first wins — and the pasted address goes through the same `state` / `no_code` checks as
a real redirect. A cancelled dialog does not abort anything; the loopback keeps waiting.

**Verification (this is the round where CI is the judge):**
- three new tests for the fallback (pasted address succeeds; no code → `no_code`; foreign
  state → `invalid_state`) plus the two `D-058` tests that redirect from inside `openBrowser`;
- `Linux` CI on this commit — `[full]`, so Scope/Analyze/Test 1/Test 2/Editor package
  tests/Build Linux desktop/Coverage all run. The run id is appended below once it lands.

**CI — the whole suite on the final commit (`962b70a`, dispatched full run `43879483211`):**

| job | result |
| --- | --- |
| Scope | ✅ |
| Analyze | ✅ 0 errors, *All Dart files are formatted* |
| Test (1) / Test (2) | ✅ 51 + 51 files (full suite, every test file) |
| Coverage | ✅ 4198/27113 lines (15.5%) |
| Build Linux desktop | ✅ |

Getting there took two CI rounds, and that is the part worth remembering: the first run
(`43878322378`) failed with **`Undefined name 'io'`** (the new test called `io.Socket` in a file
that imports `dart:io` unprefixed) and **`Future<Object>` cannot be assigned to `Future<Uri>`** (a
`Future<void>` prompt whose value came back as `void` inside `then<Uri>`). Neither could have been
found in the sandbox — there is no Dart SDK here — which is exactly why the user's "test with CI"
was the right call. Fixed in `8eddb61`; the scoped run `43879014732` then went green, and the
full dispatch above is the final word.

### Session 19b — the device log finally spoke (2026-11-16)

The retest was real this time: `adb devices` showed `R5CWC1S4P0W device`, `bin/build_apk
--install --abi arm64 --launch` printed *Installed and launched*, and logcat has exactly one
line from the flow:

```
Google sign-in: waiting for the loopback redirect on 127.0.0.1:41185
```

while the browser showed Firefox's **"The connection has timed out"**. Nothing else — no
`loopback request` line at all. Read literally:

- the app did start a loopback server and did hand a URL to the browser (the line exists);
- Google *did* redirect (the browser ended up on a page it could not load);
- **the browser's request never reached the app**, and it was a *timeout*, not "connection
  refused", so something between the two processes swallowed it. Two candidates remain, and
  both are device-level: the OEM/app freezer pausing this process while the browser is
  foreground, or the phone's proxy/VPN (the same setup that produced the `198.18.0.60` fake-IP
  DNS) intercepting `127.0.0.1`. Neither is fixable from inside the app.

So `D-060` is not a workaround for a bug — it is the only path that survives this class of
device. One line was added at the 12 s mark (`no redirect after 12s — offering the manual
fallback`) because "the dialog never appeared" and "the dialog appeared and nobody looked" were
indistinguishable in logcat.

The dialog also prefills from the clipboard when what the user copied is a loopback
address (`http://127.0.0.1…`), so the step is: copy in the browser → switch back → Confirm.
Anything else on the clipboard is ignored — pasting a note's text into that field is a
mistake, not an instruction.

`D-061` came out of the same round: the CI run for `4c03e62` changed the OAuth service and
selected only two backup tests, because the scoper's mirror rule is a directory rule and the
OAuth test sits one level above its mirror. A green run that never loaded the relevant test is
worse than a red one. Fixed and verified locally by running `bin/changed_tests --files …`.

### Session 20 — Full settings backup and Persian-first defaults (2026-11-19)

- **Implemented:** serialize `DevicePreferencesObject` and selected locale into a reserved
  record in the existing global `preferences` database table. Existing full-backup and
  Google Drive sync paths therefore carry the settings. Restore applies the snapshot locally;
  first sync seeds legacy local settings only after importing remote data, avoiding default
  settings overwriting an existing cloud snapshot.
- **Fresh-install defaults:** Persian language, Persian calendar, Friday weekend, Saturday
  week start, and Daily Score enabled. Explicitly saved Daily Score `false` remains respected.
- **Rule from user:** commit and push each completed requested task to the active branch before
  reporting completion; captured in `ai/RULES.md` and `ai/notes/user-instructions.md`.
- **Verification:** `git diff --check` passed. Flutter/Dart tests and formatting could not be
  run because the SDK is absent from this sandbox. User-side Debug build and Google Drive
  cross-device restore remain to be exercised.

### Session 21 — Gender selection and matching illustration (2026-11-19)

- **Implemented:** first-run onboarding requires woman/man selection, shows the corresponding
  existing illustration, and updates the in-app logo. Settings can change the choice later.
- **Sync:** gender is a normal `preferences` table record (id 5), so existing global/full backup
  and Google Drive sync import/export it; restore refreshes the app's local illustration.
  Gender is not logged to analytics; the community launcher icon remains unchanged.
- **Tests/checks:** added pure mapping/parsing tests. Translation JSON parses and `en`/`fa` key
  sets match (494 each); `git diff --check` passes. Flutter tests/analyzer/formatter unavailable.
