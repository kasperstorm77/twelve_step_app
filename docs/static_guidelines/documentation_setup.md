# Documentation setup guidelines

Set up the project's agent docs from the codebase and whatever already exists in the `docs/` folder. Two deliverables:

## 1. Write the CLAUDE.md files

Following [claude_md_best_practices.md](./claude_md_best_practices.md) throughout, create a top-level `CLAUDE.md` plus one `CLAUDE.md` per logical area of the app. Base their content on the codebase and the existing `docs/` documents.

## 2. Consolidate the docs

Merge every `docs/*.md` file into exactly the three documents below. Exclude only sub-folders and `docs/LOCAL_SETUP.md`, if either is present. When done, these three (plus the excluded items) are the only docs remaining. No documented functionality may be lost — relocate it, don't drop it.

Build each from the codebase and existing docs. Keep their jobs separate; no overlap.

- **architecture.md** — what the system does and how it must behave *now*. Functional features + the non-functional invariants every change must preserve. Current state only; no history, no future work.
- **historic_implementation.md** — what's been built, phase by phase, and why each pivot happened. Orientation, not an index: note that file/line citations rot. Append as work lands. Look at earlier git commits for information also.
- **implementation_plan.md** — what's next, in priority order. PR-sized items with the *why*, including deliberate "not yet" decisions. New work is added here first.

**Relationship to CLAUDE.md:** CLAUDE.md holds the hard rules; these docs hold the detail behind them — invariant → architecture.md, rationale → historic_implementation.md, pending work → implementation_plan.md. CLAUDE.md links to them instead of duplicating. When a rule's invariant, rationale, or roadmap changes, update the matching doc in the same pass.
