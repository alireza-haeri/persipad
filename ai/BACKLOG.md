# Backlog & ideas

Labels: `💡 idea` (undecided) · `⏸ awaiting decision` · `🔜 next` · `🚧 in progress` · `✅ done`

> Nothing in this list starts without your approval. The point of this file is to keep
> options visible, not to commit to them.

## 0. Linux infrastructure (the only active platform)

| # | Item | Why |
|---|---|---|
| I-1 | `✅` Add `--community-linux` to `bin/dev` (+ `bin/setup_linux`) | Done — see D-010 |
| I-2 | `💡` `bin/check` script = format + analyze + test | No local CI; convenient pre-push check |
| I-3 | `💡` Detect plugins that are no-ops on Linux and show a clear UI message | Linux users currently just see "it doesn't work" |
| I-4 | `💡` Review `GoogleDriveLinuxCloudService` (loopback OAuth) | The most important backup path on Linux |
| I-5 | `💡` Linux coverage: `flutter test` + check `Platform.isLinux` in new code | Prevent regressions |
| I-6 | `💡` Gradually remove dead macOS/iOS branches from shared flows (without deleting platform code) | Reduces complexity |
| I-7 | `🔜` Clear UI messaging for features that are unavailable on Linux (Google sign-in / Drive sync, biometrics, IAP, camera) | Users currently see a silent no-op or a raw error; this is now the top Linux UX gap |
| I-8 | `💡` Decide the Linux backup story (local export + folder backup) since Drive sync is unusable there | Data safety is the one thing we should not hand-wave |
| I-9 | `💡` Keep a `bin/test` alias for `flutter test` + `flutter analyze` so I can ask for one command | Faster verification loop |
| I-10 | `⏸` CI: `.github/workflows/ci.yml` still targets `develop` and Android-era setup | Retarget to Linux or drop |

## 1. Product features (candidates)

Generic journaling-app ideas; your preferences set the priority.

| # | Idea | Value | Rough cost |
|---|---|---|---|
| F-1 | Smart daily template (prompt suggested from date/weather/history) | high | medium |
| F-2 | Local Markdown file binding (a folder on disk, Obsidian-compatible) | high (especially Linux) | medium |
| F-3 | Better global search: fast tag + feeling + date-range filter UI | medium | low |
| F-4 | Writing stats: streaks, word counts, yearly graph | medium | low |
| F-5 | Time-based auto lock (lock after X minutes) | low | low |
| F-6 | Device-to-device sync without a cloud (Syncthing/WebDAV) | high | medium |
| F-7 | Beautiful PDF export with themes | medium | medium |
| F-8 | Quick-capture widget for Linux/Android | medium | high |
| F-9 | Focus mode (full screen, no chrome) | low | low |
| F-10 | Smart reminders based on the user's writing habits | medium | medium |

## 2. Observed tech debt

| # | Item | Note |
|---|---|---|
| T-0 | `objectbox 6.0.0-preview.6` is a preview release we now depend on | Revisit when 6.0.0 stable ships (D-009) |
| T-1 | ~981 Dart files without feature-based layering | Hard to discover things; a big refactor isn't wise right now |
| T-2 | Committed `*.g.dart` files | Model/codegen mismatch risk |
| T-3 | `bin/docs` points to a `docs/` folder that doesn't exist in this version | Dead reference |
| T-4 | Two separate Google Drive paths (standard + Linux) | Duplicate-bug risk |
| T-5 | `.github/workflows/ci.yml` comes from upstream, targets `develop`, and assumes an Android-era setup | Same as I-10 |

## 3. Open questions

1. Product name — `notely`, or keep StoryPad?
2. Keep the Pro/paywall or unlock everything? (On Linux IAP doesn't work at all, so a
   gate would be dead weight there.)
3. 20 languages, or just fa/en?
4. Should we add an `upstream` remote for future updates?
5. Even though Android is parked — do we ever go back? If yes, we keep Android-only code
   compiling; if no, we could simplify a lot.
