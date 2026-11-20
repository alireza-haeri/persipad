# Session 11 — every change, why it exists, and what proves it

> Written 2026-11-16 at the end of Session 11. Scope: the whole diff from `a238698`
> (Session-10 handoff) to `e2498c5` — **27 commits, 24 files, +1623 / −84**.
>
> This file is the narrative version. The formal records are spread over
> `DECISIONS.md` (D-041…D-046), `BACKLOG.md` (T-9…T-15), `ANALYSIS.md` (the findings)
> and `PROGRESS.md` (the log). Read this first if you want the story in one place;
> read those if you need the reasoning or the re-measure commands.
>
> **Golden rule for this file:** every claim below names the run or the command that
> proves it. Where nothing proves it, it says so.

---

## 0. How to read the evidence

There is **no Flutter/Dart SDK in the sandbox** (`ENVIRONMENT.md`). Nothing in this
session was ever executed locally. Every "it works" below is either:

- a **CI run id** — the only compiler we have, or
- a **command the reader can re-run** to check the claim themselves.

Two runs carry the weight. Everything else was superseded by a later push
(`cancel-in-progress`) or belongs to a different branch:

| Run | Commit | Result |
|---|---|---|
| `43837873918` | `13e656b` | **7/7 green**: Analyze, Scope, Test (1), Test (2), Build Linux desktop, **Editor package tests**, **Coverage** |
| `43841692813` | `7fe4c7a` | **green** — the final code state (Analyze, Scope, Test (1) scoped to `backup_repository_test.dart`) |

Re-check any of them with:

```bash
bin/ci                 # this branch's latest runs, returns in ~1s
bin/ci --all           # the last 5
gh run view <id>       # detail for one
```

---

## 1. The CI container (`.github/workflows/linux.yml`, `bin/changed_tests`)

This is where most of the risk lived, and almost none of it was visible from the app.

### 1.1 The editor package's 390 tests were never run — **fixed**

`packages/storypad_editor/` is a separate package with its own `pubspec.yaml` and
**57 test files / ~390 cases**. The root `flutter test` cannot see it, and
`bin/changed_tests` had no `packages/**` mapping, so a change there fell through to
"unmapped ⇒ run the whole app suite" — the slowest possible response to the code
that owns the persisted content format.

**What changed**

- `linux.yml` gained a job `Editor package tests`, gated on the scoper's new
  `packages` output, running `flutter test` inside the package directory.
- `bin/changed_tests` gained `PACKAGE_PREFIXES`, `touches_packages()`, and a fourth
  output key `packages`. A `packages/**`-only change now resolves to
  `mode=none, packages=true`.

**Proof** — run `43835490383` is the end-to-end demonstration: a real `.dart` change
under `packages/` produced exactly the intended graph —

```
Scope                 success
Analyze               success
Editor package tests  success   <-- ran
Build Linux desktop   skipped
Test                  skipped
Coverage              skipped
```

and the editor suite has since run alongside the app shards in `43837873918`.

### 1.2 `[full]` silently skipped the packages — **fixed** (D-045)

The marker that exists to prove "the whole tree is green" overrode the *test mode* but
not the new `packages` flag. So the strongest verification a person could ask for ran
both app shards and skipped the editor suite — weaker than changing a single file
under `packages/`.

`touches_packages(paths, message)` now returns `true` for a `[full]` subject.

### 1.3 A workflow file counted as "cannot affect behaviour" — **fixed** (D-045)

`.github/**` sat inside the blanket ignore list, so editing the gate did not run the
gate. `CI_DEFINITION_PREFIXES = (".github/workflows/",)` now exempts workflow files;
everything else under `.github/`, plus `bin/` and `docs/`, stays ignored.

**Proof** — `bin/changed_tests` was exercised directly:

