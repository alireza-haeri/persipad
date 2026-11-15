# `ai/notes/` — raw notes

- [`user-instructions.md`](user-instructions.md) — dated log of what you asked for, by session.

## Why a separate folder?

We keep three distinct layers, and they must not blur:

| Layer | What | Where |
|---|---|---|
| **Your words** (raw, uninterpreted) | "I want this / I don't want that" | this folder |
| **Rule / decision** (conclusion) | "So from now on we work like this" | `../RULES.md`, `../DECISIONS.md` |
| **Status** (execution) | "done / remaining" | `../PROGRESS.md`, `../BACKLOG.md` |

If a topic grows large (e.g. a full design discussion for one feature), it gets its
own file here — `notes/<topic>.md` — instead of bloating `user-instructions.md`.
