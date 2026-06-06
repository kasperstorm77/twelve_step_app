# CLAUDE.md Best Practices

A distilled, generic reference for writing `CLAUDE.md` files (and other
agent-instruction files in the same family — `AGENTS.md`, `.cursorrules`,
etc.) so the agent actually follows what's written.

**This file is a frozen reference.** It contains no project-specific
content and is not meant to be edited as the project evolves. Treat it
as a manual — read it, then write your `CLAUDE.md` accordingly.

Synthesised from the sources at the end of this document. Where a tip
is quoted directly, the source is named inline.

---

## 1. What `CLAUDE.md` actually is

`CLAUDE.md` is a **behavioural contract**, not documentation. It is
loaded as a user message at the start of every session — Claude reads
it and tries to follow it, but compliance is not enforced (Anthropic
docs). Two consequences:

- Vague instructions don't survive.
- Anything that **must** happen at a lifecycle event (pre-commit,
  post-edit, etc.) belongs in a **hook**, not in `CLAUDE.md`.

Test for every line: *if you removed this line, would the agent do
something wrong?* If the answer is no, delete it.

---

## 2. Size and scope

| Target | Source |
| --- | --- |
| **Hard ceiling: 200 lines** | Anthropic docs |
| **Ideal: 60–120 lines** | HumanLayer, Bijit Ghosh |
| **Project file owns 100–150 instruction slots** after the model's own ~50-slot system prompt |

Longer files consume more context and **reduce adherence** — this is
Anthropic's explicit phrasing, not a stylistic preference.

Counter-intuitive: structuring imports with `@path/to/file.md` does not
save context. Imported files are expanded at launch. The only real
levers for reducing always-loaded content are **deleting lines** and
**path-scoping rules**.

---

## 3. Sections that earn their keep

Cover only what makes the agent act differently. The most-cited
structure is **five sections**:

1. **Critical commands** — build, test, lint, run.
2. **Architecture map** — where things live and what belongs where.
3. **Hard contracts** — constraints that prevent specific past
   mistakes.
4. **Workflow preferences** — how the user wants the agent to operate.
5. **Out of scope** — files and areas the agent must not touch.

A complementary framing is **WHAT / WHY / HOW**:

- **WHAT**: stack, project structure, codebase map.
- **WHY**: project purpose and the role of each component.
- **HOW**: tools/commands needed to do meaningful work.

Pick one organising principle and stick to it. Don't have both.

---

## 4. Phrasing rules

### Imperative, never declarative

| ❌ Declarative | ✅ Imperative |
| --- | --- |
| "We generally try to avoid inline mocks." | "Never use inline mocks — use `src/test/factories/*` for all test data." |
| "Tests should pass before committing." | "Run `pnpm test` before marking a PR ready." |
| "Prefer composition over inheritance." | "Never extend base classes from external libraries." |

Declarative statements are interpretable. Commands are executable.

### Concrete, never abstract

| ❌ Abstract | ✅ Concrete |
| --- | --- |
| "Format code properly." | "Use 2-space indentation." |
| "Keep files organised." | "API handlers live in `src/api/handlers/`." |
| "Test your changes." | "Run `test` before committing." |

Anthropic's documented rule: instructions must be **concrete enough to
verify**.

### Testable, never aspirational

A rule that can't be checked by a reviewer or a tool is a rule the
agent can violate without consequence. Phrase rules so a reader can
say "yes, that happened" or "no, it didn't."

---

## 5. `IMPORTANT` / `YOU MUST` / `NEVER`

Reserve emphasis markers for the one or two rules that **cannot** be
violated. *If everything is IMPORTANT, nothing is*.

Good candidates: credentials handling, irreversible operations,
non-obvious safety invariants. Bad candidates: style, naming,
"please be careful" pleas.

---

## 6. Lead with priorities

Rules near the top of the file receive **more consistent attention**
than rules buried later. Put hard contracts first,
preferences last.

---

## 7. What to leave out

- **Code style / linting rules** — *never send an LLM to do a linter's
  job* (HumanLayer). Use the linter.
