# Working rules

> These are our standing agreements. Every new rule you give me is first recorded in
> [`notes/user-instructions.md`](notes/user-instructions.md), then folded into this file.

## 1. Git & branch rules

- We **always** work on the current branch: `arena/f59917e7-notely`.
  No other branch is created or switched to; renaming is not possible either.
- Commits are small and focused. Messages in English, Conventional Commits style:
  `feat: ...`, `fix: ...`, `docs(ai): ...`, `refactor: ...`, `chore: ...`.
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

- **Only Linux is an active target right now.** Android is parked (temporarily out of
  scope, not abandoned — see D-007). Every change must be verifiable with
  `bin/dev --community-linux` on your Fedora box.
- **Linux is the dev loop I optimize for:** build and run must stay fast and one-command.
  If a change makes `bin/setup_linux` + `bin/dev --community-linux` fail, it is not done.
- **Do not add a dependency that has no Linux implementation** without an explicit
  decision. If a package is Android-only, gate it behind `Platform.isAndroid` and make
  sure the Linux UI degrades gracefully (message instead of crash).
- When a package is disabled on Linux (Firebase, biometrics, IAP, camera, quick actions,
  video compression, Google sign-in), the code path must still work — no silent no-op
  that looks like a bug.
- macOS / Windows / iOS: no commitment. Their code must not be deleted, but we don't
  spend time on them and we don't add complexity for them.
- If a change would break macOS/iOS compilation, prefer a platform guard over a global
  change — but don't block on verifying it.

## 3b. Verification rules (Linux, no local SDK)

- **CI is the compiler.** I cannot build here, so `.github/workflows/linux.yml` must be
  green before I call anything done: **Test** and **Build Linux desktop** are blocking,
  **Analyze** is advisory.
- Every behavioural change ships with tests in `test/` (pure logic is preferred over
  widget tests so it stays fast and hermetic).
- Never leave a dead button: if a capability can't work on Linux, the UI must say so or
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
- [ ] The Linux path was considered (Android is parked, but guards must not break it).
- [ ] New strings are translated.
- [ ] I told you exactly what to run (`bin/dev --community-linux`) and what to look at.
- [ ] `ai/PROGRESS.md` updated, `ai/DECISIONS.md` updated if a decision was made.
