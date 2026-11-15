# Your instructions

Everything you say is recorded here, raw and dated — even if it later becomes a rule
or a decision. Rule: **we never delete, we only tag with a status.**

Status labels: `📌 rule` · `✅ decision` · `💡 idea` · `⏳ pending` · `🗄 archived`

---

## Session 1 — 2026-11-15

### N-001 — Clone the project
> "First of all, my goal is that you fully clone this project:
> https://github.com/theachoem/storypad.git — I really, really like this project."

**Status:** ✅ done (commit `cffda48`, version `2.34.0+834`).
**Ref:** D-001

### N-002 — Collaborate on changes and new features
> "I want us to change it together. Add features to it. Some parts I'll change myself
> based on what I like. Agreed?"

**Status:** 📌 collaboration model accepted.
**Note:** Until you give me the list of parts you want to change yourself, I won't
touch them — I'll only help with guidance and review.

### N-003 — Platform scope
> "For now my focus is Linux and Android. macOS and Windows are not a concern."

**Status:** ✅ recorded as decision → D-003 (platform rule in `RULES.md` §3).

### N-004 — An `ai/` folder as project memory
> "Make an `ai` folder. Store every note I give you, our general rules and decisions as
> md files there so you can review it later and we know where we are: what rules to
> follow, what our goal is, and how far the work has gone / how much is left."

**Status:** ✅ done → D-004
**Coverage:** goal (GOAL) · rules (RULES) · decisions (DECISIONS) · progress (PROGRESS)
· remaining (PROGRESS + BACKLOG) · notes (this file).

### N-005 — Write the `ai/` docs in English
> "I think it'd be nicer if you write the ai folder files in English — it's both
> prettier and easier and more understandable for you."

**Status:** ✅ done → D-006 (supersedes D-005). All `ai/` files rewritten in English;
`RULES.md` §4 now mandates English for docs.

---

## Template for a new note

```md
### N-0XX — Short title (YYYY-MM-DD)
> Verbatim or faithful summary of what you said

**Status:** 📌/✅/💡/⏳/🗄
**Ref:** D-0XX or the relevant file
**Note:** where I guessed, or what is still ambiguous
```
