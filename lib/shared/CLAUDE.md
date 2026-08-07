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
  backup, clears+rewrites each box **present in the payload**, imports I Am
  defs **before** entries, runs `migrateOrderValues` +
  `migrateSortOrders` + `rescheduleAll`, fires `DataRefreshService`.
  **Decode a section before clearing its box** — the old order threw
  mid-rewrite on one bad record and left the box holding a fragment.
  Unreadable records are skipped and counted in
  `RestoreCounts.skippedRecords`, never fatal.

## Before a store release
**Run `bash scripts/verify-cross-app-recovery.sh` — it must exit 0** (root
CLAUDE.md hard rule 9). Fixtures on both sides are not enough; it builds a live
payload from `SyncPayloadBuilder` and runs it through Emotional Sobriety's own
`BackupValidator`. Any change in this folder to export, restore, or a shared
model is exactly what it exists to catch.

## Importing another product's backup
- This app **never writes a `product` key**; a payload that has one is
  foreign. `emotional-sobriety` `1.0` is the only supported foreign
  product — five sections map on, the rest are ignored without error.
- Accepted **only** with `allowForeignProduct: true`, which only the
  manual JSON path passes, behind `confirmForeignImport` naming every
  dataset and count. The Drive path must never pass it — that is what
  keeps hard rule 8 true for someone else's file.
- Sections the other product lacks stay **absent** from the translated
  payload, not empty, so importing it keeps this device's gratitude,
  amends, reflections and reminders.
- Normalize, don't reject: pairs beyond the five-active cap are
  **archived**, a second randomized reading loses only its source ID.

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
- **But push local work automatically.** `uploadIfLocalNewer()` (startup) and
  `flushPendingUpload()` (app backgrounding) exist because the 1000 ms upload
  debounce is lost when the OS suspends the process — a finished morning
  ritual that never left the phone. Both directions read one verdict from
  `sync_clocks.dart`; never add a second timestamp comparison.
- `AllAppsDriveService.scheduleUploadFromBox` debounces 1000ms and
  always schedules a `LocalBackupService` backup (runs even when signed
  out). Dated backup filenames + retention must match across mobile,
  desktop, and local (see architecture.md §3.2).

## Gotchas
- `AppEntry` (typeId 2) has a registered adapter but is **never** boxed;
  the selected app is a plain `String` under `selected_app_id`.
- Only `en` + `da` are populated in
  [localizations.dart](localizations.dart); `t()` falls back en → key. The
  two maps must define the **same key set** —
  `test/localized_dates_test.dart` fails on any key present in one only.
- **Dates don't go through `t()`.** Use
  [utils/date_formats.dart](utils/date_formats.dart), which passes the active
  locale to `intl`; a bare `DateFormat.yMMMMd()` renders English inside the
  Danish UI.
- `EnhancedGoogleDriveService` was deleted — it had no references at all.
  The live flow is `AllAppsDriveService` → the Mobile/Windows services with
  dated multi-file backups. Don't reintroduce a single-file upsert path.
- `desktop_oauth_config.dart` holds an OAuth client **secret** — treat
  as sensitive. It is git-ignored and only the `.template` is tracked;
  neither the live client id nor the secret has ever been committed
  (verified against full history).
</content>
