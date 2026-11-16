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

## 2.3.1 Checking CI (do not block on it)

```bash
bin/ci              # every workflow for the latest commit — returns in ~2s
bin/ci --wait 180   # only if waiting is actually the point
```

Rule of thumb that came out of D-020: after a push, keep working. A run that
finishes while you are busy is free; one you sit and watch costs its full length.
Verify only once, at the end of a piece of work, with `bin/ci`.

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

## 2.4.1 Verifying locally instead of in CI: `bin/dev -t`

```bash
bin/dev -t            # analyze + scoped tests + debug Linux build, one short report
bin/dev -t full       # ignore the scoper, run the whole suite
```

`-t` turns `bin/dev` from "run the app" into "verify this checkout", and prints a
report meant to be pasted back into the chat — a pass/fail line per gate plus the
analyzer errors / failing tests / compiler errors when something broke. It runs the
same three gates as `.github/workflows/linux.yml`:

1. `flutter analyze --no-fatal-infos --no-fatal-warnings` (only *errors* fail);
2. `bin/changed_tests`' selection diffed against the **previous commit** — what the
   commit you just pulled can break — or the whole suite when the working tree is dirty
   (uncommitted edits make the scoper's answer a guess);
3. `flutter build linux --debug --target=lib/main_community.dart`.

Full logs are left in `bin/.tmp/verify/`. The flavor argument is irrelevant here:
`lib/main_community.dart` is the only target this checkout can build without
`private_keys/`.

Why this exists: waiting for CI costs a push, a queue and ~2–3 minutes per iteration,
and CI remains the authority (D-036). `-t` is the fast pre-check, not a replacement.

## 2.4.2 Getting an Android APK: push `[apk]`

```bash
git commit -m "something you want on your phone [apk]"   # or: Actions -> Android -> Run workflow
```

`.github/workflows/android.yml` builds the **community** flavor on ubuntu-latest
(~18 minutes cold) and publishes a pre-release tagged `apk-<UTC date>-<sha7>` with
the APK attached, plus version, signing mode, size and sha256 in the notes.

- The marker is read from the **commit subject** only; a plain push never builds an APK.
- No secrets → the APK is `--debug`: **debug-built, debug-signed, ~207 MB**, cannot
  update a previous install. Fine for trying the app, not for a store.
- With `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD` in *Settings → Secrets and variables → Actions*, the same
  job builds a **release-signed** APK instead (smaller, updatable). Create that
  keystore once and keep it:

  ```bash
  keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 \
          -validity 10000 -alias upload
  base64 -w0 release.jks        # paste as ANDROID_KEYSTORE_BASE64
  ```

- **On your own machine, skip CI (`bin/build_apk` + `bin/android_doctor`):**
  - Run `bin/android_doctor` (or `--short`) first to check JDK 17+, Android SDK, AVDs,
    and whether `dl.google.com` is reachable or blocked.
  - If `dl.google.com` is blocked on your network, run **`bin/android_doctor --mirror`**.
    It probes Aliyun, Tencent, and Huawei mirrors for AGP `9.1.1`, `google-services:4.4.4`
    (both `.pom` and `.gradle.plugin`), and `crashlytics:3.0.6`, picks a 4/4 `200` mirror
    (Tencent `mirrors.cloud.tencent.com/nexus/repository/maven-public` or Huawei, skipping
    Aliyun if it returns 502 on `.gradle.plugin`), and writes Groovy
    `~/.gradle/init.d/notely-google-mirror.gradle` (rewriting `dl.google.com` in-place via
    `repositories.all` + `eachPlugin` mappings; never `.gradle.kts`, never appending repos).
  - Run **`bin/build_apk --install --avd=storypad_dev -v`** (or `--install` with a phone
    plugged in). It resolves `flutter` (`~/development/flutter_stable`), `adb`, and
    `emulator` even when `$SDK/platform-tools` / `$SDK/emulator` are missing from `PATH`,
    boots and waits for the AVD if requested, detects attached device ABI (`--abi auto`),
    adapts to local platforms such as `android-36.1` (`notelyCompileSdk=36` +
    `notelyCompileSdkMinor=1`) when `android-37` is absent, and sets `notelyNdkVersion=none`
    when no NDK is installed (bypassing Flutter 3.50's `forceNdkDownload` `sdkmanager` hang
    because nothing in `pubspec.lock` compiles C/C++ — see D-040).
  - First cold build downloads Maven/Gradle artifacts once; warm incremental builds take
    under a minute.
- **Verified Fedora Android environment (`/mnt/MyData/Develop/Projects/notely`):**
  JDK `17.0.19` (`amazon-corretto`), `ANDROID_HOME=~/Android/Sdk`, `platforms: android-34`
  and `android-36.1` (no `android-36` or `android-37`), `build-tools: 36.1.0 37.0.0`,
  no `ndk` / no `cmake`, AVD `storypad_dev` (`x86_64`), active Gradle mirror: Tencent.
- `storypad` (the upstream flavor) is **not** buildable here: it needs `private_keys/`.
- Local store builds via `bin/build_release_android` expect `private_keys/` and
  `codemagic-cli-tools`, and upload to Play/Firebase. The `community` workflow and
  `bin/build_apk` exist so nobody has to reproduce that setup to get an APK.

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
| Drive tile says "Google Drive needs one setup step" | this build has no OAuth client id | `bin/setup_sync --google-json ~/Downloads/client_secret_*.json`, then restart `bin/dev` (D-019) |
| Browser: `Error 400: invalid_client` when connecting Drive | empty/wrong `GOOGLE_DESKTOP_CLIENT_ID`, or a client of type Web/Android instead of **Desktop app** | recreate the credential as Desktop app; check `bin/setup_sync --show` |
| Browser: `Error 400: invalid_scope` | the scope is not listed on the OAuth consent screen | Google Auth Platform → Data access → add `drive.appdata`, `openid`, `userinfo.email`, `userinfo.profile` |
| Browser: "Access blocked … has not completed verification" / app not found | Google project is in Testing and your account is not a test user | add the account under Audience → Test users, or publish the app |
| Drive re-asks for sign-in every ~7 days | consent screen still in **Testing** (Google expires refresh tokens after 7 days) | publish the app (non-sensitive scopes, no review needed) |
| `Invalid client_id: ""` page from Dropbox | `DROPBOX_APP_KEY` is empty in the build | `bin/setup_sync --dropbox-key <app key>`; Dropbox app needs redirect `http://localhost:8763/callback` |
| `objectbox.g.dart: Error: Method not found: 'loadObjectBoxLibraryAndroidCompat'` | committed generated code is older than the pinned objectbox 6 preview | run `bin/build_runner --delete` once (or `bin/setup_linux`); `bin/dev` now catches this in a second (D-016) |
| `bin/dev` refuses to start: "Generated code has not been built in this checkout" | codegen stamp missing (fresh clone or pubspec change) | `bin/setup_linux`, or bypass once with `SKIP_CODEGEN_CHECK=1` |
| `bin/build_apk`: `dl.google.com` 404 or `google-services:4.4.4` 502 from Aliyun | Google Maven blocked or mirror lacks `.gradle.plugin` marker POMs | run `bin/android_doctor --mirror` (selects 4/4 healthy Tencent/Huawei mirror, removes stale `.gradle.kts`) |
| Gradle fails on `notely-google-mirror.gradle.kts` or `RepositoriesMode` (`prefer settings repositories`) | old Kotlin DSL init script or mirror script appended `repos.maven` instead of rewriting URLs | run `bin/android_doctor --mirror` to overwrite with Groovy in-place `repos.all` script |
| Android build hangs 5+ min in `:app` on `sdkmanager --install ndk;28.2.13676358` | Flutter 3.50 `forceNdkDownload` calls `sdkmanager` even when nothing builds C/C++ | ensure `notelyNdkVersion=none` (`bin/build_apk --no-ndk` sets it automatically; D-040) |
| Android build fails looking for `platforms;android-36` when machine has `android-36.1` | plugins pin `< 36`, `android/build.gradle.kts` raises to `36` without minor | fixed in `d3d534e`: `notelyCompileSdkMinor` aligns `app` and `LibraryExtension` plugins to `36.1` |
| `emulator: command not found` or `bin/build_apk --install` exited silently with no device | SDK `emulator/`/`platform-tools/` not on `PATH`; `pipefail` tripped on empty `adb` | fixed in `0cb892f`: `bin/build_apk` resolves `$SDK/{emulator,platform-tools}` and adds `--avd` |

## 2.6 Known Linux limitations (product-level, not build errors)

These are expected behaviours on Linux and must not be "fixed" by hacking:

- **Firebase is off** — `firebase_initializer.dart` returns early on Linux, so
  Analytics / Crashlytics / RemoteConfig are no-ops. Never assume they run.
- **Drive sync works only between builds that share one OAuth client id** (D-021).
  The official StoryPad and this fork use different clients, so each sees a
  different hidden appDataFolder — both report "synced" and neither sees the
  other's notes. That is Google's design, not a bug here. Cross-app movement is
  via Nextcloud/WebDAV or JSON export/import; Drive is for this fork's own
  devices (see `BACKLOG.md`, I-12…I-14).
- **Google Drive sync works, after a one-time OAuth client** (D-019). Linux cannot
  use `google_sign_in`, so the app runs the installed-app OAuth2 flow itself and
  needs a client id in the build: `bin/setup_sync`. Without it the Drive tile
  explains the setup instead of opening a browser.
- **Dropbox sync works, after an app key** — same script, `--dropbox-key`. Empty
  key produces Dropbox's `Invalid client_id: ""` page.
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