- **Comprehensive command catalogues** — only commands the agent
  actually needs every session.
- **Implementation instructions for specific features** — those belong
  in a skill or a slash command.
- **Formatting conventions** — automate them.
- **Personality / persona instructions** ("be a senior engineer",
  "think carefully") — generic puffery that costs context for no
  behaviour change.
- **Stale architecture descriptions** — out of date worse than absent.

---

## 8. The file hierarchy

`CLAUDE.md` files compose, in load order (Anthropic docs):

| Scope | Path | Purpose | Shared with |
| --- | --- | --- | --- |
| Managed policy | OS-specific (`/etc/claude-code/`, `/Library/...`) | Org-wide instructions, IT-managed | Whole org |
| User | `~/.claude/CLAUDE.md` | Personal preferences for all projects | Just you |
| Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Team-shared, source-controlled | The team |
| Local | `./CLAUDE.local.md` | Personal project notes, gitignored | Just you |
| Subdirectory | `./<subdir>/CLAUDE.md` | Loaded on demand when the agent reads files there | Per-subdir |

The closer-to-cwd file is read last, so it takes priority on
conflicts. Recommended budgets: **user ≤ 30 lines**, **project 80–120
lines**, **local sprint-specific**

---

## 9. Path-scoped rules (`.claude/rules/`)

For instructions that only apply to one area of the codebase, use
`.claude/rules/<topic>.md` with `paths:` frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
---
# API rules
- All endpoints must include input validation.
- Use the standard error response format.
```

The rule loads only when Claude reads a matching file, keeping the
always-loaded context small.

---

## 10. Alternatives to `CLAUDE.md`

Reach for these *first*, fall back to `CLAUDE.md` only if neither
fits:

| Need | Use |
| --- | --- |
| Run a check at a specific lifecycle event (pre-commit, post-edit) | **Hook** |
| Repeatable multi-step procedure invoked on demand | **Skill** |
| Reusable prompt the user types like `/foo` | **Slash command** |
| Tooling restriction or permission rule | **Settings** (`permissions.deny`, `sandbox`) |
| Path-specific style or layout rule | **`.claude/rules/<topic>.md` with `paths:` frontmatter** |

Settings rules are **enforced** by the client. `CLAUDE.md` is
*requested* of the model.

---

## 11. Maintenance discipline

**Add to `CLAUDE.md` when**:

- The agent made the same mistake twice.
- A reviewer caught something the agent should have known.
- You re-typed the same correction into chat two sessions in a row.
- A new teammate would need the same context to be productive.

**Remove from `CLAUDE.md` when**:

- The constraint no longer applies (code refactored, dep replaced).
- A test or linter has been added that enforces the same rule.
- The instruction has been re-expressed as a hook or skill.

---

## 12. Compression strategy (three passes)

1. **Ruthless deduplication.** Remove repeated constraints. Two rules
   that overlap by 50% are usually one rule misphrased.
2. **Prose → commands.** Replace descriptive paragraphs with bullet
   imperatives or executable syntax.
3. **Always-loaded vs on-demand.** Move folder-specific rules out to
   `.claude/rules/<topic>.md`. Move one-off procedures to skills.


---

## 13. Anti-patterns to avoid

- **Conflicting instructions across files.** Claude picks one
  arbitrarily (Anthropic).
- **Copy-pasted boilerplate.** If two repos share a `CLAUDE.md`
  verbatim, at least one of them is wrong.
- **Bloat from `/init` not being trimmed.** The autogenerated file
  is a starting point, not the deliverable.
- **Documentation creep.** `CLAUDE.md` is not a `README`. If the
  content is for humans, put it in `README` or `docs/`.
- **Soft instructions inside hard sections.** "Please consider..."
  next to "NEVER do X" undermines the hard rule.

---

## 14. Format conventions that travel well

- Markdown headers (`##`, `###`) — Claude scans structure the way
  readers do.
- Short bullet lists.
- Code spans for paths, commands, identifiers.
- Tables when contrasting options.
- HTML comments (`<!-- ... -->`) for maintainer notes — they're
  stripped before being injected into context, so they don't cost
  tokens.
