# Your instructions

Everything you say is recorded here, raw and dated — even if it later becomes a rule
or a decision. Rule: **we never delete, we only tag with a status.**

Status labels: `📌 rule` · `✅ decision` · `💡 idea` · `⏳ pending` · `🗄 archived`

---

## Session 1 — 2026-11-15

### N-001 — Clone the project
> "First of all, my goal is that you fully clone this project:
> https://github.com/theachoem/storypad.git — I really, really like this project."

**Status:** ✅ done (commit `cffda48`, version `2.34.0+834`).
**Ref:** D-001

### N-002 — Collaborate on changes and new features
> "I want us to change it together. Add features to it. Some parts I'll change myself
> based on what I like. Agreed?"

**Status:** 📌 collaboration model accepted.
**Note:** Until you give me the list of parts you want to change yourself, I won't
touch them — I'll only help with guidance and review.

### N-003 — Platform scope
> "For now my focus is Linux and Android. macOS and Windows are not a concern."

**Status:** ✅ recorded as decision → D-003 (platform rule in `RULES.md` §3).

### N-004 — An `ai/` folder as project memory
> "Make an `ai` folder. Store every note I give you, our general rules and decisions as
> md files there so you can review it later and we know where we are: what rules to
> follow, what our goal is, and how far the work has gone / how much is left."

**Status:** ✅ done → D-004
**Coverage:** goal (GOAL) · rules (RULES) · decisions (DECISIONS) · progress (PROGRESS)
· remaining (PROGRESS + BACKLOG) · notes (this file).

### N-005 — Write the `ai/` docs in English
> "I think it'd be nicer if you write the ai folder files in English — it's both
> prettier and easier and more understandable for you."

**Status:** ✅ done → D-006 (supersedes D-005). All `ai/` files rewritten in English;
`RULES.md` §4 now mandates English for docs.

---

## Session 2 — 2026-11-15

### N-006 — Report: running StoryPad on Fedora Linux (the working recipe)
> A full failure-to-success report. Distilled:

**Goal:** run the Flutter project as a Linux desktop app on Fedora.

**Attempt 1 — stay on the old Flutter (failed).** Created `pubspec_overrides.yaml` to pin
`animations`, `video_player`, `record`, … to older versions, deleted `pubspec.lock`, capped
`build_runner`/`json_serializable`. `pub get` succeeded and codegen ran, but compilation
failed: the project and `super_editor` use APIs that only exist in newer Flutter —
`scrollableBuilder`, `onReorderItem`, `TextInputStyle`. **Conclusion: pinning packages
cannot fix a missing SDK API.**

**Attempt 2 — install the new Flutter side by side (worked).** Cloned Flutter stable
**3.50.0 (Dart 3.14.0)** into `~/development/flutter_stable`, leaving the existing
`flutter_3.41` intact. Removed all overrides, restored `pubspec.yaml`.

