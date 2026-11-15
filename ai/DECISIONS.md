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
