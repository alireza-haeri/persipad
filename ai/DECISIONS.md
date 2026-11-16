# Decision log (ADR)

Every meaningful decision gets a numbered block. Superseded decisions are never
deleted — they are marked `superseded by D-0XX` so the reasoning trail survives.

Template:

```
## D-00X — Title (YYYY-MM-DD)
- Status: accepted / pending / rejected / superseded by D-00Y
- Context: why this decision was needed
- Decision: what exactly was chosen
- Consequences: what gets easier / harder
```

---

## D-001 — Base project is a fork of StoryPad v2.34.0 (2026-11-15)
- **Status:** accepted
- **Context:** You liked StoryPad and want to build on top of it.
- **Decision:** The whole of `theachoem/storypad` (commit `cffda48`, version
  `2.34.0+834`) was copied into `alireza-haeri/notely`. **The upstream git history
  was not imported** — only files — so our repo history stays clean.
  The upstream reference is recorded in `ai/` instead.
- **Consequences:** Pulling upstream updates isn't trivial (needs diffs). We can add
  an `upstream` remote later — see D-002.

## D-002 — Relationship with upstream (2026-11-15)
- **Status:** accepted (revisitable)
- **Context:** We may later want to cherry-pick new features from the original project.
- **Decision:** No `upstream` remote for now; we treat this as an **independent fork**
  so we can change things freely without merge anxiety. When we need it, a new
  decision adds the remote.
- **Consequences:** Our code can drift from upstream; future merges get harder.

## D-003 — Platform scope: Linux + Android (2026-11-15)
- **Status:** superseded by D-007
- **Context:** You said: "for now I'm focused on Linux and Android; macOS and Windows
  are not a concern."
- **Decision:** Android is first-class, Linux is second-class but supported.
  macOS / Windows / iOS / web are out of active scope; their code is left untouched.
- **Consequences:** Manual testing happens on Linux and Android. Shared changes must
  go through platform-aware paths (`Platform.is*`) so other platforms don't break.
- **Superseded:** D-007 later parked Android and made Linux the only active target.

## D-004 — The `ai/` folder is the single source of truth for docs (2026-11-15)
- **Status:** accepted
- **Context:** You asked that every note, rule, decision, goal and progress update be
  stored as markdown so we can review it later and know where we are.
- **Decision:** Structure `GOAL / RULES / DECISIONS / PROGRESS / ARCHITECTURE /
  ENVIRONMENT / BACKLOG / notes`. The upstream project docs (`README.md`,
  `CONTRIBUTING.md`) stay untouched; `ai/` is our added layer.
- **Consequences:** Every session starts by reading `ai/README.md`.

## D-005 — ~~Documentation language: Persian~~ (2026-11-15)
- **Status:** **superseded by D-006**
- **Context:** Initially chosen so you could read it quickly.
- **Decision (historical):** `ai/` docs in Persian, code identifiers in English.
- **Consequences:** Mixed-script docs are harder to grep/edit and add friction for
  tooling and for any future agent.

## D-006 — Documentation language: English (2026-11-15)
- **Status:** accepted — supersedes D-005
- **Context:** You said: "I think it'd be nicer if you write the ai folder files in
  English — it's both prettier and easier and more understandable for you."
- **Decision:** All files under `ai/` (and the root `AI.md`) are written in English.
  Persian is still fine in chat. Commits and code stay English (already the case).
- **Consequences:** Slightly harder for a Persian-only reader, but better for
  searching, diffing, and consistency with the codebase and upstream docs.
  All existing files were rewritten in the same session.

## D-007 — Linux-only development; Android parked (2026-11-15)
- **Status:** accepted — supersedes D-003
- **Context:** You got the app running on Fedora and said: *"from now on, develop so I
  can easily build and run the app on my Linux machine and see it… forget Android for
  now, let's go with Linux so that while developing I can run and see it quickly."*
- **Decision:** Linux is the **only active target**. Android is parked, not deleted: no
  Android builds, no Gradle work, no Android-specific feature work for now. Code stays
  platform-aware so Android does not rot, but nothing is verified there.
- **Consequences:**
  - "Done" now means: `bin/setup_linux` and `bin/dev --community-linux` work on Fedora.
  - New dependencies must have Linux support, or be guarded behind `Platform.isAndroid`.
  - Android-only features (IAP, camera, quick actions, Google sign-in) can't be tested;
    keep them compiling, don't extend them.

## D-008 — Toolchain baseline is Flutter 3.50.0 / Dart 3.14.0 (2026-11-15)
- **Status:** accepted
- **Context:** The project does not compile on Flutter 3.41 / Dart 3.11 (the previous
  `.tool-versions` value, 3.47.4, is also below what you have). You installed Flutter
  3.50.0 stable in `~/development/flutter_stable` alongside the old one and everything
  builds. Pinning package versions cannot work around missing SDK APIs
  (`scrollableBuilder`, `onReorderItem`, `TextInputStyle`).
- **Decision:** The supported dev toolchain is **Flutter 3.50.0 stable (Dart 3.14.0)**.
  `.tool-versions` updated from `3.47.4-stable` to `3.50.0-stable` so CI and version
  managers follow along. The old Flutter on PATH must not be used.
- **Consequences:** Anyone with an older SDK gets compile errors unrelated to our code.
  `bin/setup_linux` warns when the detected SDK is older than the baseline.

## D-009 — Commit the SDK-driven dependency bumps (2026-11-15)
- **Status:** accepted (revisit when objectbox 6 is stable)
- **Context:** To compile on Dart 3.14 you needed `objectbox 6.0.0-preview.6` (5.x does
  not compile) and `json_serializable ^6.15.2` (6.14.1 conflicts with `source_helper`
  and breaks `build_runner`). Those were local-only edits in your folder, which means a
  fresh clone of our repo would not build.
- **Decision:** Commit both bumps into `pubspec.yaml` as the project baseline, with
  explanatory comments pointing here.
- **Consequences:**
  - A fresh clone now builds on the new SDK after `flutter pub get` + codegen.
  - `objectbox.g.dart` / `lib/objectbox-model.json` are generated and were produced by
    5.3.2 — **`bin/setup_linux` (or `bin/build_runner --delete`) must run once** after
     pulling, otherwise the build fails confusingly.
  - We depend on a *preview* release. Revisit when objectbox 6.0.0 stable ships.
  - `pubspec.lock` in the repo is now stale by design; `flutter pub get` rewrites it.

## D-010 — One-command Linux dev loop (2026-11-15)
- **Status:** accepted
- **Context:** `bin/dev` had no Linux target, and the working `flutter run` invocation is
  long (target + dart-defines file + `-d linux`). You want to run the app constantly
  while we develop.
- **Decision:** Two additions, both committed:
  - `bin/dev --community-linux` / `--storypad-linux`: same target and dart-defines as
    the mobile flavors, but **without** `--flavor` (`flutter run -d linux` rejects
    flavors). The sed that extracts the flavor now strips `-linux` too, otherwise every
    derived path breaks.
  - `bin/setup_linux`: idempotent setup (SDK detection + version warning, Fedora package
    check, `pub get`, codegen). No sudo.
- **Consequences:** The daily loop is `bin/setup_linux` once, then
  `bin/dev --community-linux`. Android/iOS/macOS targets are untouched.

