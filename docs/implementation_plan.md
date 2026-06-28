# Implementation Plan

What's next, in priority order. Each item is sized so a single focused
PR can land it, and carries the *why* so we don't re-litigate it later.
New work starts here: if a task isn't on this list and isn't an obvious
bug fix, add it (with rationale) before opening a branch. When a task
lands, move its story to
[historic_implementation.md](./historic_implementation.md) and delete
it here.

The **Release & environment runbooks** at the bottom are standing
reference procedures (desktop OAuth setup, iOS release), not roadmap
items — but the release items in P1 depend on them.

---

## P1 — Blocking a real public release

### P1.1 Confirm `desktop_oauth_config.dart` is not committed
`lib/shared/services/google_drive/desktop_oauth_config.dart` holds a
hardcoded desktop OAuth client id **and secret**. Its header says the
file is gitignored, but it is present in the working tree. Verify it is
actually ignored (only the `.template` should be tracked); if it was
ever committed, rotate the credential and scrub history.

**Why now:** a leaked secret in a public repo is a one-way door, even
though desktop OAuth secrets are "app-identifying" rather than truly
secret.

---

## P2 — Half-implemented behaviour the code already hints at

### P2.1 Honour per-item alarm sound in Morning Ritual
`RitualItem.soundId` is persisted and synced (values `null` /
`system_default_notification` / `system_default_alarm` /
`system_default_ringtone`), but `_playAlarm` in
[morning_ritual_today_tab.dart](../lib/morning_ritual/pages/morning_ritual_today_tab.dart)
always plays the system alarm sound. Wire `soundId` into the
`FlutterRingtonePlayer` call so the dropdown actually does something.

**Why:** the setting is exposed in the UI and round-trips through sync,
so users can set a value that is silently ignored.

### P2.2 Add Notifications (and complete 8th-step) help content
[`AppHelpService`](../lib/shared/services/app_help_service.dart) has no
case for `notifications`, so its help button falls through to the
generic `help_not_available`. Add localized help sections (EN + DA) for
notifications, and verify the 8th-step content is complete.

### P2.3 Pick one canonical Morning Ritual default window
`AppSettingsService.getMorningRitualSettings()` defaults to
**06:00–09:00** when keys are absent, but its catch-block fallback,
`importFromSync`, and the General Settings UI default to **05:00–09:00**.
Choose one and use it everywhere so a user with no saved window sees a
consistent value.

### P2.4 No real Morning Ritual alarm sound on desktop
`flutter_ringtone_player` (4.0.0+x) declares **android + ios platforms
only**, so on Linux/macOS/Windows the timer-end `_playAlarm` throws
`MissingPluginException` and falls through to a single
`SystemSound.play(SystemSoundType.alert)` — which on Linux is typically
silent. The per-item sound toggle therefore does nothing on desktop.
Either wire a desktop-capable player (e.g. `audioplayers` / `just_audio`
with a short bundled alarm asset) gated by `PlatformHelper.isDesktop`, or
surface the limitation in the UI. *(Found while fixing the alarm
cut-off; the cut-off itself — a hardcoded 2s force-stop — is already
fixed.)*

**Why:** the timer is usable on desktop, so a user expecting the alarm
to ring at the end of a meditation gets nothing.

---

## P3 — Engineering polish

### P3.1 Retire or document the dead code paths
Two paths the active flow no longer uses:
- `EnhancedGoogleDriveService` (single-file upsert + no-op
  `checkForConflicts`) — the live flow is `AllAppsDriveService` →
  Mobile/Windows services with dated multi-file backups.
- `EighthStepSettingsTab`'s list UI — `EighthStepHome` imports the file
  only to reuse `PersonEditDialog`; the list view isn't routed.

Delete them, or add a comment marking them intentionally retained.
Either way, kill the ambiguity.

