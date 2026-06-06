# Shared backbone — area rules

The cross-cutting infrastructure every tool depends on: Drive/local
backup, restore, app switching, settings, localization, help. See
[architecture.md §3–§6](../../docs/architecture.md).

## Single sources of truth — don't fork them
- **Export:** [`sync_payload_builder.dart`](services/sync_payload_builder.dart)
  (`schemaVersion '8.0'`) is the only place the payload is built. It
  reads **every** box unguarded — keep its box list in sync with
  `main.dart`'s open set.
- **Import/restore:** [`backup_restore_service.dart`](services/backup_restore_service.dart)
  is the only restore path. Validates permissively, takes a safety
  backup, clears+rewrites each box, imports I Am defs **before** entries,
  runs `migrateOrderValues` + `rescheduleAll`, fires
  `DataRefreshService`.

## Drive / sync rules
- **Scope is `drive.appdata` only.** Mobile sign-in scopes
  `['email', drive.appdata]` **must match** the interactive sign-in in
  [data_management_tab_mobile.dart](pages/data_management_tab_mobile.dart),
  or silent sign-in returns null and background sync stops.
- **Backups are UTF-8** (`utf8.encode`); keep the `decodeBackupBytes`
  Latin-1 fallback. Never `String.codeUnits`.
- **Never auto-overwrite local data.** `isRemoteNewer()` →
  `blockUploads()`; the user explicitly Fetches. Keep
  `checkAndSyncIfNeeded()` returning false.
- `AllAppsDriveService.scheduleUploadFromBox` debounces 1000ms and
  always schedules a `LocalBackupService` backup (runs even when signed
  out). Dated backup filenames + retention must match across mobile,
  desktop, and local (see architecture.md §3.2).

## Gotchas
- `AppEntry` (typeId 2) has a registered adapter but is **never** boxed;
  the selected app is a plain `String` under `selected_app_id`.
- Only `en` + `da` are populated in
  [localizations.dart](localizations.dart); `t()` falls back en → key.
- `EnhancedGoogleDriveService` is **dead** relative to the active flow
  (single-file upsert, no-op conflict check). Don't build on it.
- `desktop_oauth_config.dart` holds an OAuth client **secret** — treat
  as sensitive; only the `.template` is tracked (implementation_plan P1.2).
</content>
