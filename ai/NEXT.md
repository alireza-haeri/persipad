# What to do next — an ordered plan

> Written 2026-11-16 at the end of Session 11. Supersedes the roadmap in
> `PROGRESS.md` §"Remaining" wherever the two disagree; that section keeps the older
> phase view for history.
>
> **The ordering rule:** risk removed per hour of your time. Items that need *you*
> (a device, a keystore, a decision) are marked **👤**; items I can do alone are **🤖**.
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

## 1. Do these first — they are blocked only on information you have

### 1.1 👤 The Fedora APK verdict (blocks everything about Android)

**What I need:** one line — did `bin/build_apk --install --avd=storypad_dev -v` ever
finish? Success, or the last log?

**Why it blocks:** `PROGRESS.md` has carried it as "unknown" since Session 10. Three
separate plans (A-3 lightweight build, release signing, the whole "is the phone app
real?" question) all sit behind it. Until it is answered, Android work is guesswork.

**If it succeeded:** say so and I will record it; the next Android item is 1.2.
**If it failed:** paste the log tail — the two known failure modes (NDK
`forceNdkDownload` hang, `dl.google.com`) already have fixes (D-040).

---

### 1.2 👤 Release-signed APK instead of trimming features

**Why before A-3:** the 138 MB number everyone reacts to is a **debug build**. It has
nothing to do with how much code we ship. Cutting features to shrink a number that is
an artifact of the build type would be destroying value to fix a measurement error
(`ANALYSIS.md` §4).

**What it needs from you** — four repository secrets, ~10 minutes:

| Secret | What it is |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` of a keystore you create once |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

**What I do after:** wire them into `android.yml`, produce a signed release APK on
`[release]`, and **measure it**. Only then does "is the APK too big?" become a question
with a number attached.

> ⚠️ Do not paste these in chat. Add them in the repository's *Settings → Secrets*.
> I never need to see them.

---

### 1.3 👤 Ten minutes on a screen reader (closes T-15 properly)

The calendar cell is now labelled; everything else gets whatever Material infers. The
honest way to find the real gaps is **not** for me to add `Semantics` to files nobody
has listened to — it is for you to turn on VoiceOver/TalkBack and tell me where it
sounds wrong.

**Cheapest useful script:** open the calendar → swipe through one month → open a story
→ open search. Three places where I would expect problems: the score bar's slider
value, the month header's navigation arrows, and the story list rows' "x min read"
text. Tell me what is confusing and I will fix exactly that.

---

## 2. Then — decisions I should not make for you

### 2.1 🧠 What "search quality" should mean (T-11)

Today: `contains` on an unindexed `searchMetadata` column. It works, and it is linear.
Replacing it is a real design choice with different costs:

| Option | Cost | Gains | Risk |
|---|---|---|---|
| Prefix index | small; `@Index` on a new column + migration | `foo*` is fast; `*foo*` still scans | needs an ObjectBox schema migration (D-016 codegen) |
| ObjectBox full-text (`@HnswIndex`/FTS) | medium | real relevance ranking | preview-version dependency (T-0) on an already-preview ObjectBox |
| Do nothing, just measure | zero | honesty | none |

**My recommendation:** measure first on a realistic database (a few thousand stories)
and only then choose. Right now nobody knows whether this is a 20 ms problem or a
2-second problem — and the answer decides which row of that table is correct.

### 2.2 🧠 A coverage threshold — or not (T-14)

We now know it is **13.9%**. That number is the *start* of a conversation, not a
verdict: much of `lib/` is UI that pure-logic tests cannot reach, and the editor
package is measured separately (or not at all yet).

**My recommendation:** do not add a threshold. Instead, when we next touch a risky
file (backup merge, calendar conversion, search filter), require its tests *in that
commit*. That grows coverage where it matters instead of where it is easy.

### 2.3 🧠 Is the font picker worth keeping online? (D-043 remainder)

The default family is bundled and works offline. The **picker's ~1500 families** still
download on demand. Two defensible answers:

- **Keep it** — it is a catalogue; a user choosing "Playfair Display" expects to fetch it.
- **Make it offline-only** — bundle a curated 10–15 families and delete the rest of the
  picker. Smaller surface, fully offline, but a real feature reduction.

I did not choose, because it changes what the app *is*. If you pick the second, I will
need a list of families (or a curated default set — I would propose the 12 most common).

---

## 3. Items I can do alone, in order

These need nothing from you. Listed so you can say "do them" or reorder.

### 3.1 🤖 Close the rest of the backup-merge surface (T-10 remainder)

The merge decision is tested. **Not** tested: `BackupLatestCheckerService`'s "older
app on another device" detection and `BackupObject.fromContents`'s v2/v3/v4 branches.
Same technique as D-042 (a seam + a table). This is the remaining "can silently lose
notes" code, so it is the highest-value thing I can do without you.

### 3.2 🤖 Make the formatting gate blocking (T-7) — carefully

The gate is advisory because the sandbox cannot run `dart format`. But we now know
exactly **9 files** are unformatted, and 8 were unformatted at the base commit. The
plan: one commit that runs `bin/format` on exactly those 9, then flip
`continue-on-error` off. Risk: a formatter version difference could touch more files
than expected — so that commit stays alone and revertable.

### 3.3 🤖 The `.g.dart` freshness check (T-2)

Committed generated code can silently drift from its source. A CI job that runs
`build_runner` and fails if the tree changes would close it — but it costs ~75s per
run, which is why it is not already done. Better: run it only when a model or a
`@CopyWith` file changed (`bin/changed_tests` already knows how to detect that).

### 3.4 🤖 Delete upstream CI that targets nothing (T-5)

`.github/workflows/ci.yml` comes from upstream, targets `develop`, and assumes an
Android-era setup nobody runs. It is dead weight that makes the Actions tab confusing.
Deleting it is a one-line change — I have not done it because it is not mine to
delete without asking.

---

## 4. Explicitly **not** recommended right now

Repeating these because they keep looking attractive:

- **Trimming features to shrink the APK** — see 1.2. The number is a build artifact.
- **A big refactor toward feature-based layering** (T-1) — 1013 files, no user-visible
  gain, and every one of this session's bugs would have been *harder* to find in a
  moving tree.
- **Disabling `allowRuntimeFetching` globally** — D-043 explains why, and it needs an
  SDK to verify.
- **Adding `Semantics` broadly** — see 1.3. Listening beats guessing.
- **Chasing the `ReminderNavigationService` failure** — that is real, but it belongs to
  `arena/e3e3866a-notely` (commit `b210885`), the parallel session's branch. Fixing it
  here would be fixing someone else's tree.

---

## 5. Two traps this session found, so nobody re-finds them

1. **`gh api .../actions/runs` is repo-wide, not branch-scoped.** Filter on
   `head_branch` before reading an annotation. I spent a while chasing a failure from
   the other branch.
2. **An empty commit triggers no workflow.** `[full]` on `--allow-empty` runs nothing.
   If you want the marker to mean something, the commit must touch a file.
