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

- Priority 1: **Android** — first-class, fully supported.
- Priority 2: **Linux** — supported but second-class today (Firebase, biometrics, IAP
  are disabled there).
- macOS / Windows / iOS: no commitment. Their code must not be deleted, but we don't
  spend time on them.

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
- [ ] Both Android **and** Linux paths were considered (at minimum by reading code).
- [ ] New strings are translated.
- [ ] `ai/PROGRESS.md` updated, `ai/DECISIONS.md` updated if a decision was made.