## D-011 — Every Pro feature is unlocked, through one reversible switch (2026-11-15)
- **Status:** accepted
- **Context:** You asked to open everything that is locked so the app feels complete,
  and to delete anything that can't work instead of leaving it broken. ~30 call sites
  gate UI behind `InAppPurchaseProvider.isProUser`, which is always `false` on Linux
  because `kIAPEnabled` is false there (no store plugin, no RevenueCat key). The result
  was a "complete" app that hides half of itself.
- **Decision:** A single policy switch, `ProEntitlementService.unlockAll = true`
  (`kUnlockAllProFeatures`), fed into `isProUser`. The gating call sites stay where they
  are, so turning gating back on is one edit. Upsell surfaces (paywall entries, Pro
  badge, pro banner) are now driven by `kShowProUpsell = showUpsell(unlockAll,
  storeAvailable)` instead of `kIAPEnabled`, and are hidden — a paywall nobody can
  complete is worse than no paywall.
- **Consequences:**
  - All 30 gates open at once; Nextcloud/Dropbox sync is no longer Pro-only.
  - We never sell anything, so RevenueCat code becomes dead weight (kept, harmless).
  - The `Pro` badge no longer shows for everyone (it would be meaningless).

## D-012 — A platform-capability layer; Google Drive is not offered on Linux (2026-11-15)
- **Status:** accepted
- **Context:** On Linux `BackupProvider` registers `GoogleDriveLinuxCloudService`, whose
  `signIn()` always returns `false` — a stub. The backup screen still rendered a
  "Connect" tile for it, so tapping it did nothing (the worst possible UX, and exactly
  the "sync is not enabled on Linux" bug you hit). Implementing real Google sign-in on
  Linux is not possible with `google_sign_in` (no Linux implementation) and would need a
  loopback-OAuth flow plus our own Google client credentials.
- **Decision:** Add `PlatformCapabilities` — a pure, unit-tested matrix of what can work
  where. `BackupServiceTile` renders an explanatory, disabled tile for a service the
  platform cannot use instead of a dead Connect button. Drive is therefore hidden on
  Linux; Dropbox (loopback OAuth) and Nextcloud (WebDAV) remain — and after D-011 they
  are no longer Pro-locked, so **Linux does have working cloud sync**.
- **Consequences:**
  - Regression-guarded by tests: "every platform keeps at least one working sync backend".
  - The Linux Drive stub stays registered (the repository requires a non-null service) but
    is now unreachable from the UI. It is documented as intentionally dead.
  - A real Drive-on-Linux implementation (loopback OAuth + our client ID) stays open in
    `BACKLOG.md` as I-11.

## D-013 — GitHub Actions is the build verifier (2026-11-15)
- **Status:** accepted
- **Context:** I cannot compile anything locally (no Flutter SDK, pub.dev blocked). You
  asked for CI to be written and run on GitHub so we actually see whether it works.
- **Decision:** `.github/workflows/linux.yml` with three jobs: **Test** (blocking,
  `flutter test`), **Build Linux desktop** (blocking, `flutter build linux --debug` on
  `lib/main_community.dart` — the real compile gate for the whole app) and
  **Analyze** (blocking, but with `--no-fatal-infos --no-fatal-warnings`, so upstream's
  pre-existing lint debt is reported without blocking us while real analyzer *errors*
  still fail). It runs on pushes to `arena/**`/`main`/`develop`, on PRs, and manually.
  Flutter version comes from `.tool-versions`. The upstream `ci.yml` (wired to `develop`,
  Android-era) is left untouched.
- **Note:** GitHub Actions *logs* are not readable from my sandbox (they are served from
  Azure blob storage, which is not on the allowlist). So the jobs are designed to be
  judged by pass/fail, and the first run's step-level outcome is the signal. If we ever
  need the log text, you paste it or I ask you to read it.
- **Consequences:** "It compiles" now means CI green, not my guess. Any red CI is triaged
  before I claim a task is done.

## D-014 — Speed rules: CI is parallel and non-blocking for me (2026-11-15)
- **Status:** accepted
- **Context:** You stopped a run because a single CI cycle blocked the whole session
  for 6+ minutes while I sat waiting.
- **Decision:** three rules, effective immediately:
  1. **Never block on CI.** Kick off the run, keep working on the next piece, and check
     the result later with `gh run list` (no `gh run watch` marathons).
  2. **`paths-ignore` for docs.** `ai/**` and `**/*.md` no longer trigger a run — most of
     our commits are docs, and each one used to cost 6 minutes.
  3. **Cache the codegen.** `.dart_tool/build` is cached across runs; `build_runner` is
     ~75s of fixed cost in every job.
- **Also:** the formatting gate is advisory again until clean. A blocking formatter I
  cannot run locally costs one full CI round trip per guess.
- **Measured effect:** the blocking `Test` job went from 6m33s to 5m09s, and all three jobs
  run in parallel so wall clock is the slowest one (5m09s). A docs-only commit now costs
  zero minutes instead of ~6.
- **Remaining big win:** commit freshly generated `*.g.dart` so CI can skip `build_runner`
  entirely (~2 min per job). Tracked as `BACKLOG.md` T-6.

## D-015 — Fix media picking on the desktop instead of hiding it (2026-11-15)
- **Status:** accepted
- **Context:** `image_picker`'s Linux implementation (`image_picker_linux`, built on
  file_selector) serves a single image only — `pickVideo` and `pickMultipleMedia` return
  `UnimplementedError` there. So "record video" and "select from photos" were dead taps on
  the desktop, and single images worked only by accident of that plugin.
- **Decision:** On Linux/Windows, `AppFilePickerService` opens the OS file dialog through
  `file_picker` (already a dependency) with an extension filter for single images and
  videos. Multi-select uses `image_picker.pickMultiImage` and falls back to a single file
  dialog if the platform doesn't implement it. Mobile and Apple keep using `image_picker`,
  unchanged.
- **Implementation constraint (learned the hard way):** only call the `file_picker`
  surface this repo already proves compiles — `FilePicker.pickFiles(type:,
  allowedExtensions:)` then `result.firstOrNull?.xFile`, exactly as `pickJsonFile` does.
  Guessing an `allowMultiple` flag broke the Linux build (`file_picker 13.1.0` is the
  federated rewrite and does not accept it). Real multi-select on the desktop is tracked in
  `BACKLOG.md` T-8.
- **Consequences:**
  - Picking is one code path per platform, no try/catch guessing at runtime.
  - Desktop images are not re-compressed when picked through the file dialog (there is no
    `imageQuality` equivalent); acceptable, video is the only media the app encodes itself.
  - The extension lists must agree with `AssetFileTypeService`, otherwise a video is
    inserted as an image — enforced by `media_picker_extensions_test.dart`.

## D-016 — Generated code is regenerated by CI and published as a branch (2026-11-15)
- **Status:** accepted
- **Context:** A fresh clone could not run:
  `lib/objectbox.g.dart:751: Method not found: loadObjectBoxLibraryAndroidCompat`.
  Cause: the committed generated code was produced by the objectbox **5.x**
  generator, while D-009 pinned **6.0.0-preview.6** — the old generated file calls a
  helper the new runtime no longer has. Nothing on my side could fix it: I cannot run
  Dart, and Actions logs *and artifacts* are served from blob storage, which the
  sandbox cannot reach.
