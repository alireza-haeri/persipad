# What to do next — an ordered plan

> Rewritten 2026-11-16 at the end of session 14. Supersedes the session-11 version (which
> still listed the Fedora APK loop as "unknown" — it has since been verified, and the
> font-picker and lightweight-scope questions are answered by `D-047`/`N-020`).
>
> **The ordering rule:** risk removed per hour of your time. Items that need *you* (a
> device, a keystore, a judgement call) are **👤**; items I can do alone are **🤖**.
> Nothing here is a wish-list — each item names the evidence that it is worth doing.

---

## 1. 👤 One emulator sign-in attempt — the only open question in the sync path

**What I need:** one line of result. On Fedora:

```bash
bin/build_apk --install --avd=storypad_dev        # no DNS flag needed since D-055
# then in the app: Settings → Backup → Google Drive → sign in
```

**Why it is still open:** sessions 12–14 fixed everything around that flow (offline
handling, account retention, the AVD's resolver), and the last one was *diagnosed* but never
*exercised*: no session has seen a successful sign-in on the emulator. Until one does, "sync
works on Android" is a claim about code, not a fact.

**If it works:** say so and I record it in `PROGRESS.md`; next item is 2.1.
**If it fails:** paste the message. The two known shapes are no DNS (`Failed host lookup`,
now automatic — see `ENVIRONMENT.md` §2.2c) and no OAuth client configured for the
`community` build (`bin/setup_sync`).

> Related fact worth knowing: the app uses the **desktop loopback** OAuth flow on both
> platforms (`D-047`), not `google_sign_in`. On the emulator that means Chrome opens inside
> the guest and the redirect comes back to `127.0.0.1:<port>` *inside* the guest. It is
> designed to work there; it has not been seen working there.

---

## 2. 👤 Decisions that are yours, not mine

### 2.1 Release-signed APK instead of a bigger trim

The 138 MB number that keeps looking alarming is a **debug** build. Cutting features to
shrink it would be destroying value to fix a measurement error (`ANALYSIS.md` §4). Four
repository secrets, ~10 minutes, and then `[release]` produces a signed APK that can also be
*measured*:

| Secret | What it is |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` of a keystore you create once |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

> ⚠️ Add them in *Settings → Secrets*. Do not paste them in chat; I never need to see them.

### 2.2 Ten minutes with a screen reader (T-15)

The calendar cell is labelled; the rest gets whatever Material infers. The cheapest useful
script: open the calendar → swipe a month → open a story → open search. Tell me what sounds
wrong and I fix exactly that.

### 2.3 What "search quality" should mean (T-11)

Today `contains` on an unindexed column, and it is linear. A prefix index, ObjectBox
full-text, or "do nothing but measure" are all defensible and carry different migration
costs. **My recommendation:** measure on a realistic database (a few thousand stories)
first — nobody knows whether this is a 20 ms or a 2-second problem, and the answer picks the
row.

### 2.4 A coverage threshold — or not (T-14)

It is 14.7% and that is a starting fact, not a verdict: much of `lib/` is UI, and the editor
package is measured separately. **My recommendation:** still no threshold; instead, when we
touch a risky file (backup merge, calendar conversion, search filter), its tests go in that
same commit.

---

## 3. 🤖 What I can do without you, in order

### 3.1 Close the rest of the backup-merge surface (T-10 remainder)

The merge decision is tested. **Not** tested: `BackupLatestCheckerService`'s "older app on
another device" detection and `BackupObject.fromContents`'s v2/v3/v4 branches. Same
technique as `D-042` (a seam + a table). This is the remaining "can silently lose notes"
code, so it is the highest-value thing I can do alone.

### 3.2 Make the formatting gate blocking (T-7) — carefully

The gate is advisory only because the sandbox cannot run `dart format`. One commit formats
exactly the known-unformatted files, a second flips `continue-on-error` off. Risk: a
formatter version difference touching more files than expected — so that first commit stays
alone and revertable.

### 3.3 The `.g.dart` freshness check (T-2)

Committed generated code can drift from its source. A CI job that runs `build_runner` and
fails if the tree changes would close it (~75 s), preferably only when a model or a
`@CopyWith` file changed — `bin/changed_tests` already knows how to detect that.

### 3.4 Delete upstream CI that targets nothing (T-5)

`.github/workflows/ci.yml` comes from upstream, targets `develop`, and assumes an
Android-era setup nobody runs. One line to delete; I have not done it because it is not mine
to delete without asking.

---

## 4. Explicitly **not** recommended right now

- **Trimming more features to shrink the APK** — see 2.1, the number is a build artifact.
- **A big refactor toward feature-based layering** (T-1) — ~1000 files, no user-visible
  gain, and every bug of the last three sessions would have been harder to find.
- **Disabling `allowRuntimeFetching` globally** — `D-043` explains why; needs an SDK to verify.
- **Adding `Semantics` broadly** — see 2.2; listening beats guessing.
- **Chasing the `ReminderNavigationService` failure** — real, but it belongs to
  `arena/e3e3866a-notely` (`b210885`), which is already merged and pruned; if it still
  fails, it fails on `main` too and becomes a fresh, reproducible bug rather than a branch
  difference.

---

## 5. Traps this project has already found, so nobody re-finds them

1. **`gh api .../actions/runs` is repo-wide, not branch-scoped.** Filter on `head_branch`.
2. **An empty commit triggers no workflow.** `[full]` on `--allow-empty` runs nothing.
3. **`bin/build_runner` used to die without the artwork submodule** (`D-054`) — that is a
   skip now, not a signal.
4. **A "sign-in failed" can be DNS** (`D-053`). Check `adb shell ping -c1 oauth2.googleapis.com`
   from the guest before touching OAuth config, and note that the resolver is only chosen at
   **boot** — an AVD that is already running keeps whatever it had (`D-055`).
