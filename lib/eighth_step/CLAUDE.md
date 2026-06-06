# 8th Step Amends — area rules

Step 8: `Person` records in three willingness columns (Yes / No /
Maybe) on a drag-and-drop board. See
[architecture.md §1.2](../../docs/architecture.md).

## Frozen
- **Type IDs:** `Person`=3 (it was moved 1→3 to avoid an
  `IAmDefinition` clash — never revert), `ColumnType`=4. Box:
  `people_box`, keyed by `internalId` (UUID).
- **`Person` `HiveField` indices:** 0 internalId, 1 name, 2 amends,
  3 column, 4 amendsDone, 5 lastModified, 6 sortOrder (adapter writes
  7 fields). `ColumnType` ordinal order yes=0/no=1/maybe=2 is frozen.
- **JSON key:** `people` — **no legacy alias**. Per-person fields:
  internalId, name, amends, column (string), amendsDone, lastModified
  (ISO8601), sortOrder.

## Rules
- **Serialization is NOT in `all_apps_drive_service_impl.dart`.** Export
  lives in `SyncPayloadBuilder._exportPeople`; import in
  `BackupRestoreService` (clears `people_box`, full replace by
  `internalId`). Don't add a second path.
- **`sortOrder` uses a 1000-gap scheme**; `_handleDrop` rebalances the
  whole column to `(i+1)*1000` when neighbours collapse. Same-column
  downward drags adjust the target index by −1.
- Bump `lastModified` on every update/toggle (`PersonService` does this).

`EighthStepSettingsTab`'s list UI is legacy and **not routed** —
`EighthStepHome` imports it only to reuse `PersonEditDialog`. Don't wire
the list view back in without intent (see implementation_plan P3.1).
</content>
