# Notifications (reminders) — area rules

Scheduled local reminders (`AppNotification`), daily or on chosen
weekdays, registered with the OS via `flutter_local_notifications`. See
[architecture.md §1.7](../../docs/architecture.md).

## Frozen
- **Type IDs:** `NotificationScheduleType`=15, `AppNotification`=16
  (these were missing from the old docs). Box: `notifications_box`,
  keyed by `id` (UUID) — **not** `notificationId`.
- **`AppNotification` `HiveField` 0–11;** `vibrateEnabled`=10,
  `soundEnabled`=11 default true on read. In JSON, `scheduleType`
  serializes as its `.index`.
- **JSON key:** `notifications` — **no legacy alias**.

## Rules
- **Two Android channels by sound, never merged:**
  `daily_notifications_sound` vs `daily_notifications_silent`. A
  channel's sound is immutable once created, so the channel id encodes
  it — renaming/merging breaks the sound toggle on installed devices.
- **`cancel()` must clear the base id plus all 7 derived weekday ids**
  (`(base & 0x7FFFFFF8) + weekday`) and stay try/catch-wrapped (survives
  a stale plugin cache after reinstall).
- **Alarms are inexact by design** (`inexactAllowWhileIdle`) — the app
  isn't an alarm clock and avoids `SCHEDULE_EXACT_ALARM`. Don't switch
  without a Play Store declaration.
- **Restore must call `rescheduleAll()`** so imported reminders
  re-register with the OS — `BackupRestoreService` does this; keep it.
- `generateNotificationId()` must stay collision-free against the box.

`AppHelpService` has no `notifications` case yet (falls back to
`help_not_available`) — see implementation_plan P2.2.
</content>