**Attempt 3 — dependency conflicts.** Moved `objectbox`, `objectbox_flutter_libs`,
`objectbox_generator` to `6.0.0-preview.6` (5.x doesn't match the new SDK), and
`json_serializable` from `6.14.1` to `^6.15.2` (6.14.1 clashes with `source_helper`, so
`build_runner` itself failed to compile). Codegen then produced 90 outputs successfully.

**Attempt 4 — Fedora dev libraries.** Each CMake error named a missing `-devel` package:
`webkit2gtk-4.0` → `webkit2gtk4.1-devel` (plus a newer `desktop_webview_window`),
`libsecret-devel`, `alsa-lib-devel`, `pulseaudio-libs-devel`, `jsoncpp-devel`,
`libayatana-appindicator-gtk3-devel`, `mesa-libGL-devel`, …

**Attempt 5 — the final install error.** Build failed at install with `Permission denied`
on `/usr/local/storypad` because a stale CMake cache had that install prefix. Granting
permissions did **not** help; **`rm -rf build/linux`** did. The bundle landed in
`build/linux/x64/debug/bundle/storypad` and the app ran.

**Final state:** app runs on Linux; local ObjectBox DB and the rest work.
**Limitation:** Google sign-in / Google Drive sync are not supported on Linux
(`google_sign_in` package limitation), not an install problem — test those on Android/web.

**Daily command they used:**
```bash
cd ~/Downloads/storypad-/linux/storypad && ~/development/flutter_stable/bin/flutter run -d linux
```
(always the new Flutter in `flutter_stable`, never the one on PATH)

**Cleanup notes:** `pubspec.yaml.bak` / `pubspec.yaml.bak2` are left over and can be
deleted. The `pubspec.yaml` edits were local-only, so check before committing.

**Status:** ✅ adopted as project reality → D-007, D-008, D-009, D-010;
full detail in [`ENVIRONMENT.md`](../ENVIRONMENT.md).

### N-007 — Develop for the Linux dev loop
> "From now on, develop so that I can easily build and run the app on my Linux machine to
> see it. OK? … Forget Android too for now; let's go to Linux so that while developing I
> can run and see it easily and quickly. Agreed?"

**Status:** ✅ agreed → D-007 (Linux-only), D-010 (one-command loop).
**Note:** I treat "done" as: `bin/setup_linux` + `bin/dev --community-linux` work on
Fedora, and I always tell you what to run and what to look at.

---

## Session 3 — 2026-11-15

### N-008 — Fill Linux's feature gaps; test via CI; unlock what's locked
> "Linux unfortunately has some gaps, for example sync isn't enabled. First of all, based
> on the features Android has and Linux doesn't, add those to Linux first. Important: for
> testing, building and debugging definitely write CI for yourself and run it on GitHub
> Actions so you can see how it goes, then commit and push. Try not to put all changes in
> one commit, categorize the commits. Try to write tests and run them carefully so we
> don't have bugs. And unlock the locked features if you can so the app is complete; if
> there's something that can't work, remove that feature entirely."

**Status:** ✅ in progress → D-011, D-012, D-013
**Delivered this session:**
- All Pro features unlocked via one switch (`ProEntitlementService`) — includes
  Nextcloud/Dropbox sync, which were Pro-only.
- Dead "Connect Google Drive" tile on Linux replaced with an explanatory disabled tile;
  Linux keeps Dropbox + Nextcloud as working sync backends.
- GitHub Actions workflow (Test / Build Linux / Analyze) running on push.
- 13 unit tests covering the entitlement rules and the platform-capability matrix.
**Note (honesty):** reminders/notifications, biometrics, camera and quick actions are
*not* fixed here — they need real work (see `BACKLOG.md` I-12…I-15). I did not delete
them: the code paths are already guarded and degrade to "unavailable", and removing
Android-only features now would be premature while Android is only parked.

---

## Session 4 — 2026-11-15

### N-009 — Speed: parallelise the work, stop waiting on CI
> "I stopped you mid-work because it was taking too long. The test/action runs are getting
> very slow. Do a few things: first optimise the run process; second, while a test for one
> part is running, work on another part so it finishes in the background — speed matters to
> us. Check exactly where you were and continue."

**Status:** ✅ → D-014
**Done:** docs-only commits no longer trigger CI, codegen is cached, I never block on a run
anymore, formatting is advisory until clean. Meanwhile, in the same cycle, I fixed desktop
media picking (D-015).
**Lesson recorded:** the sandbox cannot read Actions logs (blob storage is blocked) — so CI
must report through **annotations** (`gh run view` shows them) and be judged by pass/fail.

---

## Template for a new note

```md
### N-0XX — Short title (YYYY-MM-DD)
> Verbatim or faithful summary of what you said

**Status:** 📌/✅/💡/⏳/🗄
**Ref:** D-0XX or the relevant file
**Note:** where I guessed, or what is still ambiguous
```
