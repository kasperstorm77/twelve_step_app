# 4th Step Inventory — area rules

AA 4th-step moral inventory: `InventoryEntry` records (4 categories ×
5 fields) tagged with reusable "I Am" identity definitions. The
original app, so it owns the lowest type IDs. See
[architecture.md §1.1](../../docs/architecture.md).

## Frozen
- **Type IDs:** `InventoryEntry`=0, `IAmDefinition`=1,
  `InventoryCategory`=14. Boxes: `entries`, `i_am_definitions`.
- **`InventoryEntry` `HiveField` indices:** 0 resentment, 1 reason,
  2 affect, 3 part, 4 defect, 5 `_iAmId` (deprecated — kept for
  migration, never remove), 6 category, 7 `iAmIds`, 8 `_id`, 9 order.
- **JSON keys:** `entries`, `iAmDefinitions`; compact-view flag rides
  in `appSettings.fourthStepCompactViewEnabled`.

## Rules
- **Dual I-Am export.** `toJson` always emits both the first `iAmId`
  (legacy single) and the full `iAmIds` list. `fromJson` must keep
  reading entries that have only `iAmId`. Filter out the literal string
  `'null'` everywhere.
- **`category` serializes as the enum `.name`** (`resentment` / `fear`
  / `harms` / `sexualHarms`), not the index; missing/null → `resentment`.
- **Order is higher = newer.** `reorderEntries` rebuilds every `order`;
  `InventoryService.migrateOrderValues()` runs at startup and after
  every restore — keep both calls.
- **Restore imports `iAmDefinitions` before `entries`** (entries
  reference them) — enforced in `BackupRestoreService`, don't reorder.
- **Can't delete an I Am that's in use** (usage scan over
  `effectiveIAmIds`). Keep the guard.
- **Default seed** `'Sober member of AA'` is added only when the box is
  empty and **without** triggering a Drive upload.
- **CSV export** uses `;` separators + a UTF-8 BOM; multiple I Am names
  are comma-joined in one cell. Don't switch to commas.

The text filter matches the first field only, at ≥2 chars; category
chips and compact expand/collapse are in-memory (not persisted) — only
the compact ON/OFF toggle persists.
</content>
