# Architecture

Twelve Steps App (Flutter; internal `MaterialApp` title "AA 4Step
Inventory", desktop window title "Twelve Steps app" / da "Tolv Trins
app") is a **suite of six recovery-practice tools plus a reminders
module**, sharing one offline-first storage layer and one optional
cloud backup.

The defining property of the system: **there is no backend.** Every
tool stores its data locally in Hive on the device. The only cloud
component is a single JSON file the app writes to the **user's own
Google Drive `appDataFolder`** — and that file is *backup/restore*,
not a live multi-device merge engine. A user who never signs into
Google has a fully working app; a user who does gets timestamped
recovery points and a manual cross-device restore.

This document describes *what the app does* (functional) and the
invariants every change must preserve (non-functional). The strict
rules that follow from these invariants live in the top-level
[CLAUDE.md](../CLAUDE.md) and the per-area `lib/<area>/CLAUDE.md`
files.

---

## 1. The six tools + notifications (functional)

All seven modules live in isolated folders under `lib/` (one per
folder: `models/`, `services/`, `pages/`). Each owns its Hive
box(es), routes its CRUD through its own service, and triggers the
shared Drive uploader after every mutation. Every screen's AppBar
carries the same four actions: **app switcher** (grid icon), **help**
(context-sensitive), **settings** (opens the shared Data Management
page), and an **EN/DA language** popup.

### 1.1 4th Step Inventory (`lib/fourth_step/`)
The original app, and the lowest Hive type IDs. Supports the AA 4th
Step moral inventory: the user records **inventory entries** across
four categories — resentment, fear, harms, sexual harms — using a
five-field structure (who/what, cause/why, affects-my, my part,
shortcomings). The category drives dynamic field labels and tooltips.
Each entry can be tagged with one or more reusable **"I Am" identity
definitions** (e.g. "Sober member of AA"). Three tabs: a Form,
an Entries list (persistent text filter that matches the first field
only at ≥2 chars; in-memory category-filter chips; drag-to-reorder;
default vs compact card layout), and a Settings tab (manage I Am
definitions with a delete-in-use guard, toggle compact view, export
CSV). CSV export uses `;` separators with a UTF-8 BOM for Excel/EU
locales.

### 1.2 8th Step Amends (`lib/eighth_step/`)
Supports Step 8: list everyone harmed and become willing to make
amends. The user records **Person** entries, each in one of three
willingness columns — **Yes / No / Maybe** — with optional amends
notes and an "amends done" flag. The single screen is a
drag-and-drop three-column board; cards move within and between
columns via a 1000-gap `sortOrder` scheme that rebalances when gaps
collapse. An add/edit dialog (`PersonEditDialog`) handles name,
amends, column, and the done toggle.

### 1.3 Morning Ritual (`lib/morning_ritual/`)
A daily morning-practice runner. The user defines an ordered list of
**ritual items** — *timer* items (a countdown meditation/silent
prayer that rings an alarm at the end) and *prayer* items (text to
read, e.g. 3rd Step, 7th Step, St. Francis). The **Today** tab runs
the ritual step-by-step: a 1-second countdown, wake-lock held only
while a timer actively runs, an alarm sound (`FlutterRingtonePlayer`,
`asAlarm`, 2s) plus a 3× vibration, all gated by each item's
sound/vibrate flags. It records each item completed/skipped and saves
a **MorningRitualEntry** for the day. History and a week/month
calendar review past days. An in-progress draft (device-local, in the
`settings` box, **not synced**) survives navigate-away and same-day
restart. An optional **auto-load** can force the app open into Morning
Ritual once per calendar day inside a configured time window — decided
in `main.dart` *after* the Drive sync/conflict check (so a freshly
restored window is honoured) and re-checked on resume via `AppWidget`'s
`WidgetsBindingObserver`.

### 1.4 Evening Ritual (`lib/evening_ritual/`)
A nightly 10th-step self-examination. Each day the user records one or
more **reflection entries** chosen from a fixed set of `ReflectionType`
categories (resentful, selfish, dishonest, afraid, apology owed, kept
to myself, kind and loving, could have done better, God's forgiveness,
corrective measures), each with optional detail. A single per-day
**"thinking focus" slider** (self ↔ others, stored 0–10) is persisted
as a special reflection entry (`thinkingFocus != null`). A Form tab
(with a week calendar to pick the day; today is editable, past days
are read-only) and a List tab grouped by date.

### 1.5 Gratitude (`lib/gratitude/`)
A daily gratitude journal. Each entry has two free-text fields —
**"Gratitude towards"** (a person/place/thing) and **"Grateful for"**
(what about it). A Today tab (collapsing form + today's entries; both
fields required) and a read-only history grouped by day. Entries are
**editable/deletable only on the day they were created**
(`canEdit`/`canDelete` compare `date` to today).

### 1.6 Agnosticism — "Surrender & Correction" (`lib/agnosticism/`)
The user records **Barrier/Power pairs**: a *Barrier* (something
blocking them — front/red side) and a *Power* (the corrective truth —
back/blue side). The core UI is a single flippable **"current paper"**
holding up to **5 active pairs**, with a real 3-D Y-axis flip (500ms)
between the barriers side and the powers side, driven by a flip button
and 40px horizontal swipes. Worked-through pairs are **archived**
(never hard-deleted from the active flow) into an Archive tab where
they can be restored (if under the 5-active cap) or permanently
deleted. The two tabs use gesture-driven navigation
(`NeverScrollableScrollPhysics`).

### 1.7 Notifications — reminders (`lib/notifications/`)
A standalone reminder tool. Each **AppNotification** fires either
*daily* or on selected *weekdays* at a chosen time, with per-reminder
vibrate/sound toggles and an enable/disable switch. Schedules persist
in Hive and register with the OS via `flutter_local_notifications`
(timezone-aware; runtime permission asks on mobile; inexact alarms by
design; iOS time-sensitive). Restoring a backup re-registers every
reminder with the OS (`rescheduleAll()`).

### 1.8 Shared shell (`lib/shared/`, `lib/app/`, `lib/main.dart`)
The cross-cutting backbone: the **app switcher** (a dialog listing all
tools; persists the selected id; `AppRouter` swaps the active home
widget), **Data Management** settings (Drive sign-in, backup
list/restore, sync toggle, sync-status chip; plus a General Settings
tab for the Morning Ritual auto-load window), **context-sensitive
help**, **EN/DA localization**, the Drive/local backup engine, and the
bootstrap in `main.dart` (Hive init, adapter registration, box open
with corruption recovery, migrations, silent sign-in, conflict check,
auto-load decision).

---

## 2. Data model & storage (non-functional invariants)

### 2.1 Hive type IDs — frozen, never reused
All 17 adapters are registered in [lib/main.dart](../lib/main.dart)
before any box is opened. Changing or reusing any `typeId` corrupts
existing user data on disk. The authoritative map (the `.g.dart`
adapters are the source of truth):

| typeId | Type | Area |
|---|---|---|
| 0 | `InventoryEntry` | fourth_step |
| 1 | `IAmDefinition` | fourth_step |
| 2 | `AppEntry` | shared (registered, never boxed) |
| 3 | `Person` | eighth_step |
| 4 | `ColumnType` | eighth_step |
| 5 | `ReflectionEntry` | evening_ritual |
| 6 | `ReflectionType` | evening_ritual |
| 7 | `GratitudeEntry` | gratitude |
| 8 | `BarrierPowerPair` | agnosticism |
| 9 | `RitualItemType` | morning_ritual |
| 10 | `RitualItem` | morning_ritual |
| 11 | `RitualItemStatus` | morning_ritual |
| 12 | `RitualItemRecord` | morning_ritual |
| 13 | `MorningRitualEntry` | morning_ritual |
| 14 | `InventoryCategory` | fourth_step |
| 15 | `NotificationScheduleType` | notifications |
| 16 | `AppNotification` | notifications |

The next free typeId is **17**. Enum types (`ColumnType`,
`ReflectionType`, `RitualItemType`, `RitualItemStatus`,
`NotificationScheduleType`) are persisted **by ordinal index** in both
Hive and JSON — new enum values must be **appended at the end**, never
inserted, and adapters default unknown bytes to the first value.
`HiveField` indices within a model are likewise frozen and additive
(see each area's `CLAUDE.md`).

### 2.2 Hive boxes — frozen names
| Box | Type | Area |
|---|---|---|
| `entries` | `InventoryEntry` | fourth_step |
| `i_am_definitions` | `IAmDefinition` | fourth_step |
| `people_box` | `Person` | eighth_step |
| `reflections_box` | `ReflectionEntry` | evening_ritual |
| `gratitude_box` | `GratitudeEntry` | gratitude |
| `agnosticism_pairs` | `BarrierPowerPair` | agnosticism |
| `morning_ritual_items` | `RitualItem` | morning_ritual |
| `morning_ritual_entries` | `MorningRitualEntry` | morning_ritual |
| `notifications_box` | `AppNotification` | notifications |
| `settings` | untyped | shared (prefs, sync state, drafts) |
| `windows_google_credentials` | untyped | shared (desktop OAuth only) |

Every data box (all except `settings`) is opened in `main.dart` inside
a try/catch that, on a decode failure, **deletes the box from disk and
recreates it empty** — a deliberate "lose this box's local data rather
than crash" recovery path (Drive/local restore is the recovery). The
`settings` box has **no** such fallback: if it is corrupt, startup
throws.

### 2.3 Per-app persistence & the shared sync trigger
Each area writes to its own box, then calls
`AllAppsDriveService.instance.scheduleUploadFromBox(box)` to trigger an
upload — debounced 1000ms (the desktop `WindowsDriveServiceWrapper`
adds a further 700ms coalesce). **Quirk to preserve:** most areas pass the
`InventoryEntry` `entries` box as the trigger handle even for their own
data — the passed box is only a trigger; the real payload always
re-reads *every* box via `SyncPayloadBuilder`. Each trigger is wrapped
in try/catch, so if the `entries` box isn't open the sync silently
no-ops (debug-logged only).

---

## 3. Google Drive sync & backup

### 3.1 One JSON file, schema v8.0
[`SyncPayloadBuilder`](../lib/shared/services/sync_payload_builder.dart)
is the **single source of truth** for the export payload
(`schemaVersion = '8.0'`). It reads every box and assembles one map.
[`AllAppsDriveService`](../lib/shared/services/all_apps_drive_service_impl.dart)
and [`LocalBackupService`](../lib/shared/services/local_backup_service.dart)
both serialize through it, so the cloud and on-device formats are
byte-identical.

Frozen top-level JSON keys:

```json
{
  "version": "8.0",
  "exportDate": "2025-12-03T14:30:15.123Z",
  "lastModified": "2025-12-03T14:30:15.123Z",
  "iAmDefinitions": [...],        // 4th step I Am definitions
  "entries": [...],               // 4th step inventory
  "people": [...],                // 8th step
  "reflections": [...],           // evening ritual
  "gratitude": [...],             // gratitude
  "agnosticism": [...],           // agnosticism barrier/power pairs
  "morningRitualItems": [...],    // morning ritual definitions
  "morningRitualEntries": [...],  // morning ritual daily completions
  "notifications": [...],         // reminders
  "appSettings": {                // v8.0+
    "morningRitualAutoLoadEnabled": false,
    "morningRitualStartTime": "05:00:00",
    "morningRitualEndTime": "09:00:00",
    "fourthStepCompactViewEnabled": false,
    "language": "en",             // optional, device-portable
    "selectedAppId": "..."        // optional, device-portable
  }
}
```

**Legacy read-aliases (import only, never written):** restore accepts
`gratitudeEntries` for `gratitude` and `agnosticismPapers` for
`agnosticism`. Export only ever writes the new keys. Every `fromJson`
decoder uses `field ?? default`, so older payloads — e.g. backups that
predate `notifications` or `appSettings` — still import without
throwing.

### 3.2 Dated backups & retention
Every upload writes a **new** timestamped file (not an overwrite) into
the Drive `appDataFolder`:

```
twelve_steps_backup_2025-12-03_14-30-15.json   today, 2:30:15 PM
twelve_steps_backup_2025-12-03_10-15-42.json   today, 10:15:42 AM
twelve_steps_backup_2025-12-02.json            yesterday (one/day)
twelve_steps_backup_2025-11-15.json            November (one/month)
```

Filename pattern (load-bearing for listing, cleanup, and conflict
detection across mobile / desktop / local — all three must stay
identical):

```dart
final dateStr = '${y}-${m2}-${d2}';                 // 2025-12-03
final timeStr = '${h2}-${min2}-${s2}';              // 14-30-15
'twelve_steps_backup_${dateStr}_$timeStr.json';
```

**Drive retention** (mobile + desktop): keep **all** of today's
timestamps; keep **one per day** for the previous 7 days (latest);
keep **one per month** for months within the last year (latest);
**delete** anything older than 12 months. Cleanup groups backups by
date (`backupsByDate`) and by month (`backupsByMonth`), builds a
keep-set, and deletes the rest, using boundaries `weekCutoff = today −
7 days` and `yearCutoff = the same day last year`. It runs *after* each
upload — and is deliberately **not** run from `listAvailableBackups()`
(decoupled to avoid deleting data while merely listing it).

### 3.3 Conflict detection & no auto-overwrite
The `settings` box key `lastModified` is the **local clock**; the
newest backup's *internal* JSON `lastModified` (read cheaply via an
HTTP Range prefix download, not a full parse) is the **remote clock**.
On startup `isRemoteNewer()` compares them; if remote is newer it calls
`blockUploads()`, and [AppWidget](../lib/app/app_widget.dart) shows a
non-dismissible **"Newer Data Available"** dialog after first frame:
*Fetch* downloads and restores the newest backup; *Keep Local* calls
`unblockUploads()`. **Auto-restore is permanently disabled for safety**
— `checkAndSyncIfNeeded()` is `@Deprecated` and always returns false;
local data is mutated **only** by an explicit user fetch/restore.

### 3.4 Encoding
Backups are written **UTF-8** (`utf8.encode`); `decodeBackupBytes()`
decodes strict UTF-8 with a **Latin-1 fallback** so legacy files stay
readable. **Never** write `String.codeUnits`: under UTF-16, any
character above U+00FF (em-dash, smart quotes, Danish æ/ø/å, emoji) is
rejected by the Drive media layer and the upload silently fails.

### 3.5 Local backups
[`LocalBackupService`](../lib/shared/services/local_backup_service.dart)
mirrors every Drive backup to `<AppDocuments>/backups/` with the same
filename pattern and the same `SyncPayloadBuilder` content. It runs on
every change (debounced 1000ms) **even when not signed into Drive**, so
there is always a recovery path. It is also used to take a **pre-restore
safety backup** before any destructive import. Local retention keeps
today's = all and one/day for 7 days, then **deletes** older (no
monthly tier, unlike Drive).

