# Environment & builds

Two different machines are involved. Keep them separate in your head.

| | Who | Role |
|---|---|---|
| **Sandbox** | me (the agent) | I edit, commit, push. I cannot build. |
| **Fedora box** | you | The only place the app is compiled and run. |

Everything below was verified by you on 2026-11-15 (see `notes/user-instructions.md` N-006).

---

# 1. The sandbox (my side) — cannot build

| Item | Status | Meaning |
|---|---|---|
| Flutter SDK | ❌ not installed | `flutter` / `dart` are not on PATH |
| `pub.dev` reachable | ❌ blocked | `flutter pub get` is impossible |
| `storage.googleapis.com` / `dl.google.com` | ❌ blocked | cannot download SDK/NDK |
| `services.gradle.org` | ❌ blocked | no Gradle/Android build |
| `github.com`, `api.github.com`, `codeload` | ✅ open | clone/push/PR work |
| `registry.npmjs.org`, `pypi.org` | ✅ open | (irrelevant here) |

**Consequence:** I never claim "it builds". I read code, write code, and hand you a
short checklist of what to run. `flutter analyze` / `flutter test` are **your** job,
and their result goes into `PROGRESS.md` → Test log.

---

# 2. The Linux dev box (yours) — this is the target

## 2.1 Toolchain

| Thing | Value |
|---|---|
| Distro | Fedora |
| Flutter | **3.50.0 stable / Dart 3.14.0** at `~/development/flutter_stable` |
| Old Flutter | `flutter_3.41` (Dart 3.11) still installed — **must not be used**, it cannot compile this project |
| Repo | must be the repo root; `flutter run` is always launched from there |

Why 3.50.0 is mandatory: StoryPad (and `super_editor`) use APIs that only exist in the
newer Flutter — `scrollableBuilder`, `onReorderItem`, `TextInputStyle`. Pinning package
versions does **not** fix that; the SDK itself has to be new enough.

`.tool-versions` in this repo now says `flutter 3.50.0-stable`, matching your box.

## 2.2 System packages (Fedora)

Each CMake failure in your run pointed at one missing `-devel` package. Full list:

```bash
sudo dnf install -y \
  clang cmake ninja-build pkgconf-pkg-config \
  gtk3-devel \
  webkit2gtk4.1-devel \
  libsecret-devel \
  alsa-lib-devel \
  pulseaudio-libs-devel \
  jsoncpp-devel \
  libayatana-appindicator-gtk3-devel \
  mesa-libGL-devel
```

`bin/setup_linux` checks all of these and prints exactly the missing ones (it never
runs sudo itself).

## 2.3 Package overrides required by the newer SDK

These are now **committed in `pubspec.yaml`**, not local hacks (D-009):

| Package | Was | Now | Why |
|---|---|---|---|
| `objectbox` | 5.3.2 | 6.0.0-preview.6 | 5.x does not compile against Dart 3.14 |
| `json_serializable` | 6.14.1 | ^6.15.2 | 6.14.1 conflicts with `source_helper`; build_runner itself fails to compile |

`build_runner` then produces ~90 outputs. `objectbox.g.dart` and
`lib/objectbox-model.json` are **generated**: they must be regenerated after this bump.
`bin/setup_linux` does that for you.

## 2.4 Daily loop

```bash
# from the repo root, once per fresh clone / after pulling dependency changes
bin/setup_linux

# then, every time
bin/dev --community-linux
```

`bin/setup_linux` = resolve SDK → check system packages → `flutter pub get` →
`bin/build_runner --delete`. It is idempotent, so it is safe to run anytime something
feels stale.

If you prefer the raw command (e.g. for a debugger / IDE launch config):

```bash
~/development/flutter_stable/bin/flutter run -d linux \
  --target=lib/main_community.dart \
  --dart-define-from-file=bin/.tmp/private_keys/dart_defines/community.json
```

> Note: **no `--flavor` on Linux.** `flutter run -d linux` rejects flavors; `bin/dev`
> drops it for the `-linux` targets. `bin/dev` also auto-creates the (empty)
> `community.json` dart-defines file when the `private_keys/` submodule is absent, so
> RevenueCat / Maps / Google Sign-In simply no-op instead of failing the build.

## 2.5 Troubleshooting (all of these actually happened)

| Symptom | Cause | Fix |
|---|---|---|
| `pub get` fails, then Dart compile errors in `super_editor` | old Flutter (3.41 / Dart 3.11) | use `~/development/flutter_stable` (3.50.0) |
| `build_runner` won't compile, `source_helper` conflict | `json_serializable` 6.14.1 | `^6.15.2` (committed) |
| objectbox fails to compile | objectbox 5.x vs Dart 3.14 | 6.0.0-preview.6 (committed) |
| CMake: `webkit2gtk-4.0` not found | package renamed | `webkit2gtk4.1-devel` |
| CMake: `libsecret-1`, ALSA, `jsoncpp` not found | missing `-devel` | see 2.2 |
| `flutter pub get` complains about stale lock | `pubspec.yaml` changed | `flutter pub get` (setup script does it) |
| Install step: `Permission denied` on `/usr/local/storypad` | CMake install prefix cached from an older build | `rm -rf build/linux` and rebuild — granting permissions does **not** help |
| Google sign-in / Drive sync unavailable | `google_sign_in` has no Linux support | expected; test that path on Android later |
| `objectbox.g.dart: Error: Method not found: 'loadObjectBoxLibraryAndroidCompat'` | committed generated code is older than the pinned objectbox 6 preview | run `bin/build_runner --delete` once (or `bin/setup_linux`); `bin/dev` now catches this in a second (D-016) |
| `bin/dev` refuses to start: "Generated code has not been built in this checkout" | codegen stamp missing (fresh clone or pubspec change) | `bin/setup_linux`, or bypass once with `SKIP_CODEGEN_CHECK=1` |

## 2.6 Known Linux limitations (product-level, not build errors)

These are expected behaviours on Linux and must not be "fixed" by hacking:

- **Firebase is off** — `firebase_initializer.dart` returns early on Linux, so
  Analytics / Crashlytics / RemoteConfig are no-ops. Never assume they run.
- **Google sign-in + Google Drive sync are unavailable** — the `google_sign_in`
  package has no Linux implementation. The repo does contain
  `GoogleDriveLinuxCloudService` (loopback OAuth), but there is no usable sign-in
  flow today. Treat Drive sync as unsupported on Linux; local backup/export is the
  Linux path. Tracked in `BACKLOG.md` as I-7.
- **IAP off** (`kIAPEnabled` is Android/iOS/macOS only) — any paywall must be
  escapable without purchasing.
- **Biometrics off** (`local_auth_service.dart`) — PIN lock is what remains.
- **Camera / quick actions / video compression off** — `kSupportCamera`,
  `kSupportQuickActions`, `kSupportVideoCompression`.

## 2.7 Cleanup notes from your run

- Backup files `pubspec.yaml.bak`, `pubspec.yaml.bak2` were left in your project folder —
  delete them; the real values are now committed.
- Any `pubspec_overrides.yaml` you created while testing package pins must be removed,
  or it will silently override what we commit.
