# What to do next — an ordered plan

> Rewritten 2026-11-16 at the end of session 14. Supersedes the session-11 version (which
> still listed the Fedora APK loop as "unknown" — it has since been verified, and the
> font-picker and lightweight-scope questions are answered by `D-047`/`N-020`).
>
> **The ordering rule:** risk removed per hour of your time. Items that need *you* (a
> device, a keystore, a judgement call) are **👤**; items I can do alone are **🤖**.
> Nothing here is a wish-list — each item names the evidence that it is worth doing.

---

## 0. 👤 Verify the completed reminders feature (session 22, 2026-11-20)

`REMINDER_IMPLEMENTATION_PLAN.md` is implemented (`D-068`): the editor, persistence,
calendar-aware calculation and the OS scheduling path all exist, and the pure logic is
tested in CI. What is left is exactly what no sandbox can prove — that Android delivers the
alarm with the app closed, after a reboot, and after a time-zone change. The eight concrete
steps are in `PROGRESS.md` §Session 22 → "What only you can check".

**Why this is first:** the feature's whole value is "the notification arrives". Everything
below is older and less visible than a reminder that quietly does not fire.

---

## 0.1 👤 Send one Google sign-in capture (session 23, 2026-11-20)

The app now says *where* a Google request dies and `bin/oauth_debug` captures it (device
facts, the guest's own `ping` of the three Google names, a 120 s `adb logcat`, then the
diagnosis). The cause is not claimed until that log exists — the same symptom was already
once diagnosed as plain DNS (`D-053`) and came back, so guessing again would waste the round.

```bash
bin/build_apk --install --launch          # app-side logging: needs a rebuilt APK
bin/oauth_debug                           # Settings → Data backup → Google Drive → Sign in
```

**Then:** read `build/oauth_debug_*.log` (or `bin/oauth_debug --analyze <file>`). The verdict
line decides the fix — `fakeDns` (proxy fake-IP DNS, the "browser works, app doesn't" case),
`dnsFailure` (`--dns-server=8.8.8.8`), `tcpBlocked`/`tlsBlocked` (VPN routing/interception),
or `ok` (not the network: look at `exchange: HTTP <status>`). Details: `ENVIRONMENT.md` §2.2d.

**Why it is above the reminders list:** a sign-in that always fails blocks the entire Drive
feature, and one paste of a log settles it.

---

## 1. Do these first — they are blocked only on information you have
## 1. 👤 One DNS setting, then the sign-in attempt again

**Where it stands (session 15).** The old `Failed host lookup` is gone, the browser opened,
the Google account was accepted — and then the app said "No internet connection!". That
message is truthful: `adb shell ping -c1 oauth2.googleapis.com` from the guest returned
**198.18.0.60 (ttl 255, 1 ms)**, a fake address from the `198.18.0.0/15` pool that
Clash/mihomo-style proxies use for fake-IP DNS. The app's token exchange goes to that
address and dies; Chrome still logged in because it resolves through its own secure DNS.

So nothing in the Dart code is implicated: **the guest must resolve Google to a real
address.** Chrome reaching Google from inside the same AVD also proves the emulator's
TCP path is fine — only the name resolution is being hijacked.

**Three fixes, cheapest first:**

| # | Fix | Command / change | Cost |
|---|---|---|---|
| 1 | Let those names resolve for real in the proxy (best) | add to the proxy's config: `dns.fake-ip-filter: ["+.googleapis.com", "+.google.com", "accounts.google.com"]`, or switch `dns.enhanced-mode` to `redir-host`; restart the proxy | one config edit, fixes every app in the guest |
| 2 | Encrypted resolver inside the guest, even while it keeps running | `adb shell settings put global private_dns_mode hostname` then `adb shell settings put global private_dns_specifier dns.google` | two commands, no reboot |
|   | ...and to undo it | `adb shell settings put global private_dns_mode off` | |
| 3 | A resolver the fake-IP layer does not answer for | reboot the AVD with `bin/build_apk --install --avd=storypad_dev --dns-server=8.8.8.8` | a reboot; works only if that resolver is reachable from here |