### 3.6 Restore / import path
[`BackupRestoreService`](../lib/shared/services/backup_restore_service.dart)
is the **single import path** (Drive restore, local restore, JSON file
import). It validates (permissive — warns, never fails, on a missing
`version`), takes a safety backup, then `_applyPayload` **clears and
rewrites every box**. Ordering matters: **I Am definitions import
before entries** (entries reference them by id), and after import it
runs `InventoryService.migrateOrderValues()` and
`NotificationsService.rescheduleAll()`, updates `lastModified`, and
fires `DataRefreshService.notifyDataRestored()` to rebuild the UI. A
restore is a **full replace**, so local-only records not present in the
backup are wiped.

### 3.7 Restore-point UX & scenarios
When signed into Drive, the Data Management tab shows a **Select
Restore Point** card: a Refresh button, a dropdown of available backups
(today's by time, prior days by date, monthly points), and a *Restore
from Backup* button (with an overwrite-confirm). This protects against:
accidental deletion (roll back to earlier today / yesterday), bad
imports (roll back to pre-import), sync mistakes (revert to an earlier
point), and long-term loss (monthly points for up to a year).

### 3.8 First-time sign-in & fetch prompt
On the **first interactive Google sign-in on a fresh install**, the app
prompts "Fetch data from Google Drive?" — *Fetch* restores the latest
backup (use this on a new device); *Cancel* starts fresh. Sync is
enabled automatically after the prompt. The prompt fires **once per
installation**, gated by `syncPromptedMobile` / `syncPromptedWindows`
in `settings`; existing users with `syncEnabled = true` never see it.

---

## 4. Authentication (OAuth)

The app uses the restricted **`drive.appdata`** scope only — it can see
**only** the app-private `appDataFolder`, never the user's other Drive
files. Two auth backends, chosen by platform:

### 4.1 Mobile (Android / iOS)
[`MobileGoogleAuthService`](../lib/shared/services/google_drive/mobile_google_auth_service.dart)
uses `google_sign_in` with scopes `['email', drive.appdata]`. **These
scopes must match** the interactive sign-in in
[data_management_tab_mobile.dart](../lib/shared/pages/data_management_tab_mobile.dart),
or `signInSilently()` returns null under strict Play Services scope
matching and background sync dies. `refreshTokenIfNeeded()` recovers
the account via `signInSilently()` + auth-cache clear before re-minting
a token. Android auth is wired via SHA-1 + package name; iOS via the
iOS client ID in code and `Info.plist` (no per-build setup).

### 4.2 Desktop (Windows / macOS / Linux) — loopback OAuth
`google_sign_in` has no desktop implementation, so **all desktop
platforms** (dispatched by `PlatformHelper.isDesktop`) use the
[Windows*](../lib/shared/services/google_drive/) services with a
**loopback-IP** flow:

1. User clicks sign-in → app starts a local HTTP server on
   `127.0.0.1:PORT`.
2. App opens the browser to the Google OAuth consent URL.
3. User authorizes; Google redirects to `127.0.0.1:PORT`.
4. App receives the auth code (browser shows a success page), exchanges
   it for tokens, caches them in the `windows_google_credentials` Hive
   box, and stops the server.

Why loopback: it is Google's required method for native desktop apps
(custom URI schemes are deprecated for desktop), needs no external
server, binds only to `127.0.0.1` (not network-reachable), and the
temporary server stops immediately after the callback. The refresh
token is stored locally for silent re-auth. For desktop apps the OAuth
client ID + secret merely *identify* the app (not true server secrets).
The setup procedure and troubleshooting live in the
[implementation_plan.md runbooks](./implementation_plan.md#release--environment-runbooks).

---

## 5. Localization
All UI strings for all tools live centrally in
[lib/shared/localizations.dart](../lib/shared/localizations.dart), in
**English (en) and Danish (da)** only. `t(context, 'key')` returns the
current-locale string (falls back en → raw key).
[`LocaleProvider`](../lib/shared/services/locale_provider.dart) (a
`ChangeNotifier`, injected via Modular, persisted under the `language`
key) drives `MaterialApp.locale`; every screen's AppBar has the EN/DA
popup. Key prefixes follow the area: `agnosticism_*`, `gratitude_*`,
`morning_ritual_*`, `evening_ritual_*` / `reflection_type_*`,
`eighth_step_*`, `category_*` / `*_field1` (4th step), `notifications_*`
/ `weekday_*`, `app_*` (tool names/descriptions), `help_*`. Danish text
runs longer than English — verify both lay out without clipping.

---

## 6. App-switching & routing
[`AppSwitcherService`](../lib/shared/services/app_switcher_service.dart)
holds the active tool as a `ValueNotifier<String>` (`selectedAppNotifier`)
backed by the `selected_app_id` key in `settings` (default
`fourth_step_inventory`).
[`AppRouter`](../lib/shared/pages/app_router.dart) listens to it and
renders the matching `*Home`, each wrapped in `ValueKey(appId)` so
switching apps rebuilds a fresh subtree. Unknown ids fall back to the
4th-step home. App-id constants live in `AvailableApps`
(`app_entry.dart`): `fourth_step_inventory`, `eighth_step_amends`,
`evening_ritual`, `morning_ritual`, `gratitude`, `agnosticism`,
`notifications`. `AppEntry` instances are built transiently from
localized strings each call — they have a registered Hive adapter
(typeId 2) but are **never** stored in a box.

The runtime flow:

```
main.dart  (Hive init · register 17 adapters · open 11 boxes ·
            migrations · silent sign-in · isRemoteNewer→blockUploads ·
            morning-ritual force check)
   → ModularApp(AppModule, AppWidget)
   → AppWidget  (MaterialApp.router · locale · resume-time auto-load ·
                 "Newer Data Available" fetch prompt)
   → AppModule  (Modular DI: LocaleProvider, DataRefreshService,
                 settings Box; route '/')
   → AppRouter  (selectedAppNotifier → active tool home)
   → 4th Step · 8th Step · Morning · Evening · Gratitude · Agnosticism · Notifications
        ↓ every mutation
   → AllAppsDriveService.scheduleUploadFromBox()
        → LocalBackupService (always) + Drive upload (if signed in & not blocked)
        → payload built once by SyncPayloadBuilder
```

---

## 7. Backend constraints (deliberately absent)
The system excludes the following **by design**; these are invariants.
The rationale for each is in
[historic_implementation.md](./historic_implementation.md).

- **No Firebase / no server.** Sync is a single self-managed JSON file
  on the user's own Drive, not a backend database.
- **No full Drive scope.** Only `drive.appdata` (the app-private
  folder). The app cannot read the user's other Drive content.
- **No web platform.** Removed after early exploration; targets are
  mobile + desktop only.
- **No `MANAGE_EXTERNAL_STORAGE`.** Removed via the AndroidManifest
  template for Play Store policy compliance.
- **No billing.** The app is free to run; Drive is optional and uses
  the user's own quota.
- **No live multi-device merge.** Cross-device transfer is an explicit,
  user-initiated restore — never an automatic overwrite of local data.

---

## 8. Stack & layout

```
lib/
  main.dart                     Bootstrap: Hive init, 17 adapter regs,
                                11 box opens (corruption-recovery),
                                migrations, silent sign-in, conflict
                                check, morning-ritual force.
  app/
    app_module.dart             Flutter Modular DI + '/' route (AppHomePage)
    app_widget.dart             Root MaterialApp.router; locale; resume
                                auto-load; "Newer Data Available" prompt

  shared/                       Cross-cutting backbone (all tools depend on it)
    localizations.dart          All EN/DA strings; t(context, 'key')
    models/app_entry.dart       AppEntry + AvailableApps (app-id constants)
    pages/
      app_router.dart           Active-tool switcher (ValueKey per app)
      data_management_page.dart Settings: Data Management + General Settings tabs
      data_management_tab_mobile.dart   Mobile sync/backup UI + fetch prompt
      data_management_tab_windows.dart  Desktop (loopback) sync/backup UI
    services/
      all_apps_drive_service_impl.dart  Drive sync facade (debounce, block,
                                        auth-recovery, conflict)
      sync_payload_builder.dart         SINGLE export source (schema 8.0)
      backup_restore_service.dart       SINGLE import/restore path
      local_backup_service.dart         On-device backup mirror
      app_switcher_service.dart         Selected-app state
      app_settings_service.dart         appSettings (auto-load window, compact)
      app_help_service.dart             Per-tool help dialogs
      locale_provider.dart              EN/DA locale
      app_version_service.dart          Version/install tracking
      data_refresh_service.dart         Post-restore rebuild signal
      google_drive/                     Mobile + desktop Drive/auth backends,
                                        GoogleDriveCrudClient (Drive v3 CRUD)
    utils/                              platform_helper, sync_utils

  fourth_step/  eighth_step/  morning_ritual/  evening_ritual/
  gratitude/    agnosticism/  notifications/    Each: models/ services/ pages/

docs/
  architecture.md               This file
  historic_implementation.md    Build timeline + migration notes
  implementation_plan.md        Roadmap + release/setup runbooks
  LOCAL_SETUP.md                Dev environment setup (kept separate)
  play_store-retain/            Store listing copy (retained)
  static_guidelines/            CLAUDE.md authoring reference (frozen)
test/
  morning_ritual_progress_test.dart   Draft round-trip / same-day-resume guard
```

`SyncPayloadBuilder` reads **every** box with `Hive.box<T>(...)`
(non-open-safe). If `main.dart` ever stops opening one of these boxes,
building the payload throws — keep `main.dart`'s open-set in sync with
the builder's box list.

---

## 9. Adding a new tool
1. Add the app-id constant to `AvailableApps` in
   [app_entry.dart](../lib/shared/models/app_entry.dart) and to
   `AvailableApps.getAll()`.
2. Add a case to `AppRouter._buildAppForId`.
3. Create `lib/<area>/` with `models/`, `services/`, `pages/` and a
   per-area `CLAUDE.md`.
4. Register the new Hive type IDs (next free is **17**) in `main.dart`
   and open the new box(es) with the corruption-recovery pattern.
5. Add export in `SyncPayloadBuilder.buildPayload` and import in
   `BackupRestoreService` (new top-level JSON key; keep decoders
   tolerant).
6. Route every mutation through your service →
   `AllAppsDriveService.scheduleUploadFromBox`.
7. Add EN + DA strings, a help case in `AppHelpService`, and update
   this doc + [historic_implementation.md](./historic_implementation.md).
</content>
</invoke>
