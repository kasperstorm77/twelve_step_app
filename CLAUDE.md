# CLAUDE.md

Operating rules for this repo. Read them before writing code.

Twelve Steps App is a Flutter suite of six recovery tools + a reminders
module, sharing one offline-first Hive layer and one optional Google
Drive backup file. No backend. Each `lib/<area>/` folder has its own
`CLAUDE.md` — read it before touching that area.

The three canonical docs (open the one that fits, then come back):
- [docs/architecture.md](docs/architecture.md) — what the app does and
  the invariants every change must preserve.
- [docs/historic_implementation.md](docs/historic_implementation.md) —
  why things are the way they are, phase by phase. Skim before
  "fixing" something that looks odd — it's usually load-bearing.
- [docs/implementation_plan.md](docs/implementation_plan.md) — what's
  next, plus the iOS-release and desktop-OAuth runbooks. New work goes
  here first.

---

## Hard rules — never violate

### Storage (Hive)
1. **Hive type IDs are frozen and never reused.** The map runs 0–16
   ([architecture.md §2.1](docs/architecture.md)); the next free id is
   17. Changing or reusing one corrupts data on disk.
2. **`HiveField` indices never move, and enums are append-only.** Schema
   changes are additive — new fields get new indices with a tolerant
   `field ?? default` decoder. Enums (`ColumnType`, `ReflectionType`,
   `RitualItemType`, `RitualItemStatus`, `NotificationScheduleType`) are
   stored by ordinal in Hive and JSON; add values at the end, never
   insert or reorder.
3. Box names are frozen ([architecture.md §2.2](docs/architecture.md)).
   When you add a box, open it in [main.dart](lib/main.dart) with the
   existing delete-and-recreate-on-corruption fallback, and add it to
   `SyncPayloadBuilder` — that builder reads every box unguarded, so a
   box it expects but `main.dart` didn't open throws at upload.

### Sync & backup
4. One export path, one import path. All export goes through
   [`SyncPayloadBuilder`](lib/shared/services/sync_payload_builder.dart)
   (`schemaVersion '8.0'`); all restore/import goes through
   [`BackupRestoreService`](lib/shared/services/backup_restore_service.dart).
   Don't serialize or restore a box anywhere else.
5. Drive JSON keys are frozen; changes are additive
   ([architecture.md §3.1](docs/architecture.md)). Restore must keep
   accepting the legacy aliases `gratitudeEntries` and
   `agnosticismPapers`, and must import I-Am definitions before entries.
6. **Backups are UTF-8** — write with `utf8.encode`, never
   `String.codeUnits`; keep the Latin-1 read fallback for legacy files.
7. Route every data mutation through its area service →
   `AllAppsDriveService.scheduleUploadFromBox(...)`. No widget writes a
   box and uploads on its own.
8. **Never auto-overwrite local data.** `isRemoteNewer()` only
   `blockUploads()`; the user explicitly *Fetches*. Keep
   `checkAndSyncIfNeeded()` returning false.

### Backend constraints
9. No Firebase, no server, no full Drive scope. Sync is one JSON file in
   the user's own `drive.appdata`. Don't add `firebase_*`, a broader
   Drive scope, the web platform, `MANAGE_EXTERNAL_STORAGE`, or any
   billed dependency — each reverses a shipped decision
   ([historic_implementation.md](docs/historic_implementation.md)).

### UI & localization
10. Localize every user-visible string in both `en` and `da` via
    `t(context, 'key')` in
    [localizations.dart](lib/shared/localizations.dart). No hardcoded
    user text. Danish runs longer — check both lay out.
11. Every screen's AppBar keeps the four actions: app switcher, help,
    settings (Data Management), EN/DA language popup. Every routed tool
    has an `AppHelpService` case — keep it that way when adding one.
12. **Dates are localized separately from `t()`.** Use
    [`shared/utils/date_formats.dart`](lib/shared/utils/date_formats.dart);
    a bare `DateFormat.yMMMMd()` renders English inside the Danish UI.
13. **Never give the system bars a colour.**
    `ThemeData.appBarTheme.systemOverlayStyle` stays
    [`appSystemOverlayStyle`](lib/shared/utils/system_ui.dart) with all three
    colours null — each non-null one calls an API Android 15 deprecated and
    Google Play flags. `targetSdk` 36 forces edge-to-edge, so every
    `Scaffold` body needs `SafeArea(top: false, ...)`.

---

## Process

- Don't bump `pubspec.yaml` `version:` unless asked — it's the user's
  call; build at whatever it says.
- Don't commit or push unless explicitly asked.
- Don't skip git hooks (`--no-verify` etc.) unless told to. If a hook
  fails, fix the cause.
- Keep the three docs current: a changed invariant → `architecture.md`;
  a notable pivot or fix → append to `historic_implementation.md`; a
  landed or new roadmap item → `implementation_plan.md` — same PR.
- After editing any Hive model (`lib/**/models/**`), regenerate the
  adapters with `dart run build_runner build --delete-conflicting-outputs`
  before `flutter analyze`/`flutter test` — a stale `*.g.dart` fails the
  build. Full local setup (codegen, gitignored credential files, platform
  config) lives in [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md).
- Before reporting a change done: `flutter analyze` is clean and
  `flutter test` passes. Keep `main.dart`'s open-box set in sync with
  `SyncPayloadBuilder`.
- **Answer short, clear, concise — and end with one recommended next
  step.** A reply is the finding plus what to do about it, not a survey.
  Lead with the answer; drop the preamble. Prefer a few lines or a tight
  list over prose; no exhaustive option lists, no restating what the user
  just said. Close with a single recommendation ("Next: …") rather than
  several choices — if a real decision is needed, ask one question. All
  supporting detail belongs in the three docs above, linked, not pasted
  into chat.

---

## Quick reference

| Task | Where |
|---|---|
| New tool / app | [architecture.md §9](docs/architecture.md); constant in [`app_entry.dart`](lib/shared/models/app_entry.dart), case in [`app_router.dart`](lib/shared/pages/app_router.dart), new `lib/<area>/` + `CLAUDE.md` |
| New Hive type | next free typeId 17; register in [`main.dart`](lib/main.dart) + open box w/ corruption fallback |
| Sync a new box | export in [`sync_payload_builder.dart`](lib/shared/services/sync_payload_builder.dart), import in [`backup_restore_service.dart`](lib/shared/services/backup_restore_service.dart) |
| New string | add `en` + `da` in [`localizations.dart`](lib/shared/localizations.dart) |
| Drive / auth change | [`all_apps_drive_service_impl.dart`](lib/shared/services/all_apps_drive_service_impl.dart) + `lib/shared/services/google_drive/` |
| Ship a release | `deploy-release` agent + `scripts/{build-aab,upload-aab-to-play,upload-ipa-to-testflight}.sh`; notes in `release.md`; setup in [implementation_plan.md](docs/implementation_plan.md) Store release runbook |

When the docs and the code disagree, the code wins — fix the doc in the
same PR.
</content>
