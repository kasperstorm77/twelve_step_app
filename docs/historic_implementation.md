# Historic Implementation

A timeline of what's been built and the design pivots behind each
phase. This is for orientation only — file:line citations rot, so
verify against current code before relying on a specific reference.
The architectural invariants that resulted from this history live in
[architecture.md](./architecture.md); the strict rules in
[CLAUDE.md](../CLAUDE.md).

---

## Phase 1 — Single-app 4th Step Inventory (MVP)
The project began as a standalone Flutter app for the 4th-step
inventory. Data
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

## Phase 17 — Automated store-release tooling
Added a one-command release path, ported from the sibling Life-happens
project and tailored to Flutter:
- `scripts/build-aab.sh` (release AAB + signer check),
  `scripts/upload-aab-to-play.sh` (Google Play Developer API →
  closed-testing "alpha", bilingual notes from `release.md`),
  `scripts/upload-ipa-to-testflight.sh` (macOS-only: App Store IPA →
  TestFlight via `altool`) + `scripts/lib/asc-testflight-notes.mjs` (sets
  the "What to Test" notes via the App Store Connect API — no manual paste).
- A **`deploy-release`** subagent (`.claude/agents/deploy-release.md`) that
  runs the whole thing in two ordered phases (code+docs→`main`, *then*
  deploy), with the version SSOT in `pubspec.yaml` (`X.Y.Z+BUILD` feeds
  versionCode + CFBundleVersion).
- `release.md` (newest-first bilingual notes; top block = the shipped
  release) and `.gitignore` entries for the publishing credentials
  (`play-service-account.json`, `app_sp_pw`, `AuthKey_*.p8`, `asc_issuer`).
  Setup + the "can I just copy the credentials over" answer live in the
  [Store release runbook](./implementation_plan.md). The TestFlight half is
  unverifiable on the (non-Apple) dev box — syntax-checked, run from a Mac.

## Phase 18 — Passive Morning randomizer portability

Extended the existing Morning definition and history models with the additive
fields reserved by the shared recovery contract: `RitualItem` Hive field 11 /
JSON `randomizerSourceId`, plus `RitualItemRecord` Hive fields 5 and 6 / JSON
`selectedContentId` and `selectedContentText`. Missing fields decode as null,
and a present history snapshot requires both ID and text. The generated Hive
adapters write and read the frozen field indices.

No third item type was introduced: `timer=0` and `prayer=1` retain their
released meanings, schema `8.0` and all top-level keys remain unchanged, and
the current runner still shows ordinary `prayerText`. A restore-and-rebuild
test proves the three values survive `BackupRestoreService` and the canonical
`SyncPayloadBuilder` used by JSON, local backup, and Google Drive. Full
bilingual Just for Today selection and display remains deliberately open as
implementation-plan P2.5.

The final compatibility audit also made `randomizerSourceId` a non-blank,
prayer-only value at JSON decode. Editing an imported randomized prayer into a
timer clears that source before the canonical payload is rebuilt, so Twelve
Steps cannot emit a definition that Emotional Sobriety must reject.
Final verification completed with zero analyzer issues, all 15 repository
tests passing, resolved local documentation links, and no Git whitespace
errors.

---

## Phase 19 — Connected fear on Barrier/Power pairs

Adopted the three-field agnosticism shape that Emotional Sobriety uses, so
pairs mean the same thing in both apps and travel intact through the shared
`agnosticism` backup section. `BarrierPowerPair` gained the connecting fear at
Hive field 7 and JSON key `connectedFear`; the form now asks for barrier, fear,
and power, the paper shows the fear under the barrier on the front face, and
the archive card shows it when present.

The stored field is deliberately **nullable** (`storedConnectedFear`) behind a
non-null `connectedFear` getter. A non-nullable field would make the generated
adapter cast `fields[7] as String` and throw on every record written before
this change — and `main.dart` turns a box read failure into delete-and-recreate,
so the throw would have silently wiped real user data. Making the storage
nullable keeps those records readable and their fear empty until the person
edits the pair.

