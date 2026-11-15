# Status

**Last updated:** 2026-11-15
**Current session:** session 3 — Linux feature parity + CI
**Branch:** `arena/f59917e7-notely` (base: `a0d9f727` on `main`)
**Phase:** 🟡 features landing; waiting on the first green CI run

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

## 🔄 In progress

- [ ] First CI run for this branch — checking whether `flutter test` and
      `flutter build linux` pass on GitHub's runners.

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

## 📊 Metrics

| Metric | Value |
|---|---|
| Dart files (lib + packages) | 983 (+2 new services) |
| Active platform targets | **1** (Linux desktop) |
| Blocking CI jobs | 2 (Test, Build Linux desktop) |
| Tests added by us | 13 |
| Existing tests | 92 + 57 (editor package) |
| Pro feature gates opened by one switch | ~30 call sites |

## 🧾 Test log

| Date | Task | Verified by | Result |
|---|---|---|---|
| 2026-11-15 | Base app runs as Linux desktop on Fedora | you | ✅ runs; ObjectBox + features work (N-006) |
| 2026-11-15 | Dep bumps + `bin/dev --community-linux` + `bin/setup_linux` | you | ⏳ pending |
| 2026-11-15 | Pro unlock + capability layer + CI | GitHub Actions | ⏳ pending first run |

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