```bash
python3 -c "import importlib.util as u; s=u.spec_from_file_location('ct','bin/changed_tests'); ..."
# workflow edit                 -> ('full', [])
# [full] with no files          -> ('full', []) + packages=True
# ai/PROGRESS.md only           -> ('none', [])
# .github/ISSUE_TEMPLATE/*.md   -> ignored
# bin/changed_tests             -> ignored
```

### 1.4 Every *successful* test job printed a failure annotation — **fixed** (D-046)

The test step re-emits failures as annotations (the raw log goes to blob storage we
cannot read — D-013). It never received `flutter test`'s exit status, so `if not
failed:` fired on every **green** run and printed:

```
::error::flutter test failed but the JSON reporter reported no failing test
```

Both shards of `43834022225` carried this. It is not cosmetic: an annotation channel
that cries wolf on every success is one people learn to skim — and during this session
it nearly hid a real failure.

**What changed** — the status is passed in:

| Situation | Annotation |
|---|---|
| exit 0 | **none at all** |
| a reported failing test | its name + first error line (as before) |
| non-zero, no reported test (compile error, timeout) | one note saying the log is where to look |

**Proof** — the extracted Python block was run against three fixtures before
committing (green ⇒ empty output; failing test ⇒ names it; empty+non-zero ⇒ the
fallback message), then confirmed in `43837873918`, whose Test jobs carry only
`shard N/2: 56 files` and no error annotations.

### 1.5 Advisory jobs added

- **`Coverage`** (T-14) — `--coverage`, lcov artifact, one percentage notice.
  **First measurement: 4 527 / 32 634 lines = 13.9%.** No threshold, on purpose:
  a gate picked before anyone looked at the shape of the gap is a number to game.
- `Build Linux desktop` and the editor job are unchanged in scope.

### 1.6 What this container still gets wrong

- An **empty commit starts no workflow at all**. `72eb3d2` (`… [full]`) is a valid
  empty commit and sits at the tip, yet GitHub reports **zero runs** for it. `[full]`
  needs a real file change to have any effect.
- The formatting gate is **still advisory** (T-7): 9 files are unformatted at the
  base commit and 9 are unformatted now. One of those nine was created by this
  session (`backup_repository.dart`) and was re-indented in `7fe4c7a`; the rest are
  pre-existing.

---

## 2. Backup merge — the code that can silently lose notes (`D-042`)

### 2.1 The problem

`RestoreBackupService.restoreOnlyNewData` decides which copy of a record survives a
sync. Pure logic over two `updatedAt` values — and **zero tests**. The reason was
structural: it walks `BackupRepository.databases`, a `static final` list whose
initializer reads eight `*.db` getters, each opening the real ObjectBox store. A unit
test could not import it without opening a database that does not exist.

### 2.2 The seam

- `BackupRepository.databases` is now a **getter** over a lazy `_databases`, so the
  initializer runs on first *read* — exactly as before for the app, never for a test
  that overrides it.
- `BackupRepository.overrideDatabases()` (`@visibleForTesting`) installs fakes for the
  duration of a test; an empty list restores the real tables.
- `JsonTablesToModelService.decode` takes an optional `databases` parameter.

No behaviour change at runtime: the same initializer runs on the same first read.

### 2.3 The tests — `test/core/services/backup_sync_steps/restore_backup_service_test.dart`

Nine cases, one per reachable state of the decision table:

| Case | Expected |
|---|---|
| device newer than backup | touch, never overwrite |
| backup newer | import + count |
| equal timestamps | no-op |
| missing locally | insert |
| local without `updatedAt` | handled both ways |
| backup without `updatedAt` | handled both ways |
| listener batching | `notifyCallbacks: false`, one `notify()` |
| `forceRestore` | always imports |

**Still open:** the latest-checker's "older app on another device" detection and
`BackupObject.fromContents`'s v2/v3/v4 branches.

---

## 3. Search (`D-044`, T-11)

### 3.1 Opening search waited on a backfill

`SearchViewModel` awaited `reindexSearchMetadata()` before its first `load()`, so the
screen showed nothing until a backfill that is a **no-op on a healthy database**
finished.

**Now:** `load()` runs first; the backfill runs concurrently and re-runs the search
**only** if a query or a tag was picked while it was in flight — the only two ways its
result can change.

### 3.2 The backfill itself did expensive work to learn there was nothing to do

It materialised every live tag into a map *before* discovering that no story needed
reindexing. Now a single `count()` answers "is there anything to do?" first.

**Honest correction, made during this session.** My first version of this, and the
first version of this document, called that an "indexed `count()`". It is not:
`searchMetadata` has **no `@Index`** in `entities.dart`. It is a column scan. What it
saves is the tag map and the per-story Markdown decode — real, but not what the word
"indexed" promises. The code comment, D-044 and `ANALYSIS.md` were corrected.

Also fixed while there: the probe and the fetch built the same three-part condition
twice. Drift between them is silent in the worst direction — a probe that stops
matching returns early and the backfill never runs again. They now share one.

### 3.3 The filter contract is now pinned — `test/core/objects/search_filter_object_test.dart`

Field→query-key mapping, query widening, the Shamsi display-year conversion,
`encode()`'s DateTime safety, and `DateRangeFilterObject` in **both** calendar modes.

**Still open:** the scan itself (`contains` on an unindexed column). That is a design
decision (prefix index? FTS?), not a drive-by fix.

---

## 4. Offline typography (`D-043`, T-12)

`AppTheme` builds its whole text theme with `GoogleFonts.getTextTheme()`, and
`kDefaultFontFamily` was `'Quicksand'` — a family **nothing bundled**. `google_fonts`
downloads a family it cannot find in the asset manifest, so on a fresh offline install
the app rendered with a platform fallback and swapped faces once the network answered.
For an offline-first, privacy-first app that is a contradiction.

**What changed** — `assets/fonts/Quicksand-Variable.ttf` (variable 300..700, **124 824
B**, TrueType magic `00 01 00 00`, `fvar` present) and `OFL-Quicksand.txt` (4 445 B),
declared in `pubspec.yaml`. Obtained from `google/fonts`' `ofl/quicksand` directory, so
OFL-1.1 with the licence file shipped next to it.

**What was deliberately *not* done** — `GoogleFonts.config.allowRuntimeFetching = false`.
I tried it, then reverted it. It is global, and `fonts_content.dart` calls
`GoogleFonts.getFont()` for every family in the picker (~1500). Without an SDK I cannot
confirm how 8.2.1 behaves for a family that is neither bundled nor fetchable — a
fallback face, or a throw inside a widget build. A global behavioural switch on
unverified semantics is a worse trade than the download it prevents. If offline-only is
ever wanted, the picker must be limited to bundled families **in the same change**.

**Verified:** the TTF's magic bytes and presence of `fvar` were checked with `od`/python
(the sandbox cannot render it); `flutter analyze` accepts the manifest.

---

## 5. Accessibility (`D-040` note, T-15)

The calendar cell is a `Stack` of a today-ring, a score tint, an emoji and a day badge.
A screen reader announced those as unrelated fragments — a bare number, an emoji,
sometimes a percentage — where a sighted user reads one date.

**What changed** — one `Semantics` node per cell: formatted date, then the day's
feeling(s), then its score (`15 Nov 2026 · 🥳 · 70%`), with `excludeSemantics: true`
so the badge and emoji are not read twice; `button` only when tappable; `selected`
mirrors selection. The label builds **no translated string** — `tr()` throws outside an
`EasyLocalization` scope and the existing tests pump the cell bare.

**Tests** — `group('semantics')`, 4 cases, asserting through the semantics *tree*
(`rootSemanticsNode`) rather than one node's identity, because `SpTapEffect`
contributes a `GestureDetector` node above ours.

**Two honest corrections:**

- The **score bar was already complete** — `slider: true` with
  `value`/`increasedValue`/`decreasedValue` and both actions. The original finding
  claimed otherwise; it was wrong.
- The **"story-list rail" does not exist.** It was a misreading of the timeline rail,
  which is decoration inside a row that is already labelled.

So T-15 is closed: one real gap fixed, one already fixed, one imaginary. The
remaining surface is real (2 `Semantics` sites for ~100 custom widgets) but the next
step is **listening to a real screen reader**, not sprinkling widgets across files
nobody has listened to.

---

## 6. Small corrections that were not features

- **`bin/changed_tests` keys changed.** The scoper now emits
  `mode|build|packages|shards|paths`. Anything reading the old key set must add
  `packages`.
- **An unused-import cleanup that broke the build, then was reverted.** I removed two
  imports from `stories_box.dart` as "unused"; `helpers/stories_box_transformer.dart`
  is `part of '../stories_box.dart';` and uses both. Analyze failed with two
  `Undefined class` errors; commit `28cc12b` was reverted in `e3cc2f0`.
  **Lesson, now recorded in `PROGRESS.md`:** 180 files in this repo are `part of`
  something, so grepping one file for a symbol is not enough. Check with
  `grep -rl "part of '.*<file>.dart'" lib/` before deleting an import.

---

## 7. Documentation work in this session

Beyond the code, `ai/` was corrected in three places and extended with the analysis.

| File | What changed | Why |
|---|---|---|
| `ANALYSIS.md` | **New** — 9 sections, every finding with evidence + a re-measure command | D-041: findings are re-measured, not remembered |
| `DECISIONS.md` | D-041…D-046 added | one entry per decision, with the alternative that was rejected |
| `BACKLOG.md` | T-9…T-15 added, then closed/adjusted as they landed | the analysis's findings became trackable items |
| `PROGRESS.md` | Session-11 log, metrics, test log, verification log, two incident notes | the handoff must be readable by a new session |
| `notes/user-instructions.md` | N-017 (this round's instruction and its honest gaps) | every instruction is recorded verbatim |
| `RULES.md` | branch/tip facts, `.github/workflows/**` no longer "ignorable" | it described a branch that no longer existed |
| `ARCHITECTURE.md` | 628 → 626 translation keys, plus how to re-count | the constant was wrong and would rot again |
| `ENVIRONMENT.md` | JDK block explains *requirement* (17+) vs *observed* (21 / 17) | it stated one version as if it were the contract |
| `README.md` | file table grew `ANALYSIS.md` | new file must be discoverable |
| **`CHANGES.md`** | **this file** | the diff in one narrative place, so nobody has to reconstruct it from 27 commits |

---

# Session 22 — custom calendar reminders, end to end (2026-11-20)

> Branch `arena/95cdc5fd-persipad`, from `main` at `a87f0147`. Scope: `REMINDER_IMPLEMENTATION_PLAN.md`
> (written on `arena/7ba21f51-notely`). The plan named its own starting point: "the calendar
> calculation and standalone schedule model exist, but monthly and yearly schedules are not
> yet connected to the editor, persistence or notification scheduling." That foundation was
> not on this branch, so it was ported first and completed here. Decision record: `D-068`.

## 1. The missing half was the whole feature

The tempting reading of the plan was "add two date formulas". The real gap was the path a
reminder travels:

```
editor → ReminderObject (JSON in SharedPreferences) → planner → OS alarms → tap → editor
```

Only the middle-left piece (a calculator) existed, and it was unreachable from the UI. So the
work is described in that order.

## 2. Model — old reminders must not move

`ReminderObject` gained four fields:

| Field | Why it exists |
|---|---|
| `recurrence` (`daily/weekly/monthly/yearly`, nullable) | the user's choice; `null` on every reminder stored before today |
| `intervalMonths` | 1–12 for "every N months"; 12 for yearly |
| `anchorDate` | the Gregorian date the user picked — it names the anchor month |
| `anchorDay` | the day **number** they meant in the calendar they were reading |

`effectiveRecurrence` infers daily/weekly from `weekdays` when `recurrence` is null, so a
legacy record keeps its exact schedule and there is no migration step that could half-run.
`anchorDay` is separate from `anchorDate.day` because Jalali 30 Esfand and Gregorian March 30
are different dates; keeping the number is what lets the series clamp one month and recover
the next.

## 3. Calculation — the displayed calendar, clamped per occurrence

`CalendarRecurrence.next` walks whole months from the anchor, computes the day (clamped to
the month length) and rebuilds a local `DateTime` from components. No `Duration(days:)` on a
local date (`D-049`). `CalendarReminderSchedule` binds that to a reminder and adds
`upcoming(count)` so the notifier can ask for a series instead of one date.

## 4. Delivery — a bounded window of real alarms, not a promise of infinity

A repeating OS rule cannot express "every 3 months, day 31, clamp in short months" in either
calendar. `ReminderSchedulePlanner` therefore expands monthly/yearly reminders into up to 24
concrete occurrences, and `LocalNotificationService` schedules each one as an inexact
`zonedSchedule` alarm:

- daily/weekly → unchanged repeating rules (they never expire),
- monthly/yearly → 24 alarms (≥ 2 years of monthly, ~24 years of yearly),
- renewed on app start, on resume and on every edit — the app does not have to run for the
  alarms to fire, only to renew the window.

Notification ids are now allocated per reschedule pass after `cancelAll()`. The old
`reminderId * 10 + slot` scheme could collide with a calendar reminder's slot ids; payloads
carry the reminder id, so ids only need to be unique within one pass.

`RescheduleQueue` (ported with its tests) serializes updates, drops superseded snapshots and —
unlike the previous inline queue — keeps working after a plugin or permission failure.

## 5. The parts that only exist because the OS is involved

| Concern | What was done | What proves it |
|---|---|---|
| Reboot | the plugin's `ScheduledNotificationBootReceiver` was already declared; nothing to add | device test |
| Time-zone change | Dart gets no broadcast → compare the device zone on resume and reschedule | device test |
| Notifications blocked | `notificationsBlocked()` + a banner on the reminders screen with the exact fix | device test |
| Calendar switch | `setCalendarSystem` reschedules; the anchor month is re-read in the new calendar | unit test (`planner`) + device test |
| Delete / disable / edit | every write goes through `_writeReminders` → `rescheduleAll` | unit tests + device test |

## 6. Editor

`Repeat` (with a bottom sheet), `Interval` (1–12), `Starting date` (the app's own calendar
dialog, so Shamsi is picked in Shamsi), a live summary, a clamping hint for monthly series and
"your next reminder will be on …". `build()` is pure, which is why the mapping is tested
without a widget.

## 7. What is *not* claimed

- Exact delivery: scheduling stays inexact on purpose (no `SCHEDULE_EXACT_ALARM`), so Doze can
  delay an alarm by minutes.
- Infinite renewal: an app that is never opened for years stops renewing its window.
- Android/OEM background killers are not defeated by any of this; the notification may never
  arrive if the OEM drops alarms, which is why the device test exists.

## 8. Verification

| What | Evidence |
|---|---|
| Analyzer + full suite + Linux build | Linux CI `44703732346` on `e9e519f`: Scope, Analyze, Test (1), Test (2), Build Linux desktop, Editor package tests, Coverage — **7/7 green** |
| Generated code + formatting | the `[codegen]` job (`44703366204`) published `ci/codegen`; the regenerated `reminder_object.g.dart` and the two formatting fixes were taken from it, and the final run above is green with no format annotation |
| Pure logic (recurrence, clamping, leap years, calendar switch, legacy records, editor mapping, queue) | new tests listed in `PROGRESS.md` §Session 22 |
| Delivery while closed / reboot / time zone / blocked notifications | **not verified** — device steps in `PROGRESS.md` |