### P3.2 Fix the stale source comments
The `AllAppsDriveService` class comment says it "syncs all 5 apps"
(it's six tools + notifications), and the `BarrierPowerPair` header
comment claims it reuses typeId 9 (typeId 9 is now `RitualItemType`).
Stale comments are how the next agent re-introduces a typeId clash —
correct them.

### P3.3 Round-trip and conflict regression tests
Only [test/morning_ritual_progress_test.dart](../test/morning_ritual_progress_test.dart)
exists. Add tests for:
- `SyncPayloadBuilder.buildPayload` → `BackupRestoreService` round-trip
  for every box, including the `gratitudeEntries` / `agnosticismPapers`
  legacy import aliases and the I-Am-before-entries ordering.
- `isRemoteNewer()` → `blockUploads()` so the "never auto-overwrite
  local data" invariant can't regress silently.

---

## Deferred (intentionally not on the roadmap)

- **Web platform.** Removed deliberately; sync has no web auth path.
  Not coming back.
- **Firebase / a real backend, or full Drive scope.** Permanent
  exclusions — the whole sync model is one JSON file in the user's own
  `drive.appdata`. See
  [historic_implementation.md](./historic_implementation.md).
- **Auto-restore on launch.** `checkAndSyncIfNeeded()` is deprecated
  and returns false on purpose. Cross-device transfer stays an explicit
  user *Fetch*; we never silently overwrite local data.
- **Exact alarms for notifications.** `schedule()` uses
  `inexactAllowWhileIdle` by design — the app isn't an alarm clock and
  `SCHEDULE_EXACT_ALARM` needs a Play Store declaration. Revisit only
  if reminder timing accuracy becomes a real complaint.
- **More than EN/DA locales.** Only English and Danish are populated;
  adding a locale means filling the entire `localizations.dart` table.

---

## Release & environment runbooks

Standing procedures. They change only when the platform tooling or
OAuth configuration changes.

### Store release runbook (Google Play + TestFlight)

Releases are automated by `scripts/` + the **`deploy-release`** agent
(`.claude/agents/deploy-release.md`). The agent runs two ordered phases:
**A)** bump `pubspec.yaml` `version: X.Y.Z+BUILD`, write the bilingual
notes in `release.md` (top block = the shipped release), update docs, run
`flutter analyze`/`flutter test`, commit + push `main`; then **B)** deploy
— Android/Play on every host, iOS/TestFlight on macOS only.

**Version SSOT.** `pubspec.yaml` `version: X.Y.Z+BUILD` feeds *both*
stores: Flutter maps `X.Y.Z`→versionName/CFBundleShortVersionString and
`BUILD`→versionCode/CFBundleVersion. Both stores dedupe on `BUILD`, so it
must strictly increase each upload (patch release: `2.2.13+106` →
`2.2.14+107`). No `build.gradle.kts` / `Info.plist` edits needed.

**The scripts:**
- `scripts/build-aab.sh` — `flutter build appbundle --release`; verifies
  the signer is the release key (not the debug fallback).
- `scripts/upload-aab-to-play.sh [--dry-run|--yes]` — drives the Google
  Play Developer API (`edits.insert → bundles.upload → tracks.update →
  edits.commit`) to the **alpha** (Closed testing) track, attaching the
  en-GB + da-DK notes from `release.md` (≤ 500 chars/locale enforced).
- `scripts/upload-ipa-to-testflight.sh --build` — *macOS only*; builds the
  App Store IPA, verifies it's `Apple Distribution`-signed, uploads via
  `altool`, then sets the TestFlight "What to Test" notes automatically via
  the App Store Connect API (`scripts/lib/asc-testflight-notes.mjs`).

**Local-only credential files (all git-ignored — see `.gitignore`):**

