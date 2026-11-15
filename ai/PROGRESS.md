# Status

**Last updated:** 2026-11-15
**Current session:** session 4 — Linux feature parity + a CI loop that doesn't block
**Branch:** `arena/f59917e7-notely` (base: `a0d9f727` on `main`)
**Phase:** 🟢 CI fully green (Test / Analyze / Build Linux) — features landing

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

- **Committed `*.g.dart` is stale** relative to the pinned objectbox 6 generator (proved by
  CI): every job must run `build_runner`. Committing the regenerated output would cut
  ~2 minutes per job — `BACKLOG.md` T-6.
- **Formatting gate is advisory** even though it is currently green (`BACKLOG.md` T-7). The
  sandbox cannot run `dart format`, so a blocking gate would cost a full round trip per
  line-break guess.
- **Desktop multi-select** degrades to a single file dialog (`BACKLOG.md` T-8).

## 📊 Metrics

| Metric | Value |
|---|---|
| Dart files (lib + packages) | 983 (+2 new services) |
| Active platform targets | **1** (Linux desktop) |
| Blocking CI jobs | 2 (Test, Build Linux desktop) + advisory format |
| Tests added by us | 18 |
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
