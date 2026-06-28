# Historic Implementation

A timeline of what's been built and the design pivots behind each
phase. This is for orientation only — file:line citations rot, so
verify against current code before relying on a specific reference.
The architectural invariants that resulted from this history live in
[architecture.md](./architecture.md); the strict rules in
[CLAUDE.md](../CLAUDE.md).

---

## Phase 1 — Single-app 4th Step Inventory (MVP)
The project began as a standalone Flutter app for the AA 4th-step
inventory ("Initial commit — AA 4Step Inventory Flutter app"). Data
lived locally in Hive (`InventoryEntry`, typeId 0). Early work split
data management from settings — moving CSV export and Google Drive
behind a gear-icon menu — and stripped out an early platform-abstraction
layer and unused state management to keep the single app lean.

## Phase 2 — "I Am" role-based inventory + data-safety protections
Added a second concept: **"I Am" identity definitions**
(`IAmDefinition`, typeId 1) linked to inventory entries via an `iAmId`
field, with a dedicated `IAmService`. This was the first real
data-relationship in the model, and it shipped paired with explicit
data-safety protections so role-based edits couldn't silently lose
entries. Later extended to **multiple I Am definitions per entry**
(the dual `iAmId` + `iAmIds` export contract that still exists for
backward compatibility).

## Phase 3 — Google sign-in and first cross-device sync
Wired up Google Sign-In with platform-specific Android/iOS OAuth
clients. Much of the effort went into hardening the sign-in UX: a
`_signingInProgress` guard to stop mid-sign-in rebuilds and double
dialogs, and correct `iAmId` parsing when syncing entries down from
Drive. `MANAGE_EXTERNAL_STORAGE` was **deliberately removed** via an
AndroidManifest template to avoid Play Store policy problems. This
established cross-device transfer of a single app's data via a Drive
JSON file.

## Phase 4 — Windows desktop + loopback OAuth
Added Windows as a target with timestamp-based sync. Because
`google_sign_in` has no desktop implementation, desktop auth switched
to a **loopback-IP OAuth flow** (`http://127.0.0.1:PORT`) with
browser-based consent, plus deep-link handling and a Windows release
ZIP build script. The **web platform was removed** in the same era.
This established the desktop-vs-mobile auth split the suite still
relies on.

## Phase 5 — Expansion into a multi-app suite
The single app grew into a suite, each tool an isolated folder with
its own models/services/pages reusing the shared Drive sync rather than
reimplementing it:
- **Evening Ritual** (`ReflectionEntry` 5 / `ReflectionType` 6)
- **Gratitude** (`GratitudeEntry` 7; later the two-field
  gratitudeTowards / gratefulFor shape)
- **Agnosticism / Surrender & Correction** (`BarrierPowerPair` 8;
  a design spec preceded the build — note this replaced an older
  `PaperStatus`/`AgnosticismPaper` model whose typeIds 8/9 were reused,
  so old on-disk agnosticism data is intentionally not migrated)
- **8th Step Amends** (`Person` 3 / `ColumnType` 4; `Person`'s typeId
  was moved **1→3** to avoid colliding with `IAmDefinition`)

## Phase 6 — Centralized sync: `AllAppsDriveService`
Drive services moved into `shared/` and the legacy per-app
`DriveService` was replaced by a single **`AllAppsDriveService`**
syncing all apps into **one** Drive JSON file (schema versioned up
through v7.0 → v8.0). This killed multi-file cross-app conflicts and
gave one source of truth. The split between `MobileDriveService` and
`WindowsDriveServiceWrapper` was formalized behind a `GoogleDriveCrudClient`
and an `EnhancedGoogleDriveService` (debouncing/events), with debounced
uploads to coalesce rapid edits.

## Phase 7 — Sixth tool (Morning Ritual) + app-switcher architecture
**Morning Ritual** was added (timers, prayers, calendar; `RitualItem`
/ `MorningRitualEntry`, typeIds 9–13), completing the six-tool suite.
`AppSwitcherService` persists the selected app in the `settings` box
and `AppRouter` swaps home pages. The suite crossed from 1.x to **2.0.0**
around this consolidation. **Auto-load** could force Morning Ritual open
within a configurable morning window, with a device-specific
"last forced date" (not synced) so it fires at most once per day.

