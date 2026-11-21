# Working rules

> These are our standing agreements. Every new rule you give me is first recorded in
> [`notes/user-instructions.md`](notes/user-instructions.md), then folded into this file.

## 1. Git & branch rules

- We **always** work on the current active branch named by Arena's session context
  (`main` holds the integrated baseline; per-session Arena branches merge back into
  `main` via PR once verified). Never switch to, create, push to, or rename another
  branch unless you are explicitly working in a new session attached to that branch.
- Commits are small and focused. Messages in English, Conventional Commits style:
  `feat: ...`, `fix: ...`, `docs(ai): ...`, `refactor: ...`, `chore: ...`.
- **After each completed requested change/task, commit and push the result to the
  current active branch before replying.** Do not leave completed changes only in the
  local checkout. Never push to another branch. If a push is blocked (for example,
  remote changes or an authentication problem), explain the blocker and do not claim
  the change was pushed.
- The upstream history is pinned as a reference point (commit `cffda48`). We never
  rebase or force-push over it.
- Generated files (`.dart_tool/`, `build/`, `*.g.dart`) are only committed when the
  repo already tracks them. The committed `*.g.dart` files must be regenerated with
  `bin/build_runner` — **never edit them by hand**.

## 2. Code rules

- Language/style: Dart with the existing `flutter_lints` + `analysis_options.yaml`.
  `dart format` is mandatory.
- We **do not break** the existing MVVM + Provider architecture:
  - One screen = `XView` + `XViewModel` + `XContent` (+ a model if needed).
  - Business logic lives in the ViewModel, never in a widget.
- Data access goes through the models' static `.db` boxes (e.g. `StoryDbModel.db`) or
  through `lib/core/services/...`. Views never touch ObjectBox directly.
- Every user-visible string gets a key in `translations/*.json` and is read via
  `.tr()`. No hard-coded UI text.
- Paid/exclusive features are gated via existing flags (`kSupport*`, `kIAPEnabled`),
  not with ad-hoc `if (Platform...)` sprinkled around.
- Any platform-specific change must use `Platform.isLinux` / `Platform.isAndroid` and
  carry an explanatory comment (see the existing pattern in `app_constants.dart`).
- **Privacy**: no log, error report, or telemetry may leak file paths, server names,
  or the user's note content.

## 3. Platform rules

- **Active targets: Linux desktop and Android (`community` flavor).**
  Every change should keep `bin/dev --community-linux` / `bin/dev -t` working on Fedora,
  and shared/Android changes must not break `bin/build_apk` or `.github/workflows/android.yml`
  (D-038, D-039, D-040). The `storypad` flavor stays out of scope (`private_keys/` absent).
- **Keep both dev loops fast and one-command:**
  - Linux: `bin/setup_linux` + `bin/dev --community-linux` (and `bin/dev -t` for local checks).
  - Android: `bin/android_doctor` + `bin/build_apk --install` (auto-adapts to local SDKs
    such as `android-36.1` and `--no-ndk` without touching `dl.google.com`).
- **Do not break Android local builds:**
  - Do not remove `notelyCompileSdkMinor`, `flutter.installedNdkVersions` (`notelyNdkVersion=none`),
    or the `LibraryExtension.compileSdk >= 36` floor in `android/build.gradle.kts` /
    `android/app/build.gradle.kts` (D-040).
  - Do not add plugins with C/C++ native builds without discussing NDK impact first.
- **Do not add a dependency that lacks Linux support** without an explicit decision and
  a `Platform.isAndroid` / `PlatformCapabilities` guard so Linux degrades cleanly.
- When a package is disabled on Linux (Firebase, biometrics, IAP, camera, quick actions,
  video compression), the code path must still work — no silent no-op that looks like a bug.
- macOS / Windows / iOS: no commitment. Their code must not be deleted, but we don't
  spend time on them and we don't add complexity for them.