| File | Store | What it is | Scope |
|---|---|---|---|
| `play-service-account.json` | Play | Google Cloud service-account key, Android Publisher API | Per Play developer account (covers all apps it's granted) |
| `app_sp_pw` | Apple | Apple ID app-specific password (for `altool`) | Per **Apple ID** — works for every app |
| `AuthKey_<KEYID>.p8` + `asc_issuer` | Apple | App Store Connect API key (App Manager) + Issuer ID | Per **team** — works for every app in the team |

Android release signing reuses the existing `android/key.properties` +
keystore (already git-ignored).

#### Bringing the credentials over from another app (what the user asked)

These credentials are **account/team-scoped, not app-scoped**, so you can
**copy the files over** — with a couple of one-time console steps:

- **Play — `play-service-account.json`:** copy it. Then in **Play Console
  → Users & permissions** confirm that service account (its
  `client_email`) has access to *this* app with **"Release to testing
  tracks."** An account-level invitation already covers every app; only if
  it was granted app-by-app do you add this app. **One extra one-time
  step for a brand-new app:** Play refuses the *first* bundle over the API
  — upload one AAB by hand in the Console once (Testing → Closed testing →
  Create release), after which the script handles every release. The app
  listing must exist for package `dk.stormstyrken.twelvestepsapp`.
- **Apple — `app_sp_pw`:** copy it; an app-specific password authorises
  the whole Apple ID, nothing per-app to do. The app must exist as a
  record in **App Store Connect** for bundle id
  `dk.stormstyrken.twelvestepsapp` (create it once if it doesn't).
- **Apple — `AuthKey_<KEYID>.p8` + `asc_issuer`:** copy them; the API key
  is a **team** key (role App Manager), valid for every app in the team —
  no per-app setup. Without these the IPA still uploads; only the
  auto-notes fall back to a manual paste.
- **Xcode signing (macOS):** the team that owns the API key must also own
  the app record; automatic signing in Xcode (Runner → Signing &
  Capabilities → your Team) mints the Distribution cert/profile.

**Locale caveat.** The scripts send release notes for `en-GB` + `da-DK`
(matching the developer's other app). Confirm the Play listing and the App
Store record actually have those languages; if your Play listing's default
is e.g. `en-US`, change the locale strings in `upload-aab-to-play.sh`
(the `releaseNotes` array) or the API rejects the unknown locale.

> **Not testable on this (non-Apple) machine.** The TestFlight script is
> macOS/Xcode-only; it's syntax-checked here and meant to be run from a
> Mac. The Android path runs on any host.

### Desktop OAuth setup runbook

OAuth for **desktop platforms only** (Windows / macOS / Linux). Mobile
is already configured:
- **Android** — configured via SHA-1 fingerprint + package name. No code
  changes; register your debug SHA-1 in Google Cloud Console (see
  [LOCAL_SETUP.md](./LOCAL_SETUP.md)).
- **iOS** — configured via the iOS client ID in
  [mobile_google_auth_service.dart](../lib/shared/services/google_drive/mobile_google_auth_service.dart)
  and `ios/Runner/Info.plist`. No code changes.

Desktop uses the **loopback-IP** OAuth method (a local HTTP server on
`127.0.0.1` receives the callback — see the flow and rationale in
[architecture.md §4.2](./architecture.md#42-desktop-windows--macos--linux--loopback-oauth)).
Custom URI schemes are not supported for desktop apps, so loopback is
required.

1. **Create an OAuth client ID.** Google Cloud Console → APIs &
   Services → Credentials → *Create Credentials* → *OAuth client ID* →
   Application type **Desktop app** → name it (e.g. "12 Steps App -
   Desktop") → Create. You get a Client ID
   (`...-....apps.googleusercontent.com`) and a Client Secret
   (`GOCSPX-...`).
2. **Enable the Drive API.** APIs & Services → Library → search "Google
   Drive API" → Enable.
3. **Add credentials to the app.** Copy the template, then fill it in:
   ```bash
   cp lib/shared/services/google_drive/desktop_oauth_config.dart.template \
      lib/shared/services/google_drive/desktop_oauth_config.dart
   ```
   Set `desktopOAuthClientId` and `desktopOAuthClientSecret` to your
   values. `desktop_oauth_config.dart` is gitignored; only the
   `.template` is tracked (see P1.2).
4. **Test.** `flutter run -d windows` → Data Management → "Sign in to
   Google" → the browser opens, you authorize, it shows "Sign-in
   Successful!", and the app returns signed in.

**Security notes.** For desktop apps the client ID + secret *identify*
the app (they are not server-grade secrets). The local server binds
only to `127.0.0.1` (not network-reachable) and stops immediately after
the callback. Refresh tokens are cached locally (Hive
`windows_google_credentials`) for silent re-auth.

**Troubleshooting.**
- *"Invalid client"* — wrong client ID/secret, or the client wasn't
  created as a **Desktop app**. Re-copy both values.
- *"Access blocked"* — the Drive API isn't enabled (step 2).
- *"redirect_uri_mismatch"* — you created a "Web application" client
  instead of "Desktop app"; desktop clients auto-allow loopback
  redirects.
- *Browser doesn't open* — no default browser / `url_launcher` issue.
  Set a default browser; try running as administrator.
- *Port already in use* — extremely rare with random port selection;
  sign in again and a different port is used.

### iOS release runbook

**Prerequisites:** an Apple Developer account ($99/yr), an App Store
Connect app record, and Xcode on macOS.

1. **Bundle identifier.** Already set to `dk.stormstyrken.twelvestepsapp`
   (the Flutter default is `com.example.twelvestepsapp`). If you ever
   change it again:
   - *Xcode (recommended):* open `ios/Runner.xcworkspace` (not
     `.xcodeproj`) → Runner → Signing & Capabilities → set Bundle
     Identifier (e.g. `dk.stormstyrken.twelvestepsapp`), select your
     Team; Xcode auto-manages signing.
   - *CLI:* edit `ios/Runner.xcodeproj/project.pbxproj`, update every
     `PRODUCT_BUNDLE_IDENTIFIER`.
2. **Re-point the iOS OAuth client (critical when the bundle ID
   changes).** Google Cloud Console
   (`console.cloud.google.com/apis/credentials?project=mobile-app-drive-sync`)
   → find the iOS OAuth client
   `628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k` → update its Bundle
   ID → Save. Then update the URL scheme in `Info.plist`:
   `com.googleusercontent.apps.<ios-client-id-without-.apps.googleusercontent.com>`
   — for the client above that is
   `com.googleusercontent.apps.628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k`.
3. **Display name, icons, version.**
   - `CFBundleDisplayName` in `ios/Runner/Info.plist` → "12 Steps App".
   - Icons are generated by `flutter_launcher_icons` into
     `ios/Runner/Assets.xcassets/AppIcon.appiconset/` from `icon.png` at
     the project root.
   - Version lives in `pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`);
     increment with `dart scripts/increment_version.dart`.
4. **Build the IPA.**
   - *Flutter (recommended):* `dart scripts/increment_version.dart`
     then `flutter build ipa --release` → output
     `build/ios/ipa/twelvestepsapp.ipa`.
   - *Xcode:* open the workspace, destination "Any iOS Device (arm64)",
     Product → Archive, then Distribute App → App Store Connect.
5. **Upload.** Via Xcode Organizer (Distribute App → App Store Connect →
   automatic signing), or Transporter (install it from the Mac
   App Store, open the `.ipa`, Deliver), or CLI:
   ```bash
   xcrun notarytool submit build/ios/ipa/twelvestepsapp.ipa \
     --apple-id "you@email.com" --password "app-specific-password" \
     --team-id "YOUR_TEAM_ID"
   # (legacy: xcrun altool --upload-app --type ios --file ... )
   ```
6. **Submit for review.** App Store Connect → your app → new version →
   fill metadata (description, keywords, screenshots for all device
   types, Privacy Policy URL, Support URL) → select the uploaded build →
   Submit.

**Pre-submit checklist:** bundle ID changed · iOS OAuth client updated ·
`Info.plist` URL scheme updated · code signing configured · display name
set · version incremented · tested on a real device · Google Sign-In
verified · Drive sync verified · all features tested · screenshots ready ·
Privacy Policy URL ready · Support URL ready.

**Current configuration:** Bundle ID `dk.stormstyrken.twelvestepsapp` ·
display name "12 Steps App" · iOS OAuth client
`628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k.apps.googleusercontent.com`
· URL scheme
`com.googleusercontent.apps.628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k`
· version: see `pubspec.yaml`. (Bundle ID and display name are already
set; the steps above apply only if you change them again.)

**Troubleshooting.**
- *"No identity found"* — configure code signing in Xcode with your
  Apple Developer account.
- *"Bundle identifier mismatch"* — Xcode bundle ID must match App Store
  Connect.
- *"Missing iOS Distribution certificate"* — create one in the Apple
  Developer portal (Certificates, IDs & Profiles).
- *Google Sign-In stops working after a bundle-ID change* — update the
  iOS OAuth client and the `Info.plist` URL scheme (step 2).
- *"Version already exists"* — bump with
  `dart scripts/increment_version.dart` (or edit `pubspec.yaml`).

**References:**
[Flutter iOS deployment](https://docs.flutter.dev/deployment/ios) ·
[Apple Developer](https://developer.apple.com) ·
[App Store Connect](https://appstoreconnect.apple.com) ·
[Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
</content>