## Phase 8 — Dated backup history + restore points
Replaced always-overwrite sync with **timestamped backup files**: each
sync writes a dated file and old ones are cleaned up on a retention
schedule, with a Data Management dropdown to pick a restore point. The
reasoning was pure data safety — recover from accidental deletions, bad
imports, or sync mistakes by rolling back rather than losing data on the
next overwrite. The same era hardened **auto-sync safety** — *only*
sync into an empty local store, and prompt the user to fetch rather than
auto-overwriting — which is the origin of today's never-auto-overwrite
invariant. The retention window grew incrementally afterwards (the
12-month-monthly tier landed with the first-time fetch-prompt fix,
*before* the Phase 11 refactor) to today-all / 7-day-daily /
12-month-monthly.

## Phase 9 — Notifications module + alarm/wake-lock hardening
Added the **Notifications** module for scheduled reminders integrated
with Drive sync and alarm preferences (`AppNotification` 16 /
`NotificationScheduleType` 15), plus per-ritual-item notification
settings. Follow-ups added a **wake lock** for the Morning Ritual
timer, vibrate/sound options, fixed scheduling/permissions, and
resolved a **notification-cancel crash after reinstall** (stale plugin
cache — `cancel()` is now try/catch-guarded). A `LinuxInitializationSettings`
entry was later added to the `flutter_local_notifications` init.

## Phase 10 — Local backup as an offline supplement
Added **`LocalBackupService`**, mirroring the Drive backup's naming and
JSON content into the app documents folder — with a *simpler* retention
(today = all + one/day for 7 days, no monthly tier, unlike Drive). The
UI unifies the two — Drive backups when signed in, local backups when not — with automatic
debounced local backups on every change and a manual "Create Local
Backup" button when offline. Drive takes precedence when signed in.
This guaranteed a recovery path even for users who never touch Google.

## Phase 11 — Backup-system refactor: `BackupRestoreService` + `SyncPayloadBuilder` (schema v8.0)
A large refactor unified **all import/restore** behind a new
`BackupRestoreService` and **all export** behind `SyncPayloadBuilder`
emitting consistent JSON schema **v8.0**. Two safety changes mattered
most: cleanup was **removed from `listAvailableBackups()`** (so merely
listing can't delete data), and a **safety backup is taken before any
destructive clear**. The reactive model modernized — per-app
`onAppSwitched` callbacks gave way to a single `ValueListenableBuilder`
on `AppSwitcherService.selectedAppNotifier`. Bundled with a Flutter
3.35.6 → 3.38.5 upgrade.

## Phase 12 — Desktop OAuth generalized to all desktop platforms
`AllAppsDriveService`'s hardcoded `PlatformHelper.isWindows` checks
became an **`isDesktop`** check, so **macOS and Linux** also route
through the loopback OAuth flow (`WindowsDriveServiceWrapper`) instead
of falling through to the mobile `google_sign_in` path that has no
desktop implementation. Loopback browser-auth became the universal
desktop sync mechanism.

## Phase 13 — Silent Drive-sync resilience on mobile
Fixed a class of "saves locally, never reaches Drive" bugs on Android:
- **Scope alignment.** The background `MobileGoogleAuthService` requested
  only `driveAppdata` while the interactive tab requested
  `email + driveAppdata`. Newer Play Services strictly match scopes on
  `signInSilently()`, so the background instance returned null and the
  Drive client was never built. Scopes now match.
- **Auto auth recovery.** Because the tab and background sync use
  separate `GoogleSignIn` instances, an expired one-shot token couldn't
  refresh. `refreshTokenIfNeeded()` now recovers the account via
  `signInSilently()` and clears the auth cache so the retry mints a
  fresh token. The 403/insufficient-scope branch self-heals on one
  retry too.
- **Visibility.** Previously-swallowed upload errors are surfaced and a
  passive **sync-status chip** (last success / error / blocked / off)
  was added. Recovery only affects the upload direction; it never
  mutates local Hive data.

## Phase 14 — UTF-8 encoding fix for Drive backups
Backups were uploaded via `content.codeUnits` (UTF-16) and read with
`String.fromCharCodes`, so any character above U+00FF (em-dash, smart
quotes, Danish æ/ø/å, emoji) produced a value the HTTP media layer
rejected — **silently failing every affected backup**. The fix uses
`utf8.encode` on write and a new `decodeBackupBytes()` that decodes
strict UTF-8 with a Latin-1 fallback so legacy backups stay readable.
This was the real root cause behind "saves locally, never reaches
Drive," and shipped in **2.2.10+103** (later re-tagged 2.2.11+104 in a
version-only bump).