- **Decision:** three pieces.
  1. **`Codegen` workflow**: on a commit whose message contains `[codegen]`, it runs
     `pub get` + `build_runner` on a real toolchain and publishes the result to the
     **`ci/codegen`** branch (force-pushed, never touching our branch). Git branches are
     the only transfer channel that works from the sandbox, and the diff is reviewed
     before it is merged.
  2. **`bin/dev` fails fast**: `bin/build_runner` stamps the dependency set it generated
     against (`bin/.tmp/codegen.stamp`); `bin/dev` refuses to start when the stamp is
     missing or stale, printing the fix instead of letting the compiler fail 4 minutes
     later. `SKIP_CODEGEN_CHECK=1` bypasses it once.
  3. Once the regenerated files are committed, CI **verifies** them instead of silently
     regenerating: `build_runner` output must leave `git diff` clean, otherwise the job
     fails with the offending files named. (Silent regeneration is what hid this bug.)
- **Why not `workflow_dispatch`:** GitHub only registers dispatchable workflows that
  exist on the default branch; dispatching by filename from our branch returns 404. The
  commit marker is a trigger I fully control.
- **Consequences:** `flutter run` works on a fresh clone again, and a stale generated
  file can no longer reach the user silently.

## D-017 — CI levels are requested per commit, not run always (2026-11-15)
- **Status:** accepted; the "tests only on `[test]`" half is superseded by D-032 (tests now run
  scoped to the change, and only skip when nothing can fail)
- **Context:** "The gh runs take way too long. Split the CI, only run what you need. Speed
  matters." Every push ran Test + Build + Analyze regardless of what changed, and I sat
  polling them.
- **Decision:** `.github/workflows/linux.yml` has three independent jobs:
  - **Analyze** — always (~2 min). Analyzer *errors* are what actually catch broken Dart,
    so this is the default gate.
  - **Test** — only with `[test]` or `[full]` in the commit message (~5 min).
  - **Build Linux desktop** — only with `[build]` or `[full]` (~4 min); needed when touching
    the entry point, native/platform code, plugins or dependencies.
  Pull requests still run all three. `build_runner` was dropped from all jobs because the
  generated code is committed and verified (D-016), which alone saved ~75s per job.
- **Consequences:** a typical push costs ~2 minutes instead of 5.5. I pick the level when
  writing the commit message, which is cheap and predictable. The trade-off is that a
  compile-only break in a file analyze can't see would need `[build]`.

## D-018 — No Firebase options on Linux, and the app must boot without them (2026-11-15)
- **Status:** accepted
- **Context:** `bin/dev --community-linux` launched and then crashed:
  `Unhandled Exception: Unsupported operation: DefaultFirebaseOptions have not been
  configured for linux`. `DefaultFirebaseOptions.currentPlatform` **throws** for a platform
  FlutterFire never configured — it does not return null — and `main_community.dart` read it
  eagerly before `runApp`. So the app never rendered on Linux.
- **Decision:** `PlatformCapabilities.firebase` (unit-tested) decides; on Linux (or any
  platform without a config, caught defensively) `main_community` passes `null`, which
  `FirebaseInitializer` already handles by returning early.
- **Consequences:** the app boots on the desktop; Analytics/Crashlytics/RemoteConfig stay
  no-ops there, which is the documented Linux behaviour.

## D-019 — Google Drive on Linux reuses the Drive API and only replaces auth (2026-11-15)
- **Status:** accepted
- **Context:** the biggest hole in the Linux build was sync. Drive was registered as
  `GoogleDriveLinuxCloudService`, a stub whose every method returned null/false, because
  `google_sign_in` has no Linux implementation — so the tile was disabled outright. Dropbox,
  meanwhile, was fully implemented but sent `client_id=""` (the `community` flavor's
  `dart_define` file is `{}`), which Dropbox answered with `Invalid client_id: ""`.
- **Decision:**
  1. Split the platform-specific part out: `GoogleDriveAuthStrategy` obtains and renews
     tokens; everything else in `GoogleDriveCloudService` (835 lines of Drive REST) is shared.
     The mobile implementation is the previous `google_sign_in` code, moved verbatim.
  2. Linux implements the installed-app OAuth2 flow itself
     (`GoogleDesktopOAuthService`): system browser, loopback server on an OS-assigned port,
     PKCE(S256) + `state`, `access_type=offline` for a refresh token.
  3. Written against `dart:io`/`http` instead of adding `googleapis_auth`: no new dependency
     means no `pubspec.lock` change, which I cannot generate offline (pub.dev is blocked in
     the agent sandbox).
  4. Credentials live in the gitignored `private_keys` checkout next to the repo and are
     passed as `--dart-define`s; `bin/setup_sync` writes them (accepting Google's downloaded
     `client_secret_*.json`) so nobody hand-edits JSON.
  5. "Not configured" is an explicit, explained state (dialog with the checklist) rather than
     a browser window that ends on Google's `invalid_client` page.
- **Consequences:** Drive works on the desktop with the same one-tap flow as the phone. It
  needs a one-time OAuth client, owned by whoever builds/releases — an app identifier, not an
  account. `drive.appdata` is a non-sensitive scope, so publishing needs no Google security
  review; while the project stays in Testing, Google expires refresh tokens after 7 days.

## D-020 — CI answers in seconds; never block on a run (2026-11-15)
- **Status:** accepted
- **Context:** "These watcher commands take 5–10 minutes each. Can't you do something about
  it?" Two separate problems were hiding there: the runs were serialized, and I *watched*
  them (`gh run watch`), which turns CI into dead time for the whole session.
- **Decision:**
  1. **No blocking waits.** Push, keep working, check once with `bin/ci` — a one-shot API read
     that returns in ~2s (optionally `--wait N` / `--watch` when waiting is explicitly the
     point). A run finishing between turns costs nothing.
  2. **Jobs run in parallel.** `test` and `build-linux` no longer `needs: analyze`; that gate
     put ~90s of dead time in front of every one of them.
  3. **Tests are sharded** 2 ways (round-robin over the 97 test files): the suite is a single
     262s step, the largest cost anywhere in CI.
  4. **apt packages are cached** (`awalsh128/cache-apt-pkgs-action`): the Linux build's
     dependency install was 47s of every build.
- **Measured before:** Analyze 82s, Test 312s, Build 179s — `[full]` wall clock ≈ 7.3 min
  (analyze 82 + test 312, serially gated).
- **Consequences:** `[full]` should land near its slowest job (~3 min). The fast loop (plain
  push, analyze only) is unchanged at ~90s, and I no longer spend it waiting.

## D-021 — Drive's appDataFolder is sandboxed per OAuth client, so the official app and this fork can never share backups (2026-11-15)
- **Status:** accepted (a constraint, not a choice)
- **Context:** Drive sync on Linux reported "connected" and "synced", but nothing moved
  between the phone (official StoryPad) and the desktop, with the same Google account.