An empty fear therefore means "not recorded yet" rather than invalid. Both
apps preserve it and export it unchanged; neither drops a pair for lacking one.
Six tests cover the released JSON shape, the round trip, an Emotional Sobriety
payload, `copyWith`, and a stored record whose eighth field is absent.

Aligning the field then exposed a larger defect: **the shared JSON was never
importable at all.** Every instant here was written with a bare local
`DateTime.now()` — `2026-08-06T11:38:38.113572`, no zone — while Emotional
Sobriety requires a zoned ISO-8601 value. Agnosticism pairs, Morning
definitions and Morning history were all rejected; only Fourth Step entries,
which carry no instant, got through. The bug survived both apps' test suites
because every cross-app fixture on both sides had been hand-written with
`DateTime.utc(...)`, which no real device ever produces.

`toJson()` now writes `toUtc().toIso8601String()` for `createdAt`,
`archivedAt`, `lastModified`, `startedAt`, and `completedAt`. The ritual
`date` deliberately stays a local calendar day: converting it would move an
early-morning ritual to the previous date. Reading is unchanged —
`DateTime.parse` accepts the zone-less values already on devices, and they are
re-exported zoned. `test/shared_json_parity_test.dart` pins the zone rule, the
local-date exception, and the exact key set of every shared record, and the
Emotional Sobriety fixtures were replaced with payloads captured from this
app's real output. The archive card also gained a `.toLocal()` before
formatting its archived-on date: after a restore the stored instant is UTC,
and a pair archived shortly after local midnight displayed the previous day.

---

## Phase 20 — The return direction: Just for Today, and importing the other app

Phase 18 reserved the randomizer fields and Phase 19 aligned the wire format.
This phase spent them: the Morning runner now actually draws a reading, and a
person can move from Emotional Sobriety to this app instead of only the other
way. Both directions were then proven against files each application's own
builder produced.

**Just for Today (plan P2.5).** A prayer definition may name a reading source
in `randomizerSourceId`. The ten options live in
`assets/content/morning_randomizer_v1.json` with `en` + `da` text and the
stable option IDs Emotional Sobriety froze — the file was generated *from*
that app's Workshop catalog rather than retyped, because `selectedContentId`
and `selectedContentText` are what cross the boundary and a paraphrase would
have made the two apps disagree about what the same day meant. A Danish draw
made here re-resolves in that app's catalog byte-for-byte; the round-trip
check asserts exactly that.

One option is drawn when the day's ritual starts and then held. The draw is
persisted in the device-local draft under a new `randomizerSelections` key, so
resume, *previous* and *start over* all show the same reading — restarting the
ritual must not hand you a different day's intention — and a draft written
before the key existed simply resumes with no draw. Only *missing* draws are
made, which also self-heals a randomized item added mid-day. Completed and
skipped records snapshot the ID and the displayed text; missed days and static
items keep both null.

History re-resolves a known option ID into the currently selected language and
otherwise renders the stored snapshot. That matters for imported history: the
snapshot is what the person actually read and may have been written by the
other app, so it is the fallback, never overridden.

The resume path needed one correction found while writing it: it runs from
`initState`, where reading `Localizations.localeOf(context)` asserts. The draw
moved into the existing post-frame callback.

**Importing an Emotional Sobriety backup (plan P2.6).** That app's file is a
different envelope — `"product": "emotional-sobriety"`, `"version": "1.0"`,
`agnosticismPairs` rather than `agnosticism`. Five sections are mapped and the
rest ignored. Sections this app owns but that product does not are left
*absent* from the translated payload rather than emptied, so importing one adds
its five datasets and keeps this device's gratitude, amends, reflections and
reminders. Acceptance is manual-path-only behind
`allowForeignProduct` plus a dialog naming each dataset and its count; the
automatic Drive path never passes the flag, so hard rule 8 still holds.

The plan claimed the other app's Fourth Step entries carry `order` and
`category` fields "this app does not model". The code says otherwise —
`InventoryEntry` has both, and the parity test already pinned them — so they
are imported rather than dropped. The plan text was wrong, not the code.