## Phase 15 — Family-sharing privacy & store-compliance artifacts
Added the non-code artifacts for store distribution and Google Play
Family Sharing: a Danish family-sharing privacy policy, a
`family_sharing_contact.md` with support/response-time language, Play
Store descriptions, and a separate AI Madplan privacy policy. CSV
export was also fixed for locale-correct output (semicolon separator,
UTF-8 BOM). Productization/compliance rather than feature work.

## Phase 16 — Desktop polish: local-backup location & alarm cut-off
Two desktop/UX bug fixes:
- **Local backups flooded the user's Documents on desktop.**
  `LocalBackupService` rooted its `backups/` folder at
  `getApplicationDocumentsDirectory()`, which on desktop resolves to the
  *real* `~/Documents` (XDG `DOCUMENTS`), not an app sandbox. Every
  debounced change (and the launch-time mutations) dropped a dated JSON
  there. Fixed by using `getApplicationSupportDirectory()` on desktop
  (`PlatformHelper.isDesktop`) while keeping the already-sandboxed
  documents dir on mobile, plus a one-time best-effort migration of
  stray `~/Documents/backups/` files into the new app-private dir. See
  [architecture.md §3.5](./architecture.md). Guarded by
  `test/local_backup_directory_test.dart`.
- **Morning Ritual alarm was cut off.** `_playAlarm` force-stopped the
  ringtone after a hardcoded 2 seconds; with `looping: false` the alarm
  tone is finite, so the delay just truncated it. Removed the timed stop
  so the sound plays to its natural end, and added `_stopAlarmSound()`
  on user-advance (complete/skip/previous/start over) and `dispose` so it
  is silenced intentionally rather than on a timer. While here, noted
  that `flutter_ringtone_player` is android/ios-only — desktop has no
  real alarm sound (implementation_plan P2.4).

---

## Data-format migration notes
- **v6.0 → v7.0.** Added `morningRitualItems` and `morningRitualEntries`;
  renamed the backup file from `aa4step_inventory_data.json` to
  `twelve_steps_backup.json`; removed the single always-overwrite main
  file in favor of timestamped backups only.
- **v7.0 → v8.0.** Added `notifications` and the `appSettings`
  sub-object (Morning Ritual auto-load window, 4th-step compact view,
  optional device-portable `language` / `selectedAppId`).
- **Upgrading users.** Old `aa4step_inventory_data*.json` files remain
  on Drive but are no longer updated; new backups use
  `twelve_steps_backup_*.json`. A manual cross-version migration is:
  export from the old version, import into the new one.

---

## What's deliberately *not* in the codebase
These exclusions are load-bearing — restoring any unwinds a shipped
decision. Mirrored as hard rules in [CLAUDE.md](../CLAUDE.md) and
[architecture.md §7](./architecture.md#7-backend-constraints-deliberately-absent).

- **No Firebase / no central server** — sync is one JSON file on the
  user's own Drive.
- **No full Drive scope** — only `drive.appdata`.
- **No web platform** — explicitly removed.
- **No `MANAGE_EXTERNAL_STORAGE`** — removed for Play Store policy.
- **No multi-file per-app sync** — abandoned for one shared JSON to
  avoid cross-app conflicts (the legacy `DriveService` was deleted).
- **No per-app `onAppSwitched` callbacks** — replaced by a single
  `ValueListenableBuilder` on `selectedAppNotifier`.
- **No auto-delete during listing** — cleanup is decoupled from
  `listAvailableBackups()`.
- **No auto-restore** — `checkAndSyncIfNeeded()` is deprecated and
  always returns false; cross-device transfer is user-initiated only.
</content>
