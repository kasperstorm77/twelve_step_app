# Morning Ritual — area rules

A daily ritual runner: ordered `RitualItem` definitions (timer / prayer)
executed in the Today tab with countdown, wake-lock, and alarm; finished
days saved as `MorningRitualEntry`. See
[architecture.md §1.3](../../docs/architecture.md).

## Frozen
- **Type IDs:** `RitualItemType`=9, `RitualItem`=10,
  `RitualItemStatus`=11, `RitualItemRecord`=12, `MorningRitualEntry`=13.
  Boxes: `morning_ritual_items`, `morning_ritual_entries`.
- **Enum ordinal order:** timer=0/prayer=1; completed=0/skipped=1/missed=2.
  Append only.
- **`RitualItem` later fields are additive:** `lastModified`=7,
  `vibrateEnabled`=8, `soundEnabled`=9, `soundId`=10, and nullable
  `randomizerSourceId`=11. Never renumber; add new fields at index 12+.
- **`RitualItemRecord` portable snapshots are append-only:** nullable
  `selectedContentId`=5 and nullable `selectedContentText`=6. The two values
  must both be present or both be absent. Never renumber; add at index 7+.
- **JSON keys:** `morningRitualItems`, `morningRitualEntries` (no alias);
  auto-load window in `appSettings.morningRitualAutoLoadEnabled` /
  `morningRitualStartTime` / `morningRitualEndTime` (`HH:MM:SS`).

## Rules
- **The in-progress draft is device-local and NOT synced.** It lives in
  the `settings` box under `morning_ritual_progress`; only finished
  `MorningRitualEntry` records sync. `_resetRitual` must not clear the
  draft; only `_finishRitual` does. `loadProgress` discards a previous
  day's draft. [test/morning_ritual_progress_test.dart](../../test/morning_ritual_progress_test.dart)
  guards this — keep it green.
- **Auto-load fires at most once per calendar day** (`morning_ritual_last_forced_date`).
  Window is inclusive of start, exclusive of end. It runs in two places
  (main.dart after Drive sync, and `AppWidget` on resume) — keep both.
- **Early-completing a running timer records `skipped`**, not
  `completed`. Wake-lock is held **only** while a timer actively counts.
- **The timer-end alarm plays to its natural end** (`looping: false`) —
  never force-stop it after a fixed delay (that truncated the sound). It
  is silenced by `_stopAlarmSound()` when the user advances
  (complete/skip/previous/start over) or leaves the page (`dispose`).
- `soundId` is persisted/synced but `_playAlarm` currently ignores it
  (always system alarm) — see implementation_plan P2.1.
- **Randomized readings ("Just for Today").** A prayer may name a reading
  source in `randomizerSourceId`; options come from
  `assets/content/morning_randomizer_v1.json` (**data, not Dart literals**),
  whose ten option IDs and `en`/`da` text are generated from Emotional
  Sobriety's Workshop catalog and are a cross-app contract. Regenerate that
  file from theirs; never retype it. One option is drawn when the ritual
  starts, held in the draft under `randomizerSelections`, and snapshotted into
  the record. **Resume, previous and start over must not redraw** — only a
  *missing* draw is made. A source ID must be non-blank and `prayer`-only;
  changing such a definition to `timer` clears it. An unknown source ID is
  preserved and falls back to `prayerText`.
- **Two definition-set invariants the other app enforces on the whole file:**
  at most **one** `randomizerSourceId` item, and `sortOrder` unique and
  **contiguous from zero** across *all* definitions. A gap makes Emotional
  Sobriety refuse the entire backup, not just Morning. Delete compacts,
  reorder numbers inactive items after active ones, and
  `migrateSortOrders()` repairs on-disk sets at startup and after restore —
  keep all three.
- History re-resolves a known option ID into the current language and
  otherwise shows the stored snapshot. The snapshot wins: it is what the
  person actually read and may have come from the other app.
- `ritualItemsBox`/`entriesBox` resolve per call and are **not** cached in
  statics — a cached handle goes stale after main.dart's
  delete-and-recreate corruption recovery.

## Widget-testing these screens
A `testWidgets` body runs in a **fake-async zone**, and every step of the
runner writes to Hive. Those writes resolve on the real event loop, which the
fake zone never advances — so a plain `await tester.tap(...)` leaves a write in
flight forever and Hive's per-box lock then **deadlocks teardown** (the test
hangs rather than fails). Open boxes in `setUp`, and drive every interaction
and every seed write through `tester.runAsync`; see the `act` helper in
[morning_ritual_runner_test.dart](../../test/morning_ritual_runner_test.dart).
Danish also needs the `GlobalMaterialLocalizations` delegates or the framework
throws on an unsupported locale.
- `flutter_ringtone_player` ships **android/ios only**, so on desktop the
  alarm falls through to a single `SystemSound.alert` (often silent on
  Linux) — see implementation_plan P2.4.
</content>