## 3b. Verification rules (CI + local fast gates)

- **CI is the compiler for the sandbox.** I cannot run Flutter here, so `.github/workflows/linux.yml`
  must be green before I call a code change done:
  - `Scope` (`bin/changed_tests`) selects only the tests affected by the diff, or skips
    them for `ai/`/`bin/`/`.github/` (except `.github/workflows/**`)/`*.md`, or runs the
    full 2-shard suite on unmapped/`pubspec`/`android`/subject `[test]`/`[full]`.
    Its output keys are **`mode`, `build`, `packages`, `shards`, `paths`** (D-045) —
    `packages=true` means the editor package's own suite must run as a separate job.
  - `Analyze` runs `flutter analyze --no-fatal-infos --no-fatal-warnings` (errors fail;
    formatting check is advisory via annotations — T-7).
  - `Test` runs the selected files in 1 shard (scoped) or 2 (full). **A green run must
    produce no `::error::` annotation** (D-046); if one appears on a passing job, that is
    a bug in the workflow, not in the tests.
  - `Editor package tests` runs `packages/storypad_editor`'s 57 files / ~390 cases when
    `packages=true`. **`[full]` sets it too** — the full marker means *everything*.
  - `Build Linux desktop` runs on `[build]` / `[full]` / PRs.
  - `Coverage` is advisory on `[full]`/PRs: lcov artifact + a percentage notice
    (`ANALYSIS.md` §6). No threshold yet; do not add one without a decision.
  - `.github/workflows/android.yml` builds the `community` arm64 APK on `[apk]` in commit
    subject (or `workflow_dispatch`) and publishes a pre-release.
- **Markers are read from the commit SUBJECT only** (`[full]`, `[test]`, `[build]`,
  `[apk]`, `[codegen]`). A body that merely mentions one must not spend the work.
- **An empty commit triggers nothing.** `[full]` on an `--allow-empty` commit produces
  zero runs; the marker needs a real file change to fire (`PROGRESS.md` verification log).
- **Fast local verification:** the user can run `bin/dev -t` on Fedora before pushing, and
  `bin/build_apk --install` for Android.
- Every behavioural change ships with tests in `test/` (pure logic is preferred over
  widget tests so it stays fast and hermetic).
- Never leave a dead button: if a capability can't work on a platform, the UI must say so or
  the feature must go — see `PlatformCapabilities`.
- If CI is red, the task is not done — no exceptions, no "probably fine".

## 4. Documentation rules (this folder)

- End of every task: update `PROGRESS.md` (ticks + metrics + date).
- Every technical/product decision: a numbered entry in `DECISIONS.md`.
- Every instruction from you: raw, dated entry in `notes/user-instructions.md`.
- Anything pending a decision sits in `BACKLOG.md` with a `⏸` label.
- **Language: English.** Code identifiers, file names and commands stay English anyway,
  and this keeps the docs readable for both of us and for any future agent.

## 5. Collaboration rules

- When a request has several valid approaches, I present the options with costs and
  benefits **before** implementing, and you decide — unless you told me to just decide.
- No large, surprise refactors without coordination.
- Whenever I guess something, I say so explicitly.
- I never hide environment limitations (e.g. no Flutter SDK in the sandbox).

## 6. Quality checklist before saying "done"

- [ ] `dart format` on touched files (when the tool is available).
- [ ] New logic is testable and, where reasonable, covered in `test/`.
- [ ] Both active paths considered: Linux (`bin/dev --community-linux` / `bin/dev -t`) and Android `community` (`bin/build_apk`).
- [ ] New strings are added to **all 21** `translations/*.json` files (parity enforced by `unused_translations_test.dart`).
- [ ] I told you exactly what to run (`bin/dev -t`, `bin/dev --community-linux`, or `bin/build_apk --install`) and what to check.
- [ ] `ai/PROGRESS.md` updated, `ai/DECISIONS.md` updated if a decision was made.
