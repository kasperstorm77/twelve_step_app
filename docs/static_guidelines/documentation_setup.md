# Documentation setup guidelines

Use this standard for the project architecture, data model, implementation
plan, UI design guide, history, README, and agent instructions.

## 1. Writing rules

1. **Assign one owner.** Place each fact in one canonical document. Link to the
   owner from every other document.
2. **State one rule at a time.** Use a short, self-contained sentence or bullet.
3. **Write affirmatively.** Start constraints with verbs such as `Use`, `Keep`,
   `Require`, `Preserve`, `Reject`, `Route`, or `Record`.
4. **Use present tense.** Describe current behavior as fact. Write plan work as
   imperative instructions. Place narrative tense in
   `historic_implementation.md`.
5. **Lead with authority.** Name the owner, input, output, state, or action at
   the start of a sentence.
6. **Make rules testable.** Include exact symbols, paths, values, states,
   boundaries, and verification commands.
7. **Prefer structured forms.** Use tables for mappings, numbered lists for
   ordered flows, bullets for independent rules, and diagrams for topology.
8. **Keep paragraphs small.** Give each paragraph one purpose. Convert dense
   clauses into parallel bullets.
9. **Use stable terms.** Match code names, UI labels, enum values, and file
   names exactly. Preserve source grammar inside exact literals.
10. **Keep current documents current.** Move rationale and completed work to
    history. Keep accepted future work in the implementation plan.
11. **Expose uncertainty.** Put an implementation gap in the plan with an
    acceptance test. Keep the current contract factual.
12. **Optimize retrieval.** Use descriptive sentence-case headings, stable
    section IDs, local links, and concise citation keys.

## 2. Canonical ownership

| Document | Owns | Required shape |
| --- | --- | --- |
| `CLAUDE.md` | Agent priorities, safety rules, commands, document map | Short imperative quick reference |
| `AGENTS.md` | Cross-agent entry point | Link to `CLAUDE.md` |
| `architecture.md` | Current behavior, component boundaries, pipeline, engineering rules | Purpose, rules, topology, ordered pipeline, boundaries, operations, verification |
| `data_model.md` | Persisted and runtime shapes, identity, state, artifacts, ownership | Principles, layouts, schemas, transitions, transactions, normalization |
| `ui_design_guide.md` | Visible layout, interactions, action meaning, feedback, accessibility | Screen order, control tables, state rules, verification register |
| `implementation_plan.md` | Accepted future work in priority order | Outcome, driver, work rules, acceptance, validation, document impact |
| `historic_implementation.md` | Completed work and decision rationale | Dated phases with outcomes, reasons, tradeoffs, and verification |
| `README.md` | User setup and operation | Prerequisites, installation, daily use, remote setup, troubleshooting |

`docs/static_guidelines/` contains reusable writing standards. Canonical project
facts live in the documents listed in the table.

## 3. Update loop

Apply this loop to every documentation change:

1. Identify the canonical owner.
2. Read the implementation and every affected canonical section.
3. Update the owner with present-tense, affirmative, rule-based wording.
4. Replace repeated detail in companion documents with a direct link.
5. Put accepted work in `implementation_plan.md`.
6. Move completed plan content and decision rationale to
   `historic_implementation.md`.
7. Update `CLAUDE.md` when an agent rule, boundary, command, or document map
   changes.
8. Verify headings, links, anchors, exact literals, and Markdown formatting.
9. Review every current-document sentence for current tense, affirmative
   construction, one owner, and one purpose.

## 4. Source practices

This standard incorporates these current technical-writing practices:

- [GitHub: write short, self-contained AI instructions](https://docs.github.com/en/copilot/concepts/prompting/response-customization#writing-effective-custom-instructions)
- [Google: use present tense for system behavior](https://developers.google.com/style/tense)
- [Google: use descriptive, hierarchical, sentence-case headings](https://developers.google.com/style/headings)
- [Microsoft: lead with intent and make content concise and scannable](https://learn.microsoft.com/en-us/contribute/content/style-quick-start)
- [Diátaxis: structure reference material like the system](https://diataxis.fr/reference/)
