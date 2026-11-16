# Backlog & ideas

Labels: `💡 idea` (undecided) · `⏸ awaiting decision` · `🔜 next` · `🚧 in progress` · `✅ done`

> Nothing in this list starts without your approval. The point of this file is to keep
> options visible, not to commit to them.

## 0. Linux infrastructure (the only active platform)

| # | Item | Why |
|---|---|---|
| I-1 | `✅` Add `--community-linux` to `bin/dev` (+ `bin/setup_linux`) | Done — see D-010 |
| I-2 | `✅` `bin/check` = format + analyze errors + test | Local pre-push gate, same policy as CI |
| I-3 | `💡` Detect plugins that are no-ops on Linux and show a clear UI message | Linux users currently just see "it doesn't work" |
| I-4 | `💡` Review `GoogleDriveLinuxCloudService` (loopback OAuth) | The most important backup path on Linux |
| I-5 | `💡` Linux coverage: `flutter test` + check `Platform.isLinux` in new code | Prevent regressions |
| I-6 | `💡` Gradually remove dead macOS/iOS branches from shared flows (without deleting platform code) | Reduces complexity |
| I-7 | `✅` Clear UI messaging for features that are unavailable on Linux | Done for cloud sync via `PlatformCapabilities` (D-012); other features below |
| I-8 | `💡` Decide the Linux backup story (local export + folder backup) since Drive sync is unusable there | Data safety is the one thing we should not hand-wave |
| I-9 | `✅` `bin/check` covers this | See I-2 |
| I-10 | `✅` CI on GitHub Actions | `linux.yml`: Test + Build Linux + advisory Analyze (D-013) |
| I-11 (done, D-019) | `✅` Google Drive on Linux via loopback OAuth (own client ID + PKCE) | Implemented in `GoogleDesktopOAuthService` + `GoogleDriveLinuxCloudService`; needs user credentials (`bin/setup_sync`) to test E2E |
| I-12 | `🔜` Reminders on Linux | `local_notification_service` excludes Linux (`supported`), and the Linux notification backend has no scheduling support — needs an app-side scheduler to be honest about it |
| I-13 | `✅` Media picking on Linux/Windows via `file_picker` | Video and multi-select were `UnimplementedError` (D-015) |
| I-14 | `💡` Biometrics on Linux | `local_auth` unsupported; PIN lock already covers it. Probably leave as-is |
| I-15 | `💡` Camera / quick actions / video compression | Android-only; keep guarded, don't pretend they exist |
| I-16 | `✅` Add a Persian (fa) locale | Done — `translations/fa.json`, D-022 |
| I-17 | `✅` Bundle an Arabic-script font (persian text looks the same on every OS) | Done — Vazirmatn, D-023 |
| I-18 | `✅` Any first day of week + user-defined weekend days | Done — D-024 |

## 0a. Android build & mobile track

| # | Item | Why |
|---|---|---|
| A-1 | `✅` CI APK workflow (`.github/workflows/android.yml`) | Builds arm64 `community` APK on `[apk]` commit subject + publishes pre-release (D-038, D-039) |
| A-2 | `✅` Local Fedora APK loop (`bin/build_apk` + `bin/android_doctor`) | Handles offline `dl.google.com` via Tencent/Huawei Maven mirror, `android-36.1` minor SDK, `--no-ndk` `forceNdkDownload` bypass, and `--avd` (D-040) |
| A-3 | `🔜` **Lightweight mobile (phone) build** | User goal (N-015): trim heavy/unused modules or dependencies to produce a lean, fast phone APK once the first local Fedora build is verified; scope & feature cuts pending user decision |

## 0b. Calendar (the Persian-calendar track)

| # | Item | Why |
|---|---|---|
| C-1 | `✅` Shamsi (Solar Hijri) as the **displayed** calendar — reading flow | Storage/query stay Gregorian, display converts; see D-025 |
| C-1a | `✅` Story list grouping + month chip + monogram day | Grouped by `CalendarDisplay.monthKeyOf`, so Azar 1405 starts a new header mid-November |
| C-1b | `✅` "Months with stories" tab bar | Derived from the loaded stories in Shamsi mode (all pages are prefetched) |
| C-1c | `✅` Full dates + home year scope | `DateFormatHelper` switches internally; a Shamsi year becomes a `date_range` query |
| C-1d | `✅` Mood/period calendars in the display calendar | Grid, header, month picker, day numbers, feelings and period events all follow `CalendarDisplay`; both event tables and the story lists query exact day ranges (D-028) |
| C-1e | `✅` Settings tile (calendar system) | Settings → Region → Calendar System |
| C-1f | `✅` Year filters in the display calendar | Archive/tag/year-picker tabs and the search filter chips show and filter by display years; `CalendarDisplay.yearsFilter` turns them into Gregorian years + exact day ranges (D-027) |
| C-1g | `✅` Stats screen in the display calendar | `StatsRange` snaps to display months/years (start/end/years/labels), tabs and trend bars count display months, year picker lists display years, queries use exact day ranges (D-029) |
| C-1h | `✅` Month recap tiles in Shamsi | Groups by `CalendarDisplay.monthKeyOf`, counts active days by display day and scores against the display month's length, so the tiles are shown (and correct) in both calendars |
| C-1i | `✅` Persian month names are never abbreviated | `monthName(short: true)`/`MMM` return the full name (آبان) in the display calendar while Latin months keep `Aug`; the timeline month chip grows around the rail instead of squeezing the name (D-030 §4) |
| C-1j | `✅` RTL pass: arrows, timeline rail, sidebar, drawers, caret buttons, Shamsi picker | Reading-order chevrons, direction-aware timeline dividers, mirrored root sidebar + insets, drawers that keep their own safe area, caret buttons that act on the side they show, and a Material-shaped Shamsi date picker (D-030) |