**A restore could half-wipe a box.** `_applyPayload` cleared each box and then
decoded records one at a time, so a single unreadable record threw mid-rewrite
and left that box holding a fragment with the rest of the payload never
applied. Every section is now decoded *before* its box is cleared; unreadable
records are skipped and counted in `RestoreCounts.skippedRecords` and surfaced
in the UI. This was reachable before foreign files existed; it is simply much
easier to hit with one.

**Deleting a Morning item broke the whole export.** Emotional Sobriety requires
Morning definitions to carry unique sort orders contiguous from zero, and
refuses the *entire file* over a gap — not just the Morning section. This app
left a hole on every delete, and `reorderRitualItems` renumbered only active
items, so an inactive one could collide. Verified by feeding a gapped payload
to that app's real validator: `FormatException: Morning Ritual item order must
be contiguous from zero`. Delete now compacts the sequence, reorder numbers
inactive items after the active ones, and `migrateSortOrders()` repairs sets
already on disk at startup and after every restore. Idempotent, and a no-op for
a set that is already contiguous.

Imported sets are normalized to this app's own rules rather than trusted or
rejected: active pairs beyond the cap of five are **archived, never dropped**
(they are the person's work, and the other app allows a configurable cap), and
a second randomized reading loses only its source ID and stays an ordinary
prayer, because a backup with two is refused over there.

`MorningRitualService` also stopped caching its boxes in statics. A cached
handle goes stale if a box is ever deleted and recreated — which `main.dart`'s
corruption-recovery path does — and `Hive.box` is only a map lookup.

**Proving it (plan P2.7).** Both fixtures are now captured from the other
side's real output. `test/fixtures/emotional_sobriety_export_1_0.json` came out
of that app's own `SyncPayloadBuilder`, and a realistic export from here —
including a deleted definition, a Danish Just for Today draw and a connected
fear — was fed through that app's real `BackupValidator`, which accepted it and
matched the Danish snapshot text against its own catalog. That closes the
acceptance on both sides; the other repository tracks the same round trip as
its P5.10.

**Then the screens themselves got covered.** The first pass verified the new
behaviour with unit tests and the other app's validator, but the runner, the
editor toggle and the import dialog had none — so P2.5's own acceptance line
("start, resume, previous, complete, skip") was only half met, and neither
bilingual dialog had been seen rendered. Eighteen widget tests now drive the
real screens: a draw appears instead of `prayerText`, *previous* / *start over*
/ resume show the same reading, complete and skip snapshot exactly the text on
screen, a static item snapshots nothing, an unknown source falls back, and a
Danish ritual draws and records Danish. Both dialogs are rendered in English
and Danish, which is what actually proves the layout holds.

Getting there cost a real lesson, now recorded in the area's `CLAUDE.md`: a
`testWidgets` body runs in a **fake-async zone**, and every step of this runner
writes to Hive. Those writes resolve on the real event loop, which the fake
zone never advances, so a plain `tester.tap` leaves a write in flight forever
and Hive's per-box lock deadlocks teardown — the test *hangs* instead of
failing, which is a slow way to learn. Boxes are opened in `setUp` and every
interaction goes through `tester.runAsync`.

The editor test also surfaced a small localization collision: Danish labels
the prayer *type* and the prayer *text field* both "Bøn", so the test cannot
tell them apart by label and counts fields instead. Registered as P3.4b.

75 tests pass, analyzer clean.

**Shipped as 2.3.0+107** to Google Play closed testing ("alpha") and
TestFlight on 2026-08-06 — the first dual-store release from the Mac, which
also closed the long-standing P1.2 credential blocker: the four files are
account/team-scoped, so copying them from the other app's checkout was all
that was needed. App Store Connect accepted the build with warning 90068
(`MinimumOSVersion 13.0`; Apple requires 15.0 from Spring 2027), now tracked
as P1.3.

Verifying that release afterwards turned up something the tooling had always
hidden: **uploading is not distributing.** Build 107 was `VALID` in App Store
Connect and installable by nobody, because the app had never had a TestFlight
beta group — builds 100–106 were all uploaded into the void the same way. An
internal group (*Internal Testing*, `hasAccessToAllBuilds`) now exists, so
every future upload is distributed automatically without a beta review. The
Play side was fine: the alpha track read back `2.3.0` / versionCode 107,
status `completed`, with both locales' notes.

**2.3.1+108** followed the same day, for one reason: 107 had been compiled
before the naming fix, so the binary attached to a listing that disclaims
affiliation still seeded an "I Am" definition naming the fellowship. Same
feature set, built from `main` afterwards. It is on both test tracks, and the
App Store version was renamed 2.3.0 → 2.3.1 so the metadata and the build
match.


---

## Phase 21 — Clearing the backlog, and Android 15 edge-to-edge

One pass over everything on the roadmap that wasn't waiting on a store console,
plus the deprecation Google Play raised against release 106 (2.2.13).

### The Play warning was ours to fix, but not where it pointed

Play flagged `Window.setStatusBarColor`, `setNavigationBarColor` and
`setNavigationBarDividerColor`, all "starting in"
`io.flutter.plugin.platform.PlatformPlugin.setSystemChromeSystemUIOverlayStyle`
— engine code, not ours. Nothing in `lib/` calls `SystemChrome` at all, which
made it look like a Flutter problem to wait out.

It wasn't. The engine only invokes each of those three setters when the
**Dart-side style supplies that colour**. With no
`AppBarTheme.systemOverlayStyle` set, every `AppBar` fell back to
`AppBar._systemOverlayStyleForBrightness`, which fills in a `statusBarColor` —
so Material was handing the engine a colour on every screen. Setting one
`AppBarTheme.systemOverlayStyle` whose three colours are all **null**
([`shared/utils/system_ui.dart`](../lib/shared/utils/system_ui.dart)) removes
every deprecated call while keeping the icon-brightness half of the style,
which travels through `WindowInsetsControllerCompat` and is not deprecated.
`test/edge_to_edge_test.dart` pins both directions, including a negative
control that fails if Flutter's default ever stops filling the colour in.

Since `targetSdk` is already 36, Android 15 **forces** edge-to-edge regardless,
so the second half was making the app actually live with it: five screens
(8th Step, notifications, Data Management, the pair form, the 4th-step settings
tab) had no `SafeArea` and would draw under the gesture bar. All five now inset
their body, matching the five that already did.

### What else landed

- **Dates and calendars follow the language popup.** Every `DateFormat` in the
  app was constructed without a locale, so `Intl.defaultLocale` (en_US) won:
  "August 6, 2026" and "Wednesday" inside Danish screens. All 17 call sites now
  go through [`shared/utils/date_formats.dart`](../lib/shared/utils/date_formats.dart),
  `main.dart` calls `initializeDateFormatting()`, and both `TableCalendar`s get
  a `locale`. The plan named only `yMMMMd`; month, weekday, day and time were
  equally English. The `CalendarFormat` toggle's hardcoded `'Week'`/`'Month'`
  became `calendar_week` / `calendar_month`.
- **`RitualItem.soundId` finally selects a sound.** The editor had offered four
  choices and synced the value for a long time while `_playAlarm` always played
  the system alarm. The mapping lives in
  [`morning_ritual/services/alarm_sound.dart`](../lib/morning_ritual/services/alarm_sound.dart)
  so it is unit-testable; only the alarm choice takes `asAlarm: true`, or the
  quiet option would still ring at alarm volume. An unknown id — which a future
  version of the other app could introduce — falls back to the alarm rather
  than to silence.
- **One default morning window.** 06:00 in `getMorningRitualSettings()`, 05:00
  in its own catch-block, in `importFromSync` and in the settings UI. Now two
  constants on `AppSettingsService`; 05:00–09:00 won, being three of the four.
- **Notifications got help content**, so the button no longer falls through to
  `help_not_available`, and the 8th-step help was wrong rather than merely
  short: it described the columns as a reference to a 4th-Step column when they
  are Yes / No / Maybe *willingness*. Rewritten in both languages, with a third
  section on working the board.
- **Both dead paths are gone.** `EnhancedGoogleDriveService` had no remaining
  references at all. `EighthStepSettingsTab`'s unrouted list UI is deleted and
  `PersonEditDialog` — the only part `EighthStepHome` actually used — moved to
  its own file.
- **The Just for Today catalog is generated, not typed.**
  `tool/regenerate_morning_randomizer.dart` rebuilds it from Emotional
  Sobriety's `workshop_exercises_v1.json`, and it reproduces the checked-in
  asset byte for byte from that app's real file. A test regenerates from a
  fixture captured out of the same file and fails on any drift, so a hand-edit
  can no longer slip through with a user seeing different words in each app.
- **Danish stopped calling two different things "Bøn"** — the prayer *type* and
  the prayer *text* field, in the same dialog. The text field is now
  "Bønnens tekst".

### Two things the new tests found

**A restore could report failure after it had already succeeded.**
`_applyPayload` called `NotificationsService.rescheduleAll()` unguarded, in the
middle of the section sequence. That re-registers reminders with the OS, and it
can fail for reasons that have nothing to do with the backup — permission
revoked, no timezone database, a platform with no plugin implementation. When
it threw, it threw out of `_applyPayload`, so the whole restore returned
`success: false` — with every box up to and including notifications already
rewritten, and `appSettings` never applied. It is now wrapped: the records are
on disk either way, and the worst case is a reminder that re-registers on the
next launch.

**The suite had a one-in-four flake, hidden until there were enough files to
expose it.** `morning_ritual_runner_test`'s "start over" step tapped the
confirmation dialog's button assuming it had been built, relying on `act`'s
fixed 150ms. Adding six test files raised the parallel load enough that the
dialog sometimes wasn't there yet. The step now taps the trigger until the
confirm button exists. Two things worth remembering: a `.last` finder throws
`Bad state: No element` out of `evaluate()` itself, so it cannot be used to ask
"is it there yet?", and a flake that only appears under full-suite concurrency
will not reproduce when you run the file on its own.

**Shipped as 2.3.3+110** to Google Play closed testing ("alpha", versionCode
110, status `completed`, both locales' notes attached) and TestFlight on
2026-08-07, where the App Store Connect API set the en-GB + da "What to Test"
notes automatically. App Store Connect raised no warning this time — 2.3.2's
iOS 15 deployment target settled warning 90068.

### The Play track-precedence gate

Publishing verified everything about the *upload* and nothing about what the
store actually hands out. Play serves a tester the highest-priority track they
belong to — internal → closed → open → production — so a release left active on
`internal` shadows a fresh alpha publish, and when its versionCode is lower Play
can neither update nor downgrade and the Store offers nothing at all. It looks
like a broken package while every check stays green. The sibling app lost hours
to it three times.

`scripts/upload-aab-to-play.sh` now re-reads the tracks after committing (a
committed edit can't be read, so it opens a throwaway edit) and fails with the
offending track and versionCode. `draft` and `halted` releases serve nobody and
are ignored, which is the false positive that matters — an empty draft track
must not block a release. The track is also hard-pinned to closed `alpha`: the
`--track` flag is gone and passing one is an error, so open testing and
production are not reachable from this script at all.

Two things the work turned up:

- `print_track_report` ended on `[ "$found" -eq 0 ] && printf …`, which leaves
  the function's status at 1 whenever the last track *did* have a release —
  and `set -e` then killed the script before the gate ever ran. The audit
  printed a full, reassuring report and exited 1 without checking anything.
- The read-back first matched the version with `grep "versionCode=.*\b110\b"`.
  A substring match on a list of numbers is a trap: `--self-test` now pins that
  `11` does not match `110`, along with draft-vs-active and numeric-vs-string
  versionCodes. Thirteen cases, no network needed.

The one-time audit found `internal` empty, so nothing had to be halted. It also
appeared to find open testing serving versionCode 98 against production's 106 —
which would have been the same defect one tier down. It wasn't: **open testing
is paused**, and the Android Publisher API has no field for that. A paused track
still returns its last release with status `completed`, so an audit cannot tell
a live track from a paused one.

That blind spot is now stated in the script's header and printed after every
audit, because it will otherwise be rediscovered as a false alarm every time.
The gate itself is unaffected — it only ever fails on `internal` — and the audit
now prints each release's Play name (`98 (2.2.6)`, `106 (2.2.13)`) so the state
of a track reads at a glance instead of as a bare number.

### Proving the cross-app transfer, instead of assuming it

`BackupRestoreService` changed this phase, so "is Emotional Sobriety still
compatible?" needed an answer with evidence behind it. Both repositories pinned
the contract with **fixtures** — and their side's Twelve Steps fixture is a
hand-written Dart literal, which is precisely the shape of the mistake the last
cross-app defect exploited: every fixture on both sides was hand-authored with
values no device produces, so both suites stayed green while real transfers
broke.

`scripts/verify-cross-app-recovery.sh` closes that. It runs this side's import
suites, then builds a **live** payload from the real `SyncPayloadBuilder` —
seeded with the awkward cases (Danish text, a pair with an empty connected fear
and one with, an archived pair, a Just for Today draw, contiguous sort orders)
— and feeds it through Emotional Sobriety's **own `BackupValidator`** inside
their checkout, via a throwaway probe test that is always cleaned up. Then it
runs their parity suites. Both directions or nothing: `--peer none` diagnoses
and still exits non-zero, so no run can clear a release having proven one side.
It is now CLAUDE.md hard rule 9, a step in the `deploy-release` gate, and
architecture.md §7.1.

Verified against 2.3.3: their validator accepts this app's live export with all
five shared datasets intact, the empty connected fear preserved as empty rather
than invented or rejected, the archived pair still archived, and the Danish text
intact through UTF-8.

Three of the probe's own assertions were wrong before the contract ever was —
`toString()` on their models returns `Instance of 'InventoryEntry'`, and a
`contains('æ')` check missed text that actually read "Ædru i dag" and "Stille
bøn". Worth remembering when a cross-app check goes red: confirm the assertion
before believing the contract broke.

**Coverage went 75 → 105 tests**: the boxes only this app has now round-trip
through `SyncPayloadBuilder` → `BackupRestoreService`, the two legacy import
aliases and the I-Am-before-entries ordering are pinned, `blockUploads()` and
the deprecated `checkAndSyncIfNeeded()` are guarded, `reorderRitualItems` is
exercised against a real mixed active/inactive set, and both locales are
checked for key parity.


---

## Phase 22 — A finished ritual that never left the phone

Reported as "I completed the morning ritual on my phone, I fetched here, and it
isn't in the history." The desktop was not at fault, and neither was the fetch.

The desktop's boxes had all been rewritten at the time of the fetch, so the
restore ran. Its newest Morning entry was **6 August** and the `settings`
`lastModified` read `2026-08-06T10:32:22Z` — the payload it restored was a day
old. The calendar agreed: dots on the 3rd through 6th, none on the 7th.
`listAvailableBackups()` sorts newest-first by filename date and the fetch takes
`.first`, so it had picked the newest file that existed. At that moment Drive
held no backup containing the ritual.

**The first conclusion was wrong.** The obvious candidate was the upload
debounce: `scheduleUploadFromBox` starts a 1000 ms timer, nothing flushed it
when the app was backgrounded, and no path anywhere pushed when the *local*
clock was ahead — so a dropped upload stayed dropped. All of that was true and
worth fixing, but it was not what happened here. The phone itself said so:

    Synkronisering fejlede: Access was denied (www-authenticate header was:
    Bearer realm="https://accounts.google.com/", error="invalid_token").

Signed in, sync on, and **every** upload failing on a dead token. Its restore
dropdown showed the same newest backup, 2026-08-06.

The upload path does auto-heal an expired token — clear the auth cache, re-mint
via `signInSilently()`, retry once — but only for errors it recognised, and
recognition was an inline substring list built from `DetailedApiRequestError`
messages: `401`, `Invalid Credentials`, `PERMISSION_DENIED` and friends. This
message is `AccessDeniedException` from `googleapis_auth`, a different type
whose `toString()` is the raw www-authenticate text. It contains **none** of
those markers. So the recovery never ran, the raw error was shown instead, and
the credential stayed dead until someone signed out and in by hand.

The classification now lives in
[`drive_auth_errors.dart`](../lib/shared/services/google_drive/drive_auth_errors.dart)
with the real message pinned in a test, alongside `invalid_grant`, revoked and
expired tokens, and the scope variants. It stays deliberately narrow — treating
a 500 or a lost host lookup as an auth problem would burn a refresh on every
transient failure and hide the real fault behind it.

**The two fixes compose into a recovery path.** A dead token also makes the
read side return null, so the remote clock reads as absent; `uploadIfLocalNewer()`
then sees local work with no backup, attempts an upload, and *that* is what now
recognises the dead token and re-mints it. A phone in this state heals itself on
the next launch instead of needing a manual sign-out.

### The debounce gap, fixed on the way past

Still real, still worth having. Both sync directions now read one verdict from
[`sync_clocks.dart`](../lib/shared/services/sync_clocks.dart) —
`isRemoteNewer()` is `verdict.shouldBlockUploads`, `uploadIfLocalNewer()` is
`verdict.shouldCatchUpUpload` — so they cannot disagree about which side is
ahead. `flushPendingUpload()` runs when the app leaves the foreground, and the
startup push is the backstop that survives the process being killed outright.
The asymmetry is deliberate: restoring overwrites local data and needs consent
(hard rule 8), while uploading only ever writes a new timestamped backup and can
destroy nothing.

Nothing was lost. The ritual was on the phone the whole time.

**Shipped as 2.3.4+111** to Google Play closed testing ("alpha", versionCode
111, read back as served) and TestFlight on 2026-08-07.

**It does not reach the people already using the app.** Production still serves
**versionCode 106 (2.2.13)** — the build Google flagged for edge-to-edge, and a
build with the dead-token defect in it. Anyone on the public listing keeps
failing to sync silently until a production rollout happens, which is a
deliberate human decision and one this tooling cannot make: the publish script
is hard-pinned to `alpha` and has no `--track` flag.

### Lesson

Two plausible causes, and the evidence for the first one was entirely
circumstantial — "the upload didn't happen" is a symptom shared by both. The
error text on the device settled it in one line, and it had been sitting on the
user's screen the whole time. Ask for the device's own error before reasoning
about which code path could have dropped a write.


---

## Phase 23 — Saying what the app actually does, and never naming the fellowship

Two instructions, one pass: descriptions must be simple and true to the
functionality, and the fellowship is never named — "not AA, not Alcoholics
Anonymous, no flavours of it".

**The obvious spellings were already gone; the citations were not.** Every
`AA` / `Alcoholics Anonymous` had been scrubbed from user-visible strings in an
earlier phase, which is exactly why the remaining breaches survived: they named
the fellowship by quoting **its book**. Four help sections cited "The Big Book
(p.86)" / "Den Store Bog (s.86-88)" with page numbers, and one told the user its
categories "align with Big Book guidance". Naming the literature identifies the
fellowship as surely as the initials do.

Worse, and entirely public: **`PRIVACY_POLICY.md`** — the document both store
pages link to — opened with "a comprehensive recovery toolkit designed for the
AA (Alcoholics Anonymous) program". `README.md` cited "the Big Book method". The
scrub had covered `lib/`, and stopped there.

**The help content was also wrong about the app.** Rewriting it to remove the
citations meant reading what each screen actually does, and the two did not
match:

- 4th Step help described only the *resentment* field labels and never mentioned
  that there are four categories whose labels change.
- Agnosticism help was written entirely as surrender to God — "Not given to
  god", "God-given corrective attitude" — in a tool named *Agnosticism*, and it
  never mentioned the **connected fear**, which is one of the three fields on
  the paper.
- Morning Ritual help listed timers and prayers but not the Just for Today
  reading, the per-item sound, or that history records what you were given.
- Evening Ritual's section was titled "The Ten Categories" and listed five.
- Four help titles named tools differently from the app's own switcher
  (`Gratitude Journal`, `Agnosticism Papers`, `8th Step Amends List`).

All of it is rewritten in both languages: plain, specific, describing fields,
limits and buttons that exist. The Danish 8th-Step purpose also had an
unbalanced quotation mark that had been shipping.

**Enforced, not just fixed.** `test/naming_rule_test.dart` scans every `en` and
`da` string, the bundled assets, the store listing copy and the privacy policy
for the initials, both full names, the sibling fellowship and the book in both
languages — and includes a regression case asserting the guard would have caught
each phrasing that actually shipped, plus a case asserting ordinary recovery
language ("sponsor", "moral inventory", "higher power") still passes. The
word-boundary anchoring matters: an earlier grep of mine matched "an" and "away"
and produced three false positives before it was tightened.

**Names, again — and the App Store was worse than it looked.** The Play title
was corrected to "12 Steps App". On the App Store, reading the record rather
than assuming turned up three names for one app:

| appInfo | state | name |
|---|---|---|
| live | `READY_FOR_SALE` (`da` only) | `Twelve step app` |
| staged | `PREPARE_FOR_SUBMISSION` (`da`, `en-GB`) | `12 Steps App - Recovery` |
| binary | — | `12 Steps App` |

"- Recovery" was **staged, never live**: it would have shipped with the next
submission. Both staged localizations are now "12 Steps App", read back to
verify. Apple freezes a live version's name, so the public record still says
"Twelve step app" until the next submission carries the correction — reported by
the tool rather than silently ignored.

`scripts/fix-appstore-name.sh` does the check and the fix, and reports rather
than guesses when a live appInfo blocks the write.

**And a fourth name, found by looking at the running app.** The macOS window
title was built from the *system* locale — "Twelve Steps app" or "Tolv Trins
app" — so a Danish UI could sit under an English title, and neither matched the
launcher. All Dart references now come from `appDisplayName`, and the guard test
checks `android:label`, `CFBundleDisplayName`, every store listing title in the
doc, and that no Dart file hardcodes a rival. Desktop is not distributed, so
this one never reached a store. The rule now sits in
`CLAUDE.md` beside localization: the app's name is not a translatable string.

**Shipped as 2.3.5+112** to Google Play closed testing ("alpha", versionCode 112,
read back as served) and TestFlight on 2026-08-07, so the pending App Store
submission now carries both the corrected name and the rewritten help.


### Danish store page, English release notes

Checking App Store Connect before submitting found the version's **What's New**
was never written by anything: the `da` locale carried the **English** notes and
`en-GB` carried **none at all**, under two correctly localized descriptions. The
TestFlight script writes `betaBuildLocalizations` ("What to Test"); nobody wrote
`appStoreVersionLocalizations.whatsNew`, which is what the public reads. It
drifted silently because no upload output ever mentions it.

`scripts/set-appstore-release-notes.sh` now writes it from `release.md`'s top
block — the same source Play and TestFlight already use — refuses to run when
that block does not match `pubspec.yaml`, and reads every locale back to verify.
`scripts/appstore-status.sh` prints the whole picture read-only, including the
**build attached to the pending version**, which is not visible anywhere else:
that version was sitting on build 108 while TestFlight had 112.

### "Just for Today" is the name, in both languages

It was being translated to "Kun for i dag" in the Danish UI, help, release notes
and store copy. It is the reading's name, not a phrase — it stays English in
Danish, like the app's own name. Corrected in the four in-app strings, the
pending release notes and the store copy; the catalog asset keeps the upstream
`da` title because it is generated and unused by this app's UI. Already-shipped
release notes are left as they shipped.

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
