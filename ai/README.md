# `ai/` — shared project memory

This folder is the brain of our collaboration. Every note you give me, every rule
we set, every decision we make, and the state of the work — done or pending — is
written here, so that a new session can read these files first and know exactly
where we stand.

> Golden rule: **if it is not written in `ai/`, it does not exist.**
> At the end of every task, this folder is updated first, code second.

---

## Files

| File | Purpose |
|---|---|
| [`GOAL.md`](GOAL.md) | Vision, scope, what we want and explicitly do **not** want |
| [`RULES.md`](RULES.md) | Working agreements: branches, commits, code style, quality checklist |
| [`DECISIONS.md`](DECISIONS.md) | Append-only decision log (ADR style, numbered, dated, with "why") |
| [`PROGRESS.md`](PROGRESS.md) | Live status: done / in progress / remaining + metrics |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Code map of StoryPad so we don't re-explore the repo every time |
| [`ENVIRONMENT.md`](ENVIRONMENT.md) | What the sandbox can and cannot do, plus local build/run commands |
| [`BACKLOG.md`](BACKLOG.md) | Candidate features and tech debt, with status labels |
| [`ANALYSIS.md`](ANALYSIS.md) | Measured findings: what could be better next, with evidence + a re-measure command (D-041) |
| [`CHANGES.md`](CHANGES.md) | One session's diff told as a story: what changed, why, and the run id that proves it |
| [`NEXT.md`](NEXT.md) | The ordered plan: what is blocked on you, what needs a decision, what I can do alone |
| [`MERGE_REVIEW.md`](MERGE_REVIEW.md) | Session 12 parallel-branch review (`c5` + `e3e`), findings, fixes, and `main` consolidation |
| [`REMINDER_IMPLEMENTATION_PLAN.md`](REMINDER_IMPLEMENTATION_PLAN.md) | The custom-reminder plan (from `arena/7ba21f51-notely`) and its session-22 implementation status |
| [`merge-history/`](merge-history/) | Exact historical `ai/` snapshots of `c5`, `e3e`, `f599`, and `codegen` before pruning |
| [`notes/`](notes/) | Raw, dated notes of what you asked for |

## Update ritual

At the end of every task:

1. `PROGRESS.md` — tick what is finished, refresh metrics and "last updated".
2. New decision taken → add a numbered entry to `DECISIONS.md`.
3. New instruction/rule from you → record it in `notes/user-instructions.md`, then
   reflect it in `RULES.md` or `GOAL.md` if it is a general rule.
4. A task with more than a handful of commits → a `CHANGES.md` section, because a
   diff of that size is not readable from `git log`.
5. `NEXT.md` — re-order it. An out-of-date plan is worse than none: it makes the next
   session repeat finished work.

## Which file answers which question

| You are asking… | Read |
|---|---|
| "What are we building and for whom?" | `GOAL.md` |
| "What did the last session actually change?" | `CHANGES.md` |
| "What should happen next?" | `NEXT.md` |
| "Why is it built this way?" | `DECISIONS.md` (search for `D-0xx`) |
| "Where does X live in the code?" | `ARCHITECTURE.md` |
| "What is still broken / missing?" | `BACKLOG.md` |
| "Is it working right now?" | `PROGRESS.md` §Handoff Snapshot |
| "What can this sandbox do?" | `ENVIRONMENT.md` |
| "What rules did I set?" | `RULES.md` + `notes/user-instructions.md` |

## Changelog of this folder

| Date | Change |
|---|---|
| 2026-11-15 | Created `ai/` alongside importing the StoryPad codebase |
| 2026-11-15 | Rewritten in English (see D-006) |
| 2026-11-15 | Linux-only dev scope, toolchain baseline, one-command dev loop (D-007 … D-010) |
| 2026-11-16 | Refreshed docs through Session 10 (Shamsi/RTL, Daily Score, CI/local Android APK, agent handoff) |
| 2026-11-16 | Session 11: branch/tip, translation key count (626) and JDK facts corrected; `ANALYSIS.md` added (D-041) |
| 2026-11-16 | Session 11 round two: T-9…T-15 implemented; `CHANGES.md` and `NEXT.md` added, `RULES.md` §3b rewritten to match the new CI (D-042…D-046) |
| 2026-11-16 | Session 12: Parallel branches (`c5`, `e3e`, `f599`, `ci/codegen`) reviewed, merged, verified on Fedora + CI, and consolidated onto `main` (`MERGE_REVIEW.md`, `D-047`…`D-049`) |
| 2026-11-16 | Sessions 12–14: real Fedora/Android logs fixed (voice playback, no-op sync reloads, filter notifier), then the emulator "sign-in failed" traced to DNS (`D-053`), codegen-without-submodule made a skip (`D-054`), and the AVD resolver automated (`D-055`); `CHANGES.md` §8, `NEXT.md` rewritten |
| 2026-11-20 | Session 22: custom calendar reminders completed from the plan (`D-068`, `CHANGES.md`, `PROGRESS.md`) |