## 1. Product features (candidates)

Generic journaling-app ideas; your preferences set the priority.

| # | Idea | Value | Rough cost |
|---|---|---|---|
| F-1 | Smart daily template (prompt suggested from date/weather/history) | high | medium |
| F-2 | Local Markdown file binding (a folder on disk, Obsidian-compatible) | high (especially Linux) | medium |
| F-3 | Better global search: fast tag + feeling + date-range filter UI | medium | low |
| F-4 | Writing stats: streaks, word counts, yearly graph | medium | low |
| F-5 | Time-based auto lock (lock after X minutes) | low | low |
| F-6 | Device-to-device sync without a cloud (Syncthing/WebDAV) | high | medium |
| F-7 | Beautiful PDF export with themes | medium | medium |
| F-8 | Quick-capture widget for Linux/Android | medium | high |
| F-9 | Focus mode (full screen, no chrome) | low | low |
| F-10 | Smart reminders based on the user's writing habits | medium | medium |

## 2. Observed tech debt

| # | Item | Note |
|---|---|---|
| T-0 | `objectbox 6.0.0-preview.6` is a preview release we now depend on | Revisit when 6.0.0 stable ships (D-009) |
| T-6 | `✅` Committed generated code refreshed | Regenerated on a real toolchain via the `[codegen]` marker, published to `ci/codegen`, reviewed and merged (D-016) |
| T-7 | Formatting gate is advisory | It is green now; flip `continue-on-error` off in `linux.yml` once it stays green for a couple of runs |
| T-8 | True multi-select on the desktop | Needs the correct `file_picker 13` multi-select API; current code degrades to a single file dialog |
| T-1 | ~1013 Dart files without feature-based layering | Hard to discover things; a big refactor isn't wise right now |
| T-2 | Committed `*.g.dart` files | Model/codegen mismatch risk |
| T-3 | `bin/docs` points to a `docs/` folder that doesn't exist in this version | Dead reference |
| T-4 | Two separate Google Drive paths (standard + Linux) | Duplicate-bug risk (see D-021 for why Android must also align on OAuth client if Drive sync is shared) |
| T-5 | `.github/workflows/ci.yml` comes from upstream, targets `develop`, and assumes an Android-era setup | Same as I-10 |
| T-9 | `🔜` Editor package's 390 tests never run (CI + `bin/changed_tests` ignore `packages/**`) | The persisted content format is the most dangerous area and its suite is switched off — see `ANALYSIS.md` §1 |
| T-10 | `🔜` No tests for backup merge decisions (`restoreOnlyNewData`, latest-checker, backup file versions) | The one bug class that silently loses notes; pure logic over two timestamps — see `ANALYSIS.md` §2 |
| T-11 | `⏸` Search: linear `contains` scan on an unindexed field, reindex attempted on every open, no search tests | Split: cheap `SearchFilterObject`/`buildQuery` tests now, search quality later behind a decision — see `ANALYSIS.md` §3 |
| T-12 | `⏸` Theme fonts are fetched over the network at first use (`GoogleFonts.getTextTheme`, no bundling, `kDefaultFontFamily = 'Quicksand'`) | Contradicts offline-first; bundle the offered families and set `allowRuntimeFetching = false` — see `ANALYSIS.md` §5 |
| T-13 | `💡` Android workflow has no `paths-ignore`; docs pushes still occupy a run slot and can cancel an `[apk]` build (D-039) | Mirror `linux.yml`'s `ai/**`/`*.md` ignore |
| T-14 | `💡` No coverage reporting on any active workflow | `--coverage` + lcov artifact on `[full]`; no threshold enforcement |
| T-15 | `💡` Essentially no `Semantics`/`Tooltip` on our own custom widgets (calendar cell, score bar, story rail) | Cheap accessibility win in exactly the places Flutter cannot guess for us |

## 3. Open questions

1. Product name — `notely`, or keep StoryPad?
2. Keep the Pro/paywall or unlock everything? (On Linux IAP doesn't work at all, so a
   gate would be dead weight there.)
3. 21 languages, or just fa/en?
4. Should we add an `upstream` remote for future updates?
5. How aggressive should we be when building the **lightweight phone version** (A-3 / N-015):
   which heavy plugins/features (Maps, Firebase/Crashlytics, RevenueCat/IAP, Video/Audio,
   Relax Sounds, unused locales, etc.) can be trimmed vs kept?
   — **Measured input for this is `ANALYSIS.md` §4:** the APK's size is a *debug build* problem
   first (release signing is the biggest lever), and the genuinely removable set is small
   (`cloud_firestore`, `google_maps_flutter_ios_sdk10`, `cupertino_icons`, the paywall/review
   surfaces). Maps/audio/relax-sounds are features, not fat.

## Sync roadmap after D-021

| Id | | Item | Why |
|---|---|---|---|
| I-12 | `🔴` | Verify Nextcloud sync against the **official** phone app (same account, same folder) | the only path-based provider both apps already support — this is the realistic phone↔desktop bridge |
| I-13 | `🟡` | Android build that reuses the **desktop** OAuth client id (loopback flow, not `google_sign_in`) | only then do our own devices share one Drive appDataFolder (D-021) |
| I-14 | `🟡` | One-time migration flow: import a phone-exported JSON, then let Drive take over | existing notes must not be stranded on the old app |
