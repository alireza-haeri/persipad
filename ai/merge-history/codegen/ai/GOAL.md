# Project goal

## One-liner

We are building a personal/product fork of [StoryPad](https://github.com/theachoem/storypad):
a privacy-first, offline-first journal and writing app in Flutter, with our own
features layered on top and parts of the UX redesigned to our taste.

## What we want

1. **Understand the codebase fully** — before any big change, we should know where
   everything lives and why it was designed that way.
2. **Add new capabilities** on top of the existing foundation without breaking the
   architecture or the existing test suite.
3. **Redesign selected parts** that don't match our taste (UI/UX, flows).
4. **Keep privacy and offline-first as non-negotiables.**
5. **First-class Linux support + reproducible `community` Android APKs** in every
   change we make, with fast one-command local loops (`bin/dev`, `bin/build_apk`).
6. **Next product milestone (pending scope):** build a **lightweight phone version**
   of the app once the local Android APK loop is verified end-to-end (N-015).

## Out of scope (for now)

- **Android (`community` flavor):** **active again** via `.github/workflows/android.yml`
  (`[apk]` pre-releases, D-038/D-039) and local `bin/build_apk` + `bin/android_doctor`
  (D-040). The `storypad` flavor remains out of scope without `private_keys/`.
- macOS / Windows: **explicitly out of scope**. Their code stays in the tree, but we
  don't test, optimize, or add complexity for them.
- iOS: inactive scope (keep the code, no testing commitment).
- Web: out of scope.
- Public app-store releases: out of scope for now; this is a personal/local product.

## Product direction (default until you say otherwise)

- The "daily journal" experience must stay fast and simple; new features must never
  slow writing down.
- No data leaves the device without explicit consent (all cloud services optional).
- Every new feature must work offline; cloud is a complement, never a prerequisite.

## Open questions about the goal

- [ ] Final product name: keep `StoryPad`, or use our own brand (the repo is `notely`)?
- [ ] Will this fork ever be public (GPLv3 → modifications must stay open source)?
- [ ] Do we keep the paid features (StoryPad Pro / RevenueCat) or remove them?
- [ ] Is 20-language support needed, or are Persian + English enough?

Answers get recorded in [`DECISIONS.md`](DECISIONS.md) as they arrive.
