# Gratitude — area rules

A daily gratitude journal: each `GratitudeEntry` has two fields,
`gratitudeTowards` and `gratefulFor`. See
[architecture.md §1.5](../../docs/architecture.md).

## Frozen
- **Type ID:** `GratitudeEntry`=7. Box: `gratitude_box`.
- **`HiveField` indices:** 0 date, 1 gratitudeTowards, 2 createdAt,
  3 gratefulFor (adapter writes 4 fields).
- **JSON key:** export writes `gratitude`; restore must keep accepting
  the legacy alias **`gratitudeEntries`** (read-only). `fromJson` keeps
  `gratefulFor` optional with `''` default.

## Rules
- **CRUD addresses entries by box list index** (`box.values.toList()
  .indexOf(entry)` → `putAt`/`deleteAt`/`add`). `GratitudeEntry` has no
  `==`/`hashCode`, so edit/delete must operate on the **instance pulled
  from the box** — `indexOf` on a freshly constructed entry returns −1.
- **Entries are editable/deletable only on their creation day**
  (`canEdit`/`canDelete` compare `date` to today). Keep the history tab's
  delete button hidden for past entries.
- Saving requires **both** fields non-empty after trim (even though the
  model allows `gratefulFor == ''`).
</content>
