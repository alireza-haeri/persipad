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
| [`notes/`](notes/) | Raw, dated notes of what you asked for |

## Update ritual

At the end of every task:

1. `PROGRESS.md` — tick what is finished, refresh metrics and "last updated".
2. New decision taken → add a numbered entry to `DECISIONS.md`.
3. New instruction/rule from you → record it in `notes/user-instructions.md`, then
   reflect it in `RULES.md` or `GOAL.md` if it is a general rule.

## Changelog of this folder

| Date | Change |
|---|---|
| 2026-11-15 | Created `ai/` alongside importing the StoryPad codebase |
| 2026-11-15 | Rewritten in English (see D-006) |
