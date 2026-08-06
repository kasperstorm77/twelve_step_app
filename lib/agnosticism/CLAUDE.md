# Agnosticism (Surrender & Correction) — area rules

`BarrierPowerPair` records (a Barrier + its corrective Power) shown on a
flippable "current paper" of up to 5 active pairs, with an archive. See
[architecture.md §1.6](../../docs/architecture.md).

## Frozen
- **Type ID:** `BarrierPowerPair`=8. Box: `agnosticism_pairs`, keyed by
  `pair.id`.
- **Do NOT reuse typeId 9** for anything here — it now belongs to
  `RitualItemType` (morning_ritual). The live type here is **8 only**.
- **JSON key:** export writes `agnosticism`; restore must keep accepting
  the legacy alias **`agnosticismPapers`** (read-only). `fromJson`
  tolerates missing `isArchived` (→ false), `position` (→ 0) and
  `connectedFear` (→ `''`); `archivedAt` is nullable.
- **`connectedFear` is HiveField 7**, stored as `String?` in
  `storedConnectedFear` and read through the non-null `connectedFear`
  getter. Keep the stored field nullable: records written before the
  field exist on real devices, and a non-nullable field makes the
  generated adapter throw on them — which the corruption fallback would
  turn into silent data loss.

## Rules
- **`maxActivePairs = 5`** is enforced across add **and import**: a
  foreign or hand-edited payload with more active pairs has the excess
  **archived, never dropped**, and active positions compacted to 0..n.
  Active
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

## Cross-app compatibility

Emotional Sobriety reads and writes the same three fields, so pairs travel
between the two apps through Drive and JSON backups. It always writes
`connectedFear`; this app writes it too and preserves an empty value on
records that predate the field. The form requires all three fields when a
pair is written or edited, so an imported pair without a fear gains one the
next time it is touched. Never drop an unknown or empty fear on import — that
is the other app's data.

Old `PaperStatus`/`AgnosticismPaper` data is intentionally not migrated;
a corrupt old box is wiped and recreated on open.
</content>
