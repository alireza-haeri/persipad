# Status

**Last updated:** 2026-11-15
**Current session:** session 2 — Linux dev loop
**Branch:** `arena/f59917e7-notely` (base: `a0d9f727` on `main`)
**Phase:** 🟢 base runs on your Fedora box; dev loop is one command. Ready for features.

---

## ✅ Done

### Session 1 — foundation
- [x] Imported the full `theachoem/storypad` project (commit `cffda48`, version
      `2.34.0+834`) into `alireza-haeri/notely` (files copied, upstream history not).
- [x] Documented the architecture map → [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [x] Created the `ai/` memory folder and its 7 core docs + notes folder.
- [x] All docs written in English (D-006).

### Session 2 — Linux dev loop
- [x] **App runs on Linux** — verified by you on Fedora (see Test log). This was the
      blocker; it is now resolved.
- [x] Recorded your full Fedora report, including every dead end → [`ENVIRONMENT.md`](ENVIRONMENT.md)
- [x] Toolchain baseline pinned to Flutter 3.50.0 / Dart 3.14.0 in `.tool-versions` (D-008).
- [x] Committed the SDK-required dependency bumps: `objectbox 6.0.0-preview.6`,
      `json_serializable ^6.15.2` (D-009).
- [x] `bin/dev --community-linux` / `--storypad-linux` — one command to run the desktop
      app, no `--flavor` (unsupported on Linux), auto-creates the empty community
      dart-defines file (D-010).
- [x] `bin/setup_linux` — idempotent setup: SDK detection + version warning, Fedora
      package check with a ready-to-paste `dnf` line, `pub get`, codegen (D-010).
- [x] Platform scope changed to **Linux-only; Android parked** (D-007).

## 🔄 In progress

- [ ] You pull this branch, run `bin/setup_linux` + `bin/dev --community-linux`, and we
      confirm the committed dependency bumps behave exactly like your local edits.

## ⏳ Remaining (roadmap)

### Phase 1 — close the loop (now)
- [ ] Confirm `bin/setup_linux` works from a clean checkout on your machine.
- [ ] Clean up your local leftovers: `pubspec.yaml.bak`, `pubspec.yaml.bak2`, any
      `pubspec_overrides.yaml`.
- [ ] Decide whether we keep working in your `~/Downloads/storypad-` folder or switch to
      a clone of this repo (recommended: this repo, so `git pull` brings my changes in).

### Phase 2 — first features
- [ ] Pick priorities from [`BACKLOG.md`](BACKLOG.md) together.
- [ ] Implement feature #1 (TBD).

### Phase 3 — personal redesign
- [ ] Get your list of UI/UX parts you want to change.
- [ ] Implement incrementally — one commit per change.

### Parked (do not work on)
- Android builds/Gradle, IAP/paywall for mobile, camera, quick actions, biometrics.
- macOS / Windows / iOS entirely.

## 📊 Metrics

| Metric | Value |
|---|---|
| Dart files (lib + packages) | 981 |
| Screen folders (`lib/views/`) | 32 |
| Existing tests | 92 (`test/`) + 57 (editor package) |
| Languages | 20 |
| Docs we authored | 10 files in `ai/` + root `AI.md` |
| Active platform targets | **1** (Linux desktop) |

## 🧾 Test log

| Date | Task | Verified by | Result |
|---|---|---|---|
| 2026-11-15 | Base app runs as Linux desktop on Fedora | you | ✅ runs; ObjectBox + main features work (report N-006) |
| 2026-11-15 | Committed dep bumps + `bin/dev --community-linux` + `bin/setup_linux` | you | ⏳ pending — pull and run `bin/setup_linux` |

> ⚠️ I still cannot run `flutter analyze` / `flutter test` in my sandbox (no SDK, pub.dev
> blocked). Anything I commit is verified by you, and the result goes in the table above.

### What to run now

```bash
git pull                                   # bring the committed changes in
bin/setup_linux                            # pub get + codegen (needed after the bumps)
bin/dev --community-linux                  # run the app
```

If CMake complains with `Permission denied` under `/usr/local`:
`rm -rf build/linux` and run again (the stale-prefix trap from your report).