**The check that says you are done** — the address must change from `198.18.*` to something
like `142.250.*`, `172.217.*`, `216.58.*` or `74.125.*`:

```bash
adb shell ping -c1 oauth2.googleapis.com
```

Then in the app: `Settings → Backup → Google Drive → sign in`. `bin/build_apk` now prints
exactly this diagnosis itself (`D-056`), so it can tell you which of the three cases you are
in before you open the app.

**Why this is still 👤:** it is one setting on your proxy or your AVD. If you prefer, tell me
which proxy you run and I will write the exact config block for it.

---

## 1b. ✅ "Make the final app lighter" — measured, not guessed

`D-057` answers it: 238 MB is a **debug, four-ABI** artifact (`bin/apk_report` shows it), and
the ladder is debug×4 ABIs → debug×1 ABI (~120 MB) → release×1 ABI (~30–45 MB expected, R8 +
no Dart symbols). `bin/build_apk --release --sign-debug --abi arm64` produces the last one
today, with no keystore. What is left is one measurement on your machine:

```bash
bin/build_apk --release --sign-debug --abi arm64 && bin/apk_report
```

Where the 237 MB actually is (measured, `bin/apk_report`): **142.2 MB `kernel_blob.bin`** +
11.1 MB `isolate_snapshot_data` (the Dart VM snapshot, debug-only), **3 engines** for 3 ABIs
(one of them carrying a 15 MB Vulkan validation layer), **37.2 MB of unminified dex**, and
**~2 MB of the app's own pictures and fonts** (0.2%). So the release build should land around
**25–40 MB**, and nothing user-visible has to be removed to get there.

**Measured:** 40.5 MB (`--release --sign-debug --abi arm64`) against 237.3 MB debug — R8
needed no keep rule. `D-059` now also filters Gradle's `abiFilters` to the chosen ABI, which
removes the last 4.3 MB of ObjectBox JNI libraries for ABIs the phone cannot load (**~36 MB
expected on the next build**).

---

## 1c. 📱 Phone sign-in — retest on a build that is actually installed (`D-058` + `D-060`)

The first phone attempt stopped at `http://127.0.0.1:44399/?code=…` (a spinner). Two things are
now in the app, and both matter:

- **`D-058`** attaches the loopback listener *before* the browser opens. Right, tested, but the
  round that "retested" it never installed anything: `bin/build_apk --install` printed
  `nothing attached`, because the phone was not visible to `adb`. So the phone still ran the old
  APK. **Check `adb devices` shows `device` (not `unauthorized`) before trusting a retest.**
- **`D-060`** makes the stuck page survivable: after 12 s without a redirect the app offers a
  dialog to paste the address from the browser. The loopback still wins whenever it arrives, so
  a working device never sees the dialog.

```bash
bin/build_apk --install --abi arm64 --launch        # the fix is in Dart, so the APK must be rebuilt
```

Then sign in on the phone. Three outcomes, and they are all informative:

| what you see | what it means |
| --- | --- |
| Sign-in completes by itself | the loopback works on this device; nothing else to do |
| A dialog asks for the address, and pasting it completes the sign-in | the browser could not reach the app (freezing or VPN); the fallback is doing its job |
| The dialog appears but pasting does not help | the *exchange* is failing, which is the DNS problem in §2.2d — not this flow |

If it still hangs with no dialog, the dialog itself did not get a chance to run, so send me **one**
line from:

```bash
adb logcat -d -s flutter | grep -i "Google sign-in"
```

- `waiting for the loopback redirect on 127.0.0.1:<port>` but **no** `loopback request` →
  the browser never reached the app (OEM process freezing, or a phone-side VPN blocking
  loopback). Next step is a paste-the-redirect-URL fallback, which I will write once that is
  confirmed.
- `loopback request (code: …)` → the app answered; the remaining failure is the token
  exchange, i.e. the same fake-IP DNS story as §1, now on the phone.

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
