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
  `vibrateEnabled`=8, `soundEnabled`=9, `soundId`=10 (the highest index).
  Never renumber; add new fields at index 11+.
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
- `flutter_ringtone_player` ships **android/ios only**, so on desktop the
  alarm falls through to a single `SystemSound.alert` (often silent on
  Linux) — see implementation_plan P2.4.
</content>
