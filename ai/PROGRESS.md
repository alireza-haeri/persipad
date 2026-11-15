# Status

**Last updated:** 2026-11-15
**Current session:** session 9 — Persian font bundled + calendar settings (weekends, first day)
**Branch:** `arena/f59917e7-notely` (base: `a0d9f727` on `main`)
**Phase:** 🟢 fresh clones run again; CI green (Test / Analyze / Build Linux)

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

- [ ] You pull, run `bin/setup_linux` + `bin/dev --community-linux`, and try adding a photo
      and a video to an entry (the flows that used to fail on the desktop).

## ⏳ Remaining (roadmap)

### Phase 1 — verify
- [ ] CI green on `arena/f59917e7-notely`.
- [ ] You run `bin/setup_linux` + `bin/dev --community-linux` and confirm: all Pro
      features present, Drive tile explains itself, Dropbox/Nextcloud connectable.

### Phase 2 — remaining Linux gaps (see BACKLOG I-11…I-16)
- [ ] Reminders/notifications on Linux (needs an app-side scheduler).
- [ ] Photo picking on Linux (verify `file_picker` path).
- [ ] Decide on Google Drive via loopback OAuth, or drop the Drive idea for Linux for good.

### Phase 3 — first real feature / personal redesign
- [ ] Pick from `BACKLOG.md`; the redesign list is still yours to write.

### Parked (do not work on)
- Android builds/Gradle, camera, quick actions, video compression, biometrics.
- macOS / Windows / iOS entirely.

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
| Dart files (lib + packages) | 983 (+2 new services) |
| Active platform targets | **1** (Linux desktop) |
| CI on a plain push | 1 job (Analyze, ~2 min); `[test]`/`[build]`/`[full]` add more |
| Tests added by us | 30 |
| Existing tests | 92 + 57 (editor package) |
| Pro feature gates opened by one switch | ~30 call sites |

## 🧾 Test log

| Date | Task | Verified by | Result |
|---|---|---|---|
| 2026-11-15 | Base app runs as Linux desktop on Fedora | you | ✅ runs; ObjectBox + features work (N-006) |
| 2026-11-15 | Dep bumps + `bin/dev --community-linux` + `bin/setup_linux` | you | ⏳ pending |
| 2026-11-15 | Pro unlock + capability layer + CI | GitHub Actions | ✅ Test + Build green (run 43712927893) |
| 2026-11-15 | Desktop media picking (`file_picker`) | GitHub Actions | ✅ all three jobs green (run 43716086122) |
| 2026-11-15 | Formatting | GitHub Actions | ✅ "All Dart files are formatted" |
| 2026-11-15 | Bundled font + calendar settings (weekends, any first day) | GitHub Actions | ✅ Analyze 80s, Test ×2, Build Linux — run 43727580987 |
| 2026-11-15 | Shamsi display mode (list grouping, chips, dates, year scope) | GitHub Actions | ✅ Analyze 84s, Test ×2 — run 43731618364 |

> ⚠️ I cannot run `flutter analyze` / `flutter test` in my sandbox (no SDK, pub.dev
> blocked). CI is the verifier now — see D-013. Nothing is "done" until it is green.

### What to run now

```bash
bin/setup_linux                        # only if dependencies changed
bin/dev --community-linux              # run the app
```
Then check: Settings → Data & Backup (Drive should explain itself, Nextcloud/Dropbox
should connect), any previously locked feature (fonts, backgrounds, templates, stats,
markdown export) should now just open.

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
