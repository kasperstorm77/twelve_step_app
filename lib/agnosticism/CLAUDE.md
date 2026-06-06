# Agnosticism (Surrender & Correction) — area rules

`BarrierPowerPair` records (a Barrier + its corrective Power) shown on a
flippable "current paper" of up to 5 active pairs, with an archive. See
[architecture.md §1.6](../../docs/architecture.md).

## Frozen
- **Type ID:** `BarrierPowerPair`=8. Box: `agnosticism_pairs`, keyed by
  `pair.id`.
- **Do NOT reuse typeId 9** for anything here — it now belongs to
  `RitualItemType` (morning_ritual). The live type here is **8 only**;
  the class header comment that mentions typeId 9 is stale (see
  implementation_plan P3.2).
- **JSON key:** export writes `agnosticism`; restore must keep accepting
  the legacy alias **`agnosticismPapers`** (read-only). `fromJson`
  tolerates missing `isArchived` (→ false) and `position` (→ 0);
  `archivedAt` is nullable.

## Rules
- **`maxActivePairs = 5`** is enforced across add and restore. Active
  pairs can only be **archived**, never directly deleted; `deletePair`
  permanently deletes only archived pairs; `restorePair` is blocked at
  the cap. Keep this lifecycle.
- Active pairs are ordered/compacted by `position` (0..n);
  archive/restore call `_reorderActivePairs`.
- The two tabs use gesture/controller navigation
  (`NeverScrollableScrollPhysics`, 40px swipe threshold) and a 3-D flip
  with scroll-offset carry and a `_forceShowBack` cross-tab handoff. If
  you edit `paper_tab` / `archive_tab`, manually run the flip plus the
  Archive→Paper(back) swipe before reporting done.

Old `PaperStatus`/`AgnosticismPaper` data is intentionally not migrated;
a corrupt old box is wiped and recreated on open.
</content>
