# Parallel branch integration review — 2026-11-16

Integration branch: `arena/41be3147-notely`, based on main `a0d9f72`.
The two parent tips are `c493919` (c5) and `a676be3` (e3e).
`arena/f59917e7-notely` is an ancestor of c5 and `ci/codegen` is an
ancestor of e3e. Original `ai/` snapshots for all four branches are retained
under `merge-history/`; they describe historical states, not this integration.
The lightweight decision formerly numbered D-041 on e3e is D-047 here, so it
does not collide with c5's D-041.

## Review findings and integration decisions

- The e3e lightweight change removes maps/location, sounds, period calendar,
  font picker, IAP/paywall and non-Drive backup providers, plus 19 locales. It
  applies to the shared app, not just the phone. These are deliberate deletions
  from that branch, but whether all are acceptable for the combined product
  needs explicit user review. Their original code remains in Git history.
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
Run full Linux analyze, app and editor tests, coverage and Linux build on the
integration commit. Android build and real-device OAuth/Fedora validation remain
separate checks. Do not delete source branches or merge into main until the
integration is reviewed and verification succeeds.