- **Fact:** Google Drive's hidden `appDataFolder` is scoped to the **OAuth client id**, not to
  the account and not even to the Cloud project. Google's own docs: the folder "is only
  accessible by your application and its contents are hidden from the user and from other
  Drive apps"; the rclone community confirms the practical consequence — "only if you use the
  client_id and client_secret of the other app … otherwise you can't see its data". So:
  - official StoryPad (StoryPad's client id) → folder A
  - this build (the user's own desktop client id) → folder B
  Both sync *successfully* into their own folder. Neither is broken; they are simply not
  looking at the same place. **Dropbox has the identical property** (the "App folder" belongs
  to the app key), so switching provider does not fix cross-app sync.
- **Decision:**
  1. Feasible cross-**app** sync (official phone app ↔ this desktop build) goes through a
     provider that is path-based rather than app-sandboxed: **Nextcloud/WebDAV** (both apps
     support it), or a manual JSON export/import, which already works in both directions
     (`ImportExport` → `BackupObject.fromContents`, v2/v3/v4 aware).
  2. Cross-**device** sync between *our own* builds is possible and stays on Drive, provided
     every build is the same OAuth client. That is a hard requirement for the future Android
     build: it must use the **same Desktop-type client id with the loopback flow**, not
     `google_sign_in` (whose Android client id would open yet another sandbox).
  3. `GoogleDriveCloudService` logs the visible appDataFolder contents in debug builds, so
     "synced but empty" is diagnosable in one look instead of a guessing game.
- **Consequences:** until an Android build of this fork exists (or Nextcloud is set up),
  phone↔desktop movement is manual. Worth saying plainly rather than shipping a "Sync" that
  silently syncs nowhere the user expects.

## D-022 — Persian (fa) locale (2026-11-15)
- **Status:** accepted
- **Context:** "Add Persian to the app's languages." Persian is RTL and uses the Arabic
  script, so this is not only a JSON file.
- **Decision:**
  1. `translations/fa.json` — all 602 keys (the suite's `unused_translations_test` requires
     an exact key-set match with `en.json`, so a partial translation would fail CI).
  2. Hand-applied what `bin/localization/build.dart` would generate (`kSupportedLocales`,
     `kLanguageNames`, `kNativeLanguageNames`, Android `locales_config.xml`, iOS
     `CFBundleLocalizations`) because the sandbox has no Dart toolchain. Re-running the
     generator should produce the same result.
  3. `initializeDateFormatting()` in `main()`: `DateFormat` is called with `context.locale`
     everywhere, and intl throws for a locale it was never told about — a new locale must not
     be a crash waiting on the first date string.
  4. Arabic-script font fallback (`kScriptFontFamilyFallback`) on every text style: the
     selectable fonts are Latin Google fonts, so Persian glyphs would otherwise be whatever
     the platform happens to substitute. The list is advisory (fontconfig skips missing
     families).
- **Glossary** (deliberate, easy to change): story = خاطره, entry = نوشته, backup =
  پشتیبان/پشتیبان‌گیری, sync = همگام‌سازی, tag = برچسب, template = قالب, draft = پیش‌نویس,
  bin = سطل, archive = بایگانی, settings = تنظیمات, font = قلم. Months/year numbers come from
  `intl`, so dates render with Persian digits while data-driven counts stay Latin — mixed
  digits are accepted for now rather than re-implementing number formatting app-wide.

## D-023 — Vazirmatn is bundled in the app instead of relying on system fonts (2026-11-15)
- **Status:** accepted
- **Context:** "Download the font and put it inside the app itself." After D-022 the app already
  *asked* for an Arabic-script font via `fontFamilyFallback`, but nothing shipped it: on a Fedora
  box with no Persian font installed, `fontconfig` substitutes something arbitrary, so the same
  text looked different on two machines and could look broken (wrong joining/shaping) on a
  minimal install.
- **Decision:** ship the four static Vazirmatn faces (Regular/Medium/SemiBold/Bold, 492 KB
  total) under `assets/fonts/`, declare family `Vazirmatn` in `pubspec.yaml` with weights
  400/500/600/700, and keep it as the **first** entry of `kScriptFontFamilyFallback`
  (`lib/core/constants/app_constants.dart`). The `OFL.txt` licence file ships next to the
  fonts, as the SIL Open Font License requires when redistributing.
- **Why a fallback and not `fontFamily`:** `fontFamily` would replace the user's chosen Google
  font for *all* text. A fallback only fills in the glyphs the primary font lacks, so Latin text
  keeps the user's choice and Persian/Arabic text is now identical on every OS.
- **Reproducibility:** fetched from `rastikerdar/vazirmatn` (`fonts/ttf/`) through the GitHub
  contents API, since pub.dev and most other hosts are unreachable from the sandbox. Verified
  each file starts with the TrueType magic `00 01 00 00`.
- **Consequences:** +492 KB in the binary, zero network dependency at runtime, no per-OS
  variability. To add another script later: drop the TTFs in `assets/fonts/`, add a `fonts:`
  entry, and prepend the family name to `kScriptFontFamilyFallback`.

## D-024 — Calendar settings: user-defined weekends and any first day of week; Shamsi is the next slice (2026-11-15)
- **Status:** accepted (D-024 covers the settings; the calendar-system switch is scoped in
  `ai/BACKLOG.md` C-1)
- **Context:** the app assumed a Western week: `FirstDayOfWeekOption` only offered Monday and
  Sunday, and both the calendar header and the day cells coloured *Saturday/Sunday* red as "the
  weekend" in code. For an Iranian user the week starts on Saturday and the weekend is Friday
  (often Thursday+Friday). Hard-coding either pair is wrong for somebody.
- **Decision:**
  1. `FirstDayOfWeekOption` now covers all seven weekdays (the Persian defaults are simply
     values, not a special case). `value` returns real `DateTime` weekday numbers, so the grid
     math and the storage format stay unchanged (`"first_day_of_week": "saturday"`).
  2. New preference `weekendDays` (`List<int>?`, `DateTime` weekday numbers, `null` = never
     configured → Saturday+Sunday). Any subset is valid, including none. It is stored sorted
     Monday-first and de-duplicated by `CalendarConfig.normalizeWeekendDays`, so the persisted
     value has one canonical shape regardless of the order the chips were tapped.
  3. `CalendarConfig` (`lib/core/services/calendar/`) is the single reader of those settings for
     widgets that build without a `Provider` (the calendar grid/header). It is published once at
     startup by `ThemeInitializer` (before the first frame, so nothing re-lays-out) and refreshed
     by `DevicePreferencesProvider` on every change.
  4. Weekday *names* come from `intl` through `WeekdayNameService`, keyed by weekday number, so
     the seven options are translated in all 21 locales for free and a new locale needs no new
     strings. Only the settings labels are new keys (`list_tile.weekend_days.title/.subtitle`).
  5. **Shamsi is deliberately not wired to the displayed dates in this change.** 154 call sites
     derive year/month from Gregorian `StoryDbModel` fields, the story list is grouped by
     Gregorian month, the "months that have stories" tab bar is a DB query over `month`/`year`,
     and the mood/period calendars page through Gregorian months. Flipping the formatter alone
     would print a Jalali month name above a Gregorian-month grid — worse than not shipping it.
     The conversion engine is in place and tested (`PersianCalendar`, `ai/BACKLOG.md` C-1
     lists the exact remaining surfaces), so the switch lands as one coherent slice.
- **Consequences:** every calendar surface now respects the user's week; no data migration (both
  fields are additive JSON keys); a user who never opens the new setting sees exactly the old
  behaviour.

## D-025 — The calendar is a *display* layer: storage and queries stay Gregorian (2026-11-15)
- **Status:** accepted
- **Context:** "I want to use the Shamsi calendar entirely — bring months in Shamsi, group
  by them, search by them, show the calendar by Shamsi day," together with the user's own
  suggested design: store/query in Gregorian, convert only for display and convert the user's
  Shamsi input back before querying.
- **Decision (the rule everything else follows):**
  1. **Nothing is migrated.** Every `DateTime`, every `year`/`month`/`day` column, every export
     and every backup stays Gregorian. Switching calendar can never corrupt or rewrite data, and
     switching back is lossless.
  2. **One read direction and one write direction**, both in
     `lib/core/services/calendar/calendar_display.dart`: `yearOf/monthOf/dayOf/monthKeyOf` for
     rendering, `dateOf/rangeOfMonth/rangeOfYear` to turn a displayed month or year back into the
     exact Gregorian day range to query.
  3. `DateFormatHelper` keeps its signatures and switches to Solar Hijri internally when the
     preference is set, so ~40 call sites needed no change. Persian **month** names are the only
     calendar-specific words (weekday names are identical in both calendars and keep coming from
     `intl`); digits become Persian only when the app language is Persian, so an English UI reads
     `1404/8/24` instead of mixing numerals. The month *name* stays Persian in every language
     (`آبان 24, 1405` in an English UI): a transliteration table would be a second thing to keep
     correct for no real gain.
  4. **No more synthetic dates.** `DateTime(2000, month)` was used to obtain a month name; that
     silently breaks in another calendar (month 8 of 2000 ≠ month 8 of a Jalali year). Those call
     sites now use `DateFormatHelper.monthName(month, …)`, and surfaces that must stay Gregorian
     (stats, recap) use the explicit `gregorianMonthName`/`yMMMMGregorian`, so nothing can be
     mislabelled.
  5. **Grouping** uses `CalendarDisplay.monthKeyOf(story.displayPathDate)` instead of
     `story.year`/`story.month` (a Shamsi month straddles two Gregorian months — 1 Azar 1405 is
     22 Nov 2026, mid Gregorian November).
  6. **Querying a Shamsi year/month** needed a day range, which ObjectBox cannot express as a
     tuple. `stories_box` gained a `date_range` filter that expands the range into one condition
     per Gregorian month (days listed with `oneOf`, OR-ed; ≤13 conditions for a year). The home
     page keeps its `years` filter as an index hint and adds `date_range` for exactness.
  7. Per-shown-month **recap stats** are skipped in Shamsi mode: they are aggregated per Gregorian
     month, and showing them under a Shamsi header would attach numbers to the wrong month. The
     year picker regroups Gregorian per-year counts approximately (documented in code).
- **Not converted in this slice** (`ai/BACKLOG.md` C-1): the mood/period calendar grid and its
  header, the Material date pickers, search date filters, and the stats screens — each is blocked
  on data that is currently fetched/aggregated per Gregorian month, and converting a label without
  converting its numbers is worse than leaving both consistent.
- **Consequences:** the feature is safe to ship half-way (both modes are always self-consistent),
  a third calendar would only need `CalendarDisplay` + a `DateFormatHelper` branch, and the
  database format is untouched — an old build opening the same data sees exactly what it expects.

## D-026 — Date picking and calendar switching follow the display calendar (2026-11-15)
- **Status:** accepted
- **Context:** two concrete reports: the date picker at the top of a story ("تاریخ رو عوض کن") stayed
  Gregorian in Shamsi mode, and switching the calendar left the home screen pointing at the same
  *number* (2026), which in the other calendar means a different span — an empty list with no
  explanation.
- **Decision:**
  1. **A picker that speaks the display calendar** (`SpDatePickerDialog`). Flutter's
     `showDatePicker` can only draw a Gregorian grid — the grid comes from
     `MaterialLocalizations`/`DateUtils` — so with the Shamsi calendar the user would pick from a
     Gregorian month while every date around it reads Shamsi. The dialog is built on
     `CalendarDisplay.monthGridDates`, honours the configured first day of week and the user's
     weekend days, and still returns a Gregorian `DateTime`. Gregorian mode keeps the stock
     Material/Cupertino pickers: no reason to replace a working path with our own.
  2. **Switching calendar re-anchors on today** (`HomeView.resetToToday` →
     `HomeViewModel.resetToToday`). A bare reload would have kept `year = 2026`, and a Jalali 2026
     starts on 21 March 2026, so the list would legitimately be empty — a silent data-looks-lost
     moment. `year` and the visible month are re-derived from `DateTime.now()` in the new
     calendar before reloading.
  3. **Day numbers are explicit about their calendar.** Three different numbers are now
     distinguishable by name: `d` (display calendar), `dayNumber` (display, padded),
     `gregorianDay` (forced Gregorian). The mood/period calendar grid still pages Gregorian months,
     so it uses `gregorianDay` — otherwise 15 November would have shown "24" under a November
     header. The story header now uses `dayNumber`, which fixes "15 آبان ۱۴۰۵" for a story dated
     24 Aban.
  4. `CalendarDisplay.monthGridDates` is the single source of "which dates does a month grid
     show", for any calendar, so the picker and (later) the mood/period grid cannot disagree.
- **Still Gregorian on purpose** (`BACKLOG.md` C-1d/f/g): the mood/period calendar grid and its
  queries, the search date filters, and the stats aggregation. Their data is fetched or counted
  per Gregorian month, and a Shamsi label on top of Gregorian counts would be a lie; each needs
  the same "display month → Gregorian day range" treatment the home list already has.

## D-027 — Year filters are display years; the query is where they turn into dates (2026-11-15)
- **Status:** accepted
- **Context:** with Shamsi on, every *year* the user could pick was still a Gregorian year:
  the archive tabs, the tag screen, the year picker and the search filter chips all read
  `2026`, and the year counts behind them came from the Gregorian `year` column. The year
  picker also showed *approximate* counts, because per-Gregorian-year counts were regrouped
  by "whichever display year owns 1 July".
- **Decision:**
  1. **`SearchFilterObject.years` holds display years.** It is UI state (which chips are
     selected, what the tabs are labelled, what gets remembered), so it speaks the calendar
     the user sees.
  2. **`CalendarDisplay.yearsFilter()` is the single conversion.** Gregorian mode returns
     `{'years': [...]}` unchanged; Shamsi mode returns the one or two Gregorian years the
     display year can touch (so the indexed column still narrows the scan) **plus**
     `date_ranges`, an OR of exact day ranges. `buildQuery` gained `date_ranges` next to the
     existing single `date_range`, and `years`/`year`/`exclude_years` keep their Gregorian
     meaning, so no other consumer (period events, exclude-years) changed behaviour.
  3. **Counts are counted, not regrouped.** `getStoryCountsByDisplayYear()` derives the
     candidate display years from the Gregorian years that actually hold rows
     (`CalendarDisplay.displayYearsOf`, at most two per Gregorian year) and then counts each
     with an exact range query. That replaced the 1-July heuristic, so the numbers on the
     chips are now correct rather than indicative.
  4. **Gregorian-paged screens stay Gregorian and say so.** The mood/period calendars and the
     stats screen page Gregorian months; they pass the display years covering their window
     (`displayYearsCovering`) and keep their Gregorian `month`/`day` filters, which makes the
     pair exact without pretending their grid is Shamsi (`BACKLOG.md` C-1d/C-1g).
  5. **Switching calendar clears the saved search filter.** A stored display year means a
     different span in the other calendar, and silently restoring it would filter the whole
     list away — the same class of silent-empty bug as D-026 §2.
- **Consequence:** "does this story belong to the shown year" is answered by date ranges, never
  by comparing numbers. Any new year-scoped surface must go through `CalendarDisplay` rather
  than reading `story.year`.

## D-028 — The calendar screen pages the display calendar too (2026-11-15)
- **Status:** accepted · supersedes the "mood/period calendars stay Gregorian" carve-out in D-025/D-027
- **Context:** with Shamsi on, the calendar screen (mood + period) was the last place that paged
  *Gregorian* months: header, grid and day numbers were Gregorian while every other screen showed
  Shamsi, which is exactly the mismatch the user kept reporting ("توی قسمت انتخاب تقویم هنوز
  میلادی میمونه"). On top of that the screen crashed with
  `Converting object to an encodable object failed: Instance of 'DateTime'`, because its widget
  keys run `jsonEncode` over a filter map that now legitimately contains the `date_ranges` a Shamsi
  year resolves to.
- **Decision:**
  1. **One grid generator.** `CalendarDaysGenerator.generate` delegates to
     `CalendarDisplay.monthGridDates` in Shamsi mode, so the grid holds the display month's real
     days (whole weeks, real Gregorian `DateTime`s). `_SpCalendarMonthGrid` asks
     `CalendarDisplay.isInMonth` instead of comparing `date.month`, and the cells print
     `DateFormatHelper.d`.
  2. **Header and month picker follow it.** The title uses `DateFormatHelper.yMMMM` on the display
     month. `CupertinoDatePicker(mode: monthYear)` cannot show Jalali months, so the Shamsi month
     picker is our own sheet: a year stepper plus the twelve display month names.
  3. **Queries by day range, not by month number.** A Shamsi month is a run of days spanning two
     Gregorian months, so `EventsBox` gained the same `date_range` condition `StoriesBox` already
     had, and both the period events (this/last display month) and the mood feelings are fetched
     with the display month's exact range. Feelings come back keyed by **display** day
     (`CalendarDisplay.dayOf`), because the grid asks for "day 24 of آبان", not "day 24 of a
     Gregorian month".
  4. **Story lists scope by `DateRangeFilterObject`** — a `SearchFilterObject` that carries an exact
     day range — instead of `month`/`day` columns. For a single day the Gregorian month/day are kept
     as well, which preserves the "on this day in another year" throwback tile.
  5. **Conversion only at the edges.** Navigating in (story header, side bar, period reminder) passes
     display year/month/day; opening the editor or creating a period event passes the real
     Gregorian date, and both directions go through `CalendarDisplay`.
  6. **Filter maps are encoded JSON-safely.** `SearchFilterObject.encode` writes `DateTime`s as
     ISO-8601 for widget keys/equality; `jsonEncode` must never be called on a raw filter map again.
- **Consequence:** mood/period paging, `MonthPickerService`, feelings, period events and their story
  lists are all display-calendar. The stats screen is the only remaining Gregorian surface and it is
  labelled as such (`BACKLOG.md` C-1g).

## D-029 — Stats is a display-calendar screen (2026-11-15)
- **Status:** accepted · completes D-027 §4 (stats was its last Gregorian exception)
- **Context:** with the calendar screen migrated (D-028), the stats screen was the only surface left
  showing Gregorian years, Gregorian month tabs and Gregorian trend bars while the rest of the app
  read Shamsi. Keeping it "honestly Gregorian" stopped being defensible once nothing else was.
- **Decision:**
  1. **`StatsRange` snaps to the display calendar.** Its `start`/`end`/`month`/`years`/`label`/
     `previous`/`next` all derive from `CalendarDisplay`, so a month range is that display month's
     day span (23 Oct – 21 Nov 2026 for آبان ۱۴۰۵) and `previous`/`next` step display months, not
     `DateTime.month - 1`.
  2. **Counting is by display month.** The twelve trend bars bucket `dailyCounts` by
     `CalendarDisplay.monthOf(day)` within the display year, and the tab/bar labels use
     `DateFormatHelper.monthName`. Bar values and the year title print in the locale's digits.
  3. **Queries use exact day ranges** (`DateRangeFilterObject`), never `month`/`year` columns, so a
     display month that straddles two Gregorian months is counted once and correctly.
  4. **Year lists come from `getStoryCountsByDisplayYear`**, so the picker offers years that actually
     hold stories.
- **Consequence:** `StatsRange.anchor` is still a real `DateTime` — only the numbers the screen shows
  are display values. The home month recap tiles joined in the same round: `MonthlyStoryStatsService`
  groups by `CalendarDisplay.monthKeyOf`, so nothing in the app aggregates by the Gregorian `month`
  column any more (Aban is scored against its real 30 days, not against the 31-day Gregorian months
  it straddles).

## D-030 — RTL is a layout direction, not a patch (2026-11-15)
- **Status:** accepted
- **Context:** with the Persian UI on (D-022) the app was still laid out as if LTR were the
  only direction, and the user listed six concrete symptoms: swapped month arrows, a Shamsi
  date picker that looked plainer than the Gregorian one, the story-list timeline rail stuck on
  the left, `آبا` instead of `آبان`, swapped caret buttons in the editor, and drawers running
  off the left edge. Each was a real bug, but they share one cause: places that read *start* or
  *back* were hardcoded as *left*.
- **Decision:**
  1. **Chevrons follow reading order.** `SpIcons.previous(context)` / `SpIcons.next(context)`
     return the mirrored glyph, and every month/step/"opens a screen" arrow uses them
     (month picker, date picker, list tiles, cards). Icons that name a physical side stay
     literal — the editor's caret arrows must keep pointing where they move.
  2. **The caret buttons act on their side.** `Move left` runs `forward` in RTL (forward is
     toward the left in a right-to-left text) and `backward` in LTR; the pair keeps ◀ left /
     ▶ right physically by reversing the list back after the `Row` reverses it.
  3. **The story-list rail is direction-aware.** Every `Positioned(left: 32)` timeline divider
     (home list, month headers, recap tiles, the tile-preview sheet) is placed by
     `AppTheme.rtl(context)`, because the tile `Row` puts the monograms at its *start* — right
     in RTL. Same treatment for `EdgeInsets.only(left/right:)` that really meant start/end.
  4. **Persian months are never abbreviated.** `DateFormatHelper.monthName(short: true)` and
     `MMM` ignore `short` when the display calendar is Persian: `آبا` is a stem of آبان/آذر/
     اردیبهشت, not a name. Latin months keep `Aug`/`Nov`. The timeline month chip keeps its one
     monogram width (the rail crosses its centre) and scales the full name down with a
     `FittedBox`. It must **not** use an `OverflowBox` to grow sideways: a story list gives its
     rows unbounded height, `OverflowBox` sizes itself to `constraints.biggest`, and
     `Size(32, infinity)` fails layout for the whole scroll view — see the incident in
     `PROGRESS.md` (the blank home screen of 2026-11-15).
  5. **The big window sidebar and its insets mirror.** The root sidebar docks to the start edge
     (right in RTL) and `RootPagesMediaQuery` puts its 88pt inset on that side, so pages are not
     pushed clear of a sidebar that is no longer there.
  6. **Drawers keep their own safe area.** The "far side" padding an end drawer drops is the edge
     it does *not* cover (left in LTR, right in RTL) — `MediaQuery.removePadding` is physical, so
     `removeLeft: true` in RTL was stripping the inset under the drawer itself and its rows ran
     off the left edge.
  7. **The Shamsi picker is a Material date picker**, not a plainer dialog: 28pt rounded sheet,
     tinted weekday+date header, a month/year row whose label opens the app's Shamsi month picker,
     a roomier grid, and end-aligned actions, in a scrollable body for short windows.
- **Consequence:** direction-dependent layout is decided where it is drawn (`AppTheme.rtl`,
  `SpIcons.previous/next`, `EdgeInsetsDirectional`) instead of being assumed LTR. New UI should
  use those helpers; a literal `left:`/`Icons.keyboard_left` in a directional position is a bug.

## D-031 — The daily-score add-on: a drag bar, an omitting calendar, hand-painted charts (2026-11-15)
- **Status:** accepted
- **Context:** "A toggleable add-on that rates each day 0–100 — how my day was. Not a number
  field: a bar you drag. Red at the bottom, orange in the middle, deep green at 100. Show the
  score on the day, and nothing on days without one. Two charts: this month's line, and the
  monthly averages. Days and months without data must not appear at all."
- **Decision:**
  1. **The input is a progress bar, not a `Slider`.** `SpDailyScoreBar` paints the whole track as
     the 0→100 palette, fills it to the value and tints its thumb with the value's colour, so the
     colour is chosen *while* dragging. A Material `Slider` can only tint a thumb after the fact.
     Direction comes from `Directionality`: in Persian 0 is on the right.
  2. **The palette is interpolated in HSV, not RGB** (`DailyScoreScale`). `Color.lerp(red, green,
     .5)` goes through muddy brown exactly at 50, the value a "how was today" scale is read at
     most. Every surface (bar, calendar cell, both charts) colours a score through `colorOf`, so a
     30 is the same orange everywhere.
  3. **"No score" is absence, not zero.** `DailyScoreProvider` stores only rated days, `0` is a
     real score, and every reader returns `int?`. An unrated calendar day shows the day number and
     nothing else; unrated days are skipped by the charts (the line spans the gap over the month's
     real span) and months with no data produce no bar at all.
  4. **Storage is Gregorian-keyed `yyyy-MM-dd`** in a `MapStorage` (D-025). Switching to Shamsi
     must not move a day's score; display-calendar grouping happens only when reading
     (`scoresOfDisplayMonth`, `monthlyAverages`).
  5. **Both charts are `CustomPainter`/widgets, no chart dependency.** The line uses monotone
     cubic (Fritsch–Carlson) tangents: Catmull-Rom can overshoot below 0 or above 100 between two
     real points, i.e. draw a score nobody entered. Segments take the colour of the two scores
     they join; the area under the curve is a wash of the month's average.
  6. **The add-on is wired through the existing add-on machinery**: `AddOnType.daily_score` →
     `DevicePreferencesObject.enableDailyScore` (opt-in, free, default off) → a
     `CalendarSegmentId.score` segment, shown only when the preference is on. The add-on tile
     toggles in place because there are no demo screenshots yet, and `SpDemoImages` reserves 320px
     even for an empty list.
  7. **The calendar segment keeps tapping as the edit gesture** (`onTap` → `SpDailyScoreSheet`
     for that date, which writes through the provider and pops), so the grid never needs a second
     selection state, and a `TodayScoreTile` above the grid rates today in one tap.
     *(Superseded the same day by D-033: the score grid was folded into the main calendar, and that
     segment became a chart-only «روند». The bar, the palette and the charts below are unchanged.)*
- **Consequences:** adding a score is one drag and one tap from the calendar; the calendar doubles
  as a heat map; the charts never invent data points. `SpDailyScoreBar` owns its own geometry, so
  a future "score" surface reuses the palette rather than re-deriving red/orange/green.

## D-032 — CI runs the tests that can fail, not all of them (2026-11-15)
- **Status:** accepted (supersedes the "test only on `[test]`" half of D-017)
- **Context:** the full suite is 106 files / ~1000 cases and costs ~3.5 minutes across two shards,
  while most changes can only break a handful of files. Paying that for every push — or, worse,
  skipping it and shipping unverified — is what made CI feel like the task.
- **Decision:** a new `scope` job (~15s: checkout + Python, no Flutter) runs `bin/changed_tests`,
  which maps changed files to tests and publishes `mode`/`shards`/`paths`:
  - a changed `test/**_test.dart` runs itself;
  - a changed `lib/**` file runs the nearest mirroring `test/**` directory, plus a small
    cross-cutting table for relations the mirror cannot see (calendar helpers → calendar tests,
    `translations/**` → the translations test, `sp_icons.dart` → its test);
  - anything unmapped → the whole suite (never a silent empty selection);
  - `pubspec.*`, `analysis_options.yaml`, `test/flutter_test_config.dart` → whole suite;
  - docs/`ai/`/`bin/`/`.github/` only → `mode=none`, and the test job does not even start;
  - `[test]` / `[full]` in the commit message → whole suite, as before.
  The test matrix reads `shards` from that output, so a scoped run is one job and a full run is
  still sharded two ways.
- **Consequences:** a typical push runs analyze (~80s) plus a few seconds of tests in parallel. The
  scoper is conservative by construction — over-selecting costs seconds, under-selecting hides a
  bug — and its reasoning is printed to the job log (`--explain`) so a surprising selection can be
  debugged from the annotations. Risk accepted: a mapping error can under-select, which is why the
  full suite still runs for anything unmapped and why `[test]` always wins.

## D-033 — One calendar: feelings, the day number and the score in the same cell (2026-11-15)
- **Status:** accepted (folds D-031 §1–2's score grid into the main calendar)
- **Context:** "I want my calendar to be one: in the main calendar I want to see the emoji *and*
  the score. And the thing that bothers me is that when a day has an emoji or a tick you stop
  showing its number — the day should look the way it does now, but with the number in a small
  neat circle underneath the emoji. Even better: pick the day's colour from its score, so I can see
  how the month went."
- **Decision:**
  1. **One cell widget, everywhere.** `SpCalendarDateCell` gained `score` and `onLongPress`, and
     the score add-on's own grid was deleted: its segment is now «روند» (`ScoreTrendView`) and
     contains the two charts plus today's rating, no calendar. The app has exactly one grid.
  2. **The day number is never sacrificed.** A day with a feeling (or the "has stories, no feeling"
     check) keeps the emoji in the middle of the cell and gains a 19pt circle underneath it with
     the day number — the circle's ring is the score's colour, and it is filled with the primary
     colour when the day is selected. Before this, an emoji *replaced* the number and the grid lost
     its reference points: half of a month of faces had no readable dates.
  3. **The score is a background layer.** A rated day tints the whole cell with 16% of its score
     colour (the same `DailyScoreScale` ramp the input bar teaches), so a month reads as a heat map
     without any cell needing a second number. Unrated days are untinted: still no such thing as a
     "zero day".
  4. **Tap selects, long press rates.** Tapping a day already means "show that day's stories", so
     rating moved to a long press on the cell (`SpTapEffect.onLongPressed` → the score sheet for
     that date). Because a long press is not discoverable, the trend segment shows a one-line hint
     until the first score exists.
  5. **The segment key moved with the meaning:** `general.score` ("Score") was replaced by
     `general.trend` ("Trend"/«روند»), since the second segment is a chart surface, not a calendar.
- **Consequences:** the user's mental model — "one calendar, everything on it" — matches the code:
  one grid, one cell, score as a layer rather than a parallel screen. The cost is that the exact
  score number lives one gesture away (the sheet) and in the two charts; the tint answers "how was
  this month" without it.

## D-034 — The calendar's polish: motion, real insets, and the score where the day is (2026-11-15)
- **Status:** accepted (extends D-033; supersedes nothing)
- **Context:** after D-033 the calendar said everything the user asked for, and then looked like it had
  been bolted on: the trend segment was pressed against the sidebar on a wide window, both charts
  appeared as a finished picture the instant the segment was selected, a score tint snapped in from
  nothing, and the only way to rate a day was a long press on a 56pt cell — the shortest path to the
  feature was the least visible one.
- **Decision:**
  1. **Charts animate their data, not their container.** `ScoreMonthLineChart` wraps its painter in a
     700ms `easeOutCubic` `TweenAnimationBuilder` and the painter interpolates each point's *height*
     from the baseline (`progress`), fades the fill by the same factor, and brings the dots in with a
     slight `easeOutBack` overshoot after 45%. `ScoreMonthlyAverageChart` grows its bars bottom-up,
     staggered (the stagger spends 35% of a 750ms timeline, each bar 65%). A chart that fades in as a
     block still reads as an image; a chart that draws itself reads as data.
  2. **The tween's key is the data.** Both charts key the builder on the values (`'$daysInMonth|day:score,…'`,
     the joined month ids), so a newly rated day replays the entrance instead of the tween running once
     per mount and then lying about fresh numbers. The key is derived from data only, never from
     identity, so a rebuild with equal data does not replay.
  3. **Side insets come from `MediaQuery.paddingOf`, not from `EdgeInsets.zero`.** `RootPagesMediaQuery`
     folds the wide-window sidebar's 88pt into `padding.left/right`; the trend segment's `ListView` and
     the mood segment's new score card both consume those insets, which is why the charts no longer
     slide under the sidebar. Any new full-bleed list on this page must do the same.
  4. **The tint fades, and the cell keeps one key.** The score tint moved from `Container` to
     `AnimatedContainer` (`Durations.medium2`, `easeOut`) with a *stable* key. Keying the container by
     state (`score == null ? null : ValueKey('score-tint')`) silently defeats the implicit animation:
     the key swap rebuilds the box instead of tweening it.
  5. **The selected day's score sits above its stories.** When a single day is selected and the add-on
     is on, the story column starts with a card showing that date, its score (or "no score yet") and
     the same tint, tapping which opens the very same `SpDailyScoreSheet`. The grid's long press stays
     as the fast path; it is no longer the only one. The "all stories" page (no day selected) shows no
     card — there is no day to rate.
  6. **One shell for both callouts.** `SpScoreCallout` is the card; `TodayScoreTile` in the trend
     segment and the new day card both render it, differing only in wording. Two hand-built copies of
     the same tint/ink/label would have drifted on the first restyle.
- **Consequences:** the segment now *feels* like the calendar rather than a report, and rating a day is
  discoverable from the day's own column. The cost is motion: it is deliberately short (≤750ms), it
  replays only when the underlying data actually changes, and nothing on the screen waits for it —
  taps, the sheet and the story list are interactive on the first frame. Implicit animations in
  Flutter do *not* consult `MediaQuery.disableAnimations` on their own, so this is a bounded, one-shot
  entrance rather than a decorative loop; if a reduced-motion pass is ever wanted it has to be done
  explicitly in both builders.

## D-035 — Directions, surfaces and an honest switch: the calendar's second polish round (2026-11-15)
- **Status:** accepted (extends D-033/D-034; supersedes nothing)
- **Context:** four things the calendar got wrong once it was in daily use. In Persian the score bar's
  palette read backwards (100 red, 0 green) while the thumb and the labels read forwards. Turning the
  score add-on off left the grid tinted. The map could not be turned off at all, although most people
  never use it. And in a short window the new score card painted a yellow-and-black overflow strip
  through itself while the calendar was scrolled.
- **Decision:**
  1. **A gradient's direction is the caller's decision.** `DailyScoreScale.gradient(rtl:)` swaps its own
     ends, and `SpDailyScoreBar` paints the ramp under an explicit LTR `Directionality`. The old code
     passed `Alignment.centerLeft → centerRight` and trusted the ambient `TextDirection`; the bar's
     *value* mapping (0 on the right in Persian) and the ramp's *resolved* ends disagreed, so the two
     halves of the same widget described different scales. Nothing direction-sensitive is left implicit
     now: the ends are a fact of `gradient()`, and the widget that draws them says which direction it
     means. The tests pin both ends and the inner `Directionality`.
  2. **An add-on that is off leaves no trace on the grid.** The mood calendar's `scoresByDay` is empty
     unless `enableScores` is on, so the tint, the long press and the day card all disappear together —
     one gate instead of three. Half-off states (a tint with no way to change it) were the bug.
  3. **The map is an add-on, and it defaults to on.** `AddOnType.map` / `DevicePreferencesObject.enableMap`
     hides every map surface: the sidebar item, the mobile timeline item, the map provider setting, the
     `places`/`countries` stats sections and — the one the user named — the location pin and the "add
     current location" button in a note. `null` means *on*: the map shipped before it was optional, so a
     default of *off* would quietly remove a feature from everyone who never asked. Stored places are
     never deleted, so turning it back on restores every pin.
  4. **The sidebar order is a preference, stored as names.** `SidebarItemId` + `sidebarOrder` in device
     preferences; `SidebarItemId.parse` repairs it on read (unknown names dropped, missing items appended
     in shipped order, duplicates removed), which is why adding a sidebar item later needs no migration.
     The reorder screen lists *every* item, greying out the ones an add-on currently hides, because an
     item that is off today still deserves to keep the slot the user chose for it.
  5. **Do not put a fixed-height sibling above a list that may be squeezed.** The body of the mood
     segment can shrink to almost nothing while the calendar is being scrolled in a short window; the
     score card then overflowed by 12px. It is now skipped below 140pt of body height, where it would be
     the only thing on screen anyway. A `LayoutBuilder` threshold is uglier than a `Column` that just
     fits, but it is honest about the constraint instead of painting a warning over the user's data.
- **Consequences:** the palette, the switch and the sidebar all now describe the same thing the user sees.
  The costs are accepted and named: the map's default is on (the least surprising choice for existing
  users, not the smallest app), the stats lose `places`/`countries` when the map is off (they are
  location data), and the score card is absent in a window too short to show stories — with the score
  still reachable from the trend segment and the grid.
