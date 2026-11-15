# Environment & builds

## The sandbox I work in — important

Checked on 2026-11-15:

| Item | Status | Meaning |
|---|---|---|
| Flutter SDK | ❌ not installed | `flutter` / `dart` are not on PATH |
| `pub.dev` reachable | ❌ blocked | `flutter pub get` is impossible |
| `storage.googleapis.com` / `dl.google.com` | ❌ blocked | cannot download SDK/NDK |
| `services.gradle.org` | ❌ blocked | no Gradle/Android build |
| `github.com`, `api.github.com`, `codeload` | ✅ open | clone/push/PR work |
| `registry.npmjs.org`, `pypi.org` | ✅ open | (irrelevant for this project) |

**Practical consequence:**

- I **can** read, write, refactor, document, commit and push code.
- I **cannot** run `flutter analyze`, `flutter test`, or any build here.
- So **you are the final verifier**, on your own machine (Linux or Android).
- To compensate I: keep changes small, copy existing code patterns exactly, and end
  every task with an explicit "what you should test" note.

If any of this changes (e.g. a pub mirror becomes reachable), this table gets updated
and we can automate the static analysis.

## Your machine's prerequisites

From `.tool-versions` and `README.md`:

- Flutter `3.47.4-stable` (the README still says 3.29; `pubspec.yaml` requires
  `sdk: ^3.11.0` — **`.tool-versions` is the authoritative one**)
- Java 21 (`openjdk-21`) for Android
- Node 24, Python 3.12 (only for scripts in `bin/`)
- Android: minSdk 24, compileSdk 37
- Linux: standard Flutter desktop toolchain
  (`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`)

## Daily commands

```bash
# dependencies + codegen
flutter pub get
bin/build_runner --delete        # occasionally needed, since *.g.dart is committed

# Android (public flavor; the "storypad" flavor needs private keys)
bin/dev --community

# Linux (bin/dev has no linux target, run directly)
flutter run -d linux --target=lib/main_community.dart \
  --dart-define-from-file=bin/.tmp/private_keys/dart_defines/community.json
# If that dart-defines file doesn't exist yet, run `bin/dev --community` once so
# sync_private_keys creates it, or pass the --dart-define flags manually.

# quality
dart format lib packages
flutter analyze
flutter test
flutter test packages/storypad_editor
```

### Linux notes

`bin/dev` has no `--linux` input (only android/ios/macos). We can add
`--community-linux`; that idea is tracked in [`BACKLOG.md`](BACKLOG.md) as I-1.

These are deliberately disabled or replaced on Linux — keep them in mind when testing:

- Firebase (`firebase_initializer.dart`: `if (Platform.isLinux) return;`) → Analytics,
  Crashlytics and RemoteConfig become no-ops; never assume they work.
- Local auth / biometrics (`local_auth_service.dart`) → the PIN lock is what remains.
- IAP (`kIAPEnabled` only Android/iOS/macOS) → the paywall must be escapable without
  a purchase on Linux.
- Google Drive uses a separate path: `GoogleDriveLinuxCloudService` (loopback OAuth).
- Camera, quick actions, video compression are unavailable on Linux:
  `kSupportCamera`, `kSupportQuickActions`, `kSupportVideoCompression`.

## Known hazards

- `lib/main_storypad.dart` and `lib/firebase_options/storypad.dart` are gitignored →
  the `storypad` flavor fails without private keys. Use `--community`.
- `*.g.dart` files are committed; if you change a model and skip build_runner you get
  confusing errors.
