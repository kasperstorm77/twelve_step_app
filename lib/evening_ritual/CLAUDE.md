# Evening Ritual — area rules

Nightly 10th-step inventory: `ReflectionEntry` records of a fixed
`ReflectionType`, plus one per-day "thinking focus" slider. See
[architecture.md §1.4](../../docs/architecture.md).

## Frozen
- **Type IDs:** `ReflectionEntry`=5, `ReflectionType`=6. Box:
  `reflections_box`, keyed by `internalId`.
- **`ReflectionType` is serialized by ordinal index in BOTH Hive and
  JSON** — append new values only; reordering corrupts history. Adapter
  defaults unknown bytes to `resentful`.
- **JSON key:** `reflections` — **no legacy alias**. `date` serializes
  as a 10-char `YYYY-MM-DD` string.

## Rules
- **The "thinking focus" slider is not its own model.** It's a
  `ReflectionEntry` with `thinkingFocus != null` (placeholder type
  `godsForgiveness`). Assume **one per day**. Code everywhere
  distinguishes regular entries (`thinkingFocus == null`) from it;
  counts/badges exclude it. Slider UI is 0.0–1.0; storage is int 0–10
  (`(value*10).round()`).
- **Editing/deleting is gated to today** in the form tab (past days are
  read-only). The list tab's delete-day action can clear any date.
- Opening the form tab **for today** auto-creates a default thinking-focus
  entry (5) if none exists — so a today entry can appear just from
  viewing.
</content>
