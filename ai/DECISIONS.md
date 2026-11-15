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
- **Status:** accepted
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
