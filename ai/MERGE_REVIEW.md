# Parallel branch integration review — 2026-11-16

Integration branch: `arena/41be3147-notely`, based on main `a0d9f72`.
The two parent tips are `c493919` (c5) and `a676be3` (e3e).
`arena/f59917e7-notely` is an ancestor of c5 and `ci/codegen` is an
ancestor of e3e. Original `ai/` snapshots for all four branches are retained
under `merge-history/`; they describe historical states, not this integration.
The lightweight decision formerly numbered D-041 on e3e is D-047 here, so it
does not collide with c5's D-041.

## Review findings and integration decisions

- The e3e lightweight change (`D-047`) removes maps/location, sounds, period calendar,
  font picker, IAP/paywall and non-Drive backup providers, plus 19 locales. **Confirmed
  by the user (`N-020`):** these features were intentionally removed to eliminate bloat.
- **Offline dual-font typography (`D-048`):** per `N-020`, Persian uses bundled `Vazirmatn`
  and English uses bundled `Quicksand` (`Quicksand-Variable.ttf`), both shipped in
  `assets/fonts/` with zero network dependency (`google_fonts` remains removed).
- **DST-safe civil date arithmetic (`D-049`):** local Fedora verification (`Asia/Tehran`)
  caught a DST transition bug (`1991-05-03` spring-forward) hidden on UTC CI runners;
  fixed across `PersianCalendar`, `OnThisDayPredictionService`, `StatsRange`, and
  `StoryStatsService`.
- The e3e Drive change replaces the prior native Android sign-in with desktop
  OAuth/PKCE and loopback, to share an appDataFolder with Linux. Neither real
  cross-platform sign-in nor migration of existing provider data has been proven
  here; verify on a real phone and Linux using actual credentials before relying
  on sync. A packaged OAuth client secret is not confidential.
- Fedora's `:jni` build needs NDK and CMake. The e3e scripts attempt to provision
  them and propagate the installed NDK; no end-to-end Fedora build result has
  been reported. Run `bin/android_doctor --fix`, then `bin/build_apk --install
  --avd=storypad_dev` on the user's machine to verify.
- The c5 search optimization, backup test seam, accessibility work, tests, CI
  gates, and bundled Quicksand font are retained. The e3e theme deliberately uses
  a system font for English and Vazirmatn for Persian, so the Quicksand asset is
  bundled but is not the active English theme. This difference needs a product
  decision rather than being represented as preserving both behaviors.
- `linux.yml` uses c5's more informative failure annotation implementation; both
  branches intended to eliminate false error annotations on successful tests.
- Historical docs can contradict this review: c5's analysis and handoff describe
  the pre-trim app. The snapshot files preserve both agents' original reports.

## Verification

The individual branch CI results are not proof that the combination works.
Verified on the integrated commit:
- **GitHub Actions Linux CI (`43854176350`):** 7/7 jobs green (`Scope`, `Analyze`, `Test (1)`, `Test (2)`, `Editor package tests`, `Build Linux desktop`, `Coverage` 14.7%).
- **GitHub Actions Android CI (`43849981463`):** `Build APK` + `Verify the APK` (fail-closed `apksigner` signature check + Python regression tests) green.
- **Fedora 44 local verification (`bin/local_verify`):** `analyze` PASS (`12s`), `root tests` PASS (`+1087`, `56s`), `editor tests` PASS (`+11088` steps, `24s`), `linux build` PASS (`13s`), and `android apk` PASS (`1m32s`, with `NDK 28.2.13676358` + `CMake 3.22.1` + `android-36.1` + Tencent mirror).
- Consolidated onto `main` via PR and pruned merged feature branches (`arena/c5b3ddac-notely`, `arena/e3e3866a-notely`, `arena/f59917e7-notely`, `ci/codegen`). Real-device Google Drive OAuth sign-in remains an optional E2E check once user OAuth credentials are configured via `bin/setup_sync`.

The integration review also found that the APK verification step ignored a
nonzero `apksigner verify` exit status. The workflow now fails closed on an
invalid signature. A `[apk-test]` subject builds and verifies without creating a
GitHub pre-release; `[apk]` and manual dispatch retain their existing release
behavior. Python regression tests in `test/ci/` run as part of that workflow.
