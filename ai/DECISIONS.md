# Decision log (ADR)

Every meaningful decision gets a numbered block. Superseded decisions are never
deleted — they are marked `superseded by D-0XX` so the reasoning trail survives.

Template:

```
## D-00X — Title (YYYY-MM-DD)
- Status: accepted / pending / rejected / superseded by D-00Y
- Context: why this decision was needed
- Decision: what exactly was chosen
- Consequences: what gets easier / harder
```

---

## D-001 — Base project is a fork of StoryPad v2.34.0 (2026-11-15)
- **Status:** accepted
- **Context:** You liked StoryPad and want to build on top of it.
- **Decision:** The whole of `theachoem/storypad` (commit `cffda48`, version
  `2.34.0+834`) was copied into `alireza-haeri/notely`. **The upstream git history
  was not imported** — only files — so our repo history stays clean.
  The upstream reference is recorded in `ai/` instead.
- **Consequences:** Pulling upstream updates isn't trivial (needs diffs). We can add
  an `upstream` remote later — see D-002.

## D-002 — Relationship with upstream (2026-11-15)
- **Status:** accepted (revisitable)
- **Context:** We may later want to cherry-pick new features from the original project.
- **Decision:** No `upstream` remote for now; we treat this as an **independent fork**
  so we can change things freely without merge anxiety. When we need it, a new
  decision adds the remote.
- **Consequences:** Our code can drift from upstream; future merges get harder.

## D-003 — Platform scope: Linux + Android (2026-11-15)
- **Status:** accepted
- **Context:** You said: "for now I'm focused on Linux and Android; macOS and Windows
  are not a concern."
- **Decision:** Android is first-class, Linux is second-class but supported.
  macOS / Windows / iOS / web are out of active scope; their code is left untouched.
- **Consequences:** Manual testing happens on Linux and Android. Shared changes must
  go through platform-aware paths (`Platform.is*`) so other platforms don't break.

## D-004 — The `ai/` folder is the single source of truth for docs (2026-11-15)
- **Status:** accepted
- **Context:** You asked that every note, rule, decision, goal and progress update be
  stored as markdown so we can review it later and know where we are.
- **Decision:** Structure `GOAL / RULES / DECISIONS / PROGRESS / ARCHITECTURE /
  ENVIRONMENT / BACKLOG / notes`. The upstream project docs (`README.md`,
  `CONTRIBUTING.md`) stay untouched; `ai/` is our added layer.
- **Consequences:** Every session starts by reading `ai/README.md`.

## D-005 — ~~Documentation language: Persian~~ (2026-11-15)
- **Status:** **superseded by D-006**
- **Context:** Initially chosen so you could read it quickly.
- **Decision (historical):** `ai/` docs in Persian, code identifiers in English.
- **Consequences:** Mixed-script docs are harder to grep/edit and add friction for
  tooling and for any future agent.

## D-006 — Documentation language: English (2026-11-15)
- **Status:** accepted — supersedes D-005
- **Context:** You said: "I think it'd be nicer if you write the ai folder files in
  English — it's both prettier and easier and more understandable for you."
- **Decision:** All files under `ai/` (and the root `AI.md`) are written in English.
  Persian is still fine in chat. Commits and code stay English (already the case).
- **Consequences:** Slightly harder for a Persian-only reader, but better for
  searching, diffing, and consistency with the codebase and upstream docs.
  All existing files were rewritten in the same session.
