#!/usr/bin/env bash
# upload-ipa-to-testflight.sh — build a distribution-signed iOS .ipa and upload
# it to App Store Connect → TestFlight. The Apple sibling of
# scripts/upload-aab-to-play.sh (Android → Play closed testing). Mac-only.
#
# What it does, end to end:
#   1. Builds (or reuses) an App Store .ipa (flutter build ipa --release — the
#      default export method is app-store, i.e. a DISTRIBUTION-signed binary; a
#      development export is HTTP-409-rejected, so the script verifies the signer
#      before uploading).
#   2. Confirms the .ipa is signed "Apple Distribution: … (TEAMID)".
#   3. Uploads via `xcrun altool --upload-app` using the Apple ID + the
#      app-specific password in the git-ignored ./app_sp_pw.
#   4. Sets the en-GB + da-DK "What to Test" notes from release.md on the build —
#      AUTOMATICALLY via the App Store Connect API when a .p8 key is present
#      (scripts/lib/asc-testflight-notes.mjs; altool's password auth can't set
#      per-build localized notes), else prints them for a one-time manual paste.
#
# Version: pubspec.yaml `version: X.Y.Z+BUILD` → Flutter sets
# CFBundleShortVersionString=X.Y.Z (marketing) and CFBundleVersion=BUILD. App
# Store Connect dedupes / matches builds on **CFBundleVersion (BUILD)**, so each
# upload needs a strictly higher +BUILD than the last within the same X.Y.Z —
# bump it in pubspec.yaml first.
#
# Auth: the Apple Developer Apple ID (default kasper@stormstyrken.dk — override
# with --apple-id / $APPLE_ID) and its **app-specific password** in ./app_sp_pw
# (git-ignored; create at appleid.apple.com → Sign-In & Security → App-Specific
# Passwords).
#
# Auto-notes (no manual paste) — ONE-TIME setup, the only manual step Apple needs:
#   App Store Connect → Users and Access → Integrations → App Store Connect API →
#   generate a Team key (role "App Manager"). Download AuthKey_<KEYID>.p8 (once),
#   and note the Key ID + Issuer ID. Then either drop the file + ids at the repo
#   root — ./AuthKey_<KEYID>.p8 (the Key ID is the filename) + ./asc_issuer (the
#   Issuer ID), both git-ignored — and the script auto-detects them, or pass
#   --asc-key/--asc-key-id/--asc-issuer (or ASC_KEY/ASC_KEY_ID/ASC_ISSUER_ID env).
#   After that EVERY release sets its TestFlight notes with zero manual action.
#
# Flags:
#   --build            (re)build the .ipa first (App Store export)
#   --ipa <path>       upload a specific .ipa instead of building/auto-finding
#   --apple-id <id>    override the Apple ID (or $APPLE_ID)
#   --asc-key <p8>     App Store Connect API .p8 key (auto-detected at repo root)
#   --asc-key-id <id>  the key's Key ID (default: the AuthKey_<KEYID>.p8 filename)
#   --asc-issuer <id>  the Issuer ID (default: ./asc_issuer)
#   --dry-run          build + verify the signer + show the notes; DON'T upload
#   -h | --help
set -uo pipefail

if [[ -t 1 ]]; then b=$'\033[1m'; r=$'\033[0m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; else b= r= G= Y= R= C=; fi
say()  { printf "%s→%s %s\n" "$C" "$r" "$*"; }
ok()   { printf "%s✓%s %s\n" "$G" "$r" "$*"; }
warn() { printf "%s!%s %s\n" "$Y" "$r" "$*"; }
err()  { printf "%s✗%s %s\n" "$R" "$r" "$*" >&2; }
hdr()  { printf "\n%s%s%s\n%s\n" "$b$C" "$*" "$r" "────────────────────────────────────────────────────────────"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="dk.stormstyrken.twelvestepsapp"
APPLE_ID="${APPLE_ID:-kasper@stormstyrken.dk}"
DO_BUILD=0; DRY=0; IPA=""
ASC_KEY="${ASC_KEY:-}"; ASC_KEY_ID="${ASC_KEY_ID:-}"; ASC_ISSUER="${ASC_ISSUER_ID:-}"
while (($#)); do case "$1" in
  --build)      DO_BUILD=1 ;;
  --ipa)        shift; IPA="${1:?--ipa needs a path}" ;;
  --apple-id)   shift; APPLE_ID="${1:?--apple-id needs a value}" ;;
  --asc-key)    shift; ASC_KEY="${1:?--asc-key needs a .p8 path}" ;;
  --asc-key-id) shift; ASC_KEY_ID="${1:?--asc-key-id needs a value}" ;;
  --asc-issuer) shift; ASC_ISSUER="${1:?--asc-issuer needs a value}" ;;
  --dry-run)    DRY=1 ;;
  -h|--help)    sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) err "unknown flag: $1"; exit 2 ;;
esac; shift; done

# Auto-detect the App Store Connect API key so TestFlight notes get set with NO
# manual paste: a single ./AuthKey_<KEYID>.p8 at the repo root (the Key ID IS the
# filename) + the Issuer ID in ./asc_issuer (both git-ignored). Flags/env override.
[[ -z "$ASC_KEY" ]] && ASC_KEY="$(ls "$ROOT"/AuthKey_*.p8 2>/dev/null | head -1)"
[[ -n "$ASC_KEY" && -z "$ASC_KEY_ID" ]] && ASC_KEY_ID="$(basename "$ASC_KEY" | sed -E 's/^AuthKey_(.+)\.p8$/\1/')"
[[ -z "$ASC_ISSUER" && -f "$ROOT/asc_issuer" ]] && ASC_ISSUER="$(tr -d ' \n\r' < "$ROOT/asc_issuer")"
ASC_READY=0; [[ -n "$ASC_KEY" && -n "$ASC_KEY_ID" && -n "$ASC_ISSUER" ]] && ASC_READY=1

# macOS-only past this point (the iOS build + altool need Xcode). Checked after
# arg-parsing so --help works on any platform.
[[ "$(uname -s)" == "Darwin" ]] || { err "TestFlight upload is macOS-only (needs Xcode)."; exit 1; }

# ─── Pre-flight ──────────────────────────────────────────────────────────────
hdr "Pre-flight"
command -v xcrun >/dev/null || { err "xcrun (Xcode CLT) not found"; exit 1; }
command -v flutter >/dev/null || { err "flutter not on PATH"; exit 1; }
PW_FILE="$ROOT/app_sp_pw"
[[ -f "$PW_FILE" ]] || { err "app-specific password missing at ./app_sp_pw (git-ignored). Create one at appleid.apple.com → Sign-In & Security → App-Specific Passwords."; exit 1; }
APP_PW="$(tr -d ' \n\r' < "$PW_FILE")"
[[ -n "$APP_PW" ]] || { err "./app_sp_pw is empty"; exit 1; }
ok "Apple ID: $APPLE_ID  ·  app-specific password: present"

VERSION_LINE="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')"
VERSION="${VERSION_LINE%%+*}"        # 2.2.13 — CFBundleShortVersionString (marketing)
BUILD_NUMBER="${VERSION_LINE##*+}"   # 106   — CFBundleVersion (what ASC matches on)
say "marketing version $VERSION  ·  build (CFBundleVersion) $BUILD_NUMBER"

# ─── Build the App Store .ipa (or reuse) ─────────────────────────────────────
if [[ -z "$IPA" && ( $DO_BUILD -eq 1 || -z "$(ls "$ROOT"/build/ios/ipa/*.ipa 2>/dev/null | head -1)" ) ]]; then
  hdr "Build App Store .ipa"
  say "flutter build ipa --release"
  flutter build ipa --release || { err "iOS App Store build failed (check Xcode signing: a Distribution cert + the team for $BUNDLE_ID)."; exit 1; }
fi
[[ -z "$IPA" ]] && IPA="$(ls -t "$ROOT"/build/ios/ipa/*.ipa 2>/dev/null | head -1)"
[[ -n "$IPA" && -f "$IPA" ]] || { err "no .ipa under build/ios/ipa — run with --build"; exit 1; }
ok "IPA: $IPA ($(du -h "$IPA" | cut -f1))"

# ─── Verify it's DISTRIBUTION-signed (the #1 cause of a 409 rejection) ───────
hdr "Verify distribution signing"
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
unzip -q "$IPA" -d "$d" || { err "could not unzip the .ipa"; exit 1; }
APP_DIR="$(ls -d "$d"/Payload/*.app 2>/dev/null | head -1)"
[[ -n "$APP_DIR" ]] || { err "no .app inside the .ipa's Payload"; exit 1; }
AUTH="$(codesign -dvvv "$APP_DIR" 2>&1 | grep -E "Authority=Apple (Distribution|Development)" | head -1)"
say "signer: ${AUTH#Authority=}"
if echo "$AUTH" | grep -q "Apple Distribution"; then
  ok "Apple Distribution signed — uploadable"
else
  err "NOT distribution-signed (got: ${AUTH:-none}). Rebuild as an App Store export (Xcode → automatic signing with a Distribution cert)."
  exit 1
fi

# ─── Release notes for the TestFlight "What to Test" field ───────────────────
hdr "Release notes (for TestFlight → What to Test)"
notes_block() { # $1 = tag (en-GB | da-DK) — inner text of the FIRST block in release.md
  awk -v tag="$1" '
    $0=="<" tag ">"  {grab=1; next}
    $0=="</" tag ">" {if(grab) exit}
    grab {print}
  ' release.md
}
EN="$(notes_block 'en-GB')"; DA="$(notes_block 'da-DK')"
if [[ -n "$EN" ]]; then printf "%sen-GB:%s\n%s\n\n%sda-DK:%s\n%s\n" "$b" "$r" "$EN" "$b" "$r" "$DA"; else warn "no release.md block found — add one (newest-first, <en-GB>/<da-DK>)"; fi
if ((ASC_READY)); then
  ok "App Store Connect API key found (key ${ASC_KEY_ID}) — notes will be set automatically after the upload."
else
  warn "No App Store Connect API key — paste the above into App Store Connect → TestFlight → this build → Test Details. To make it automatic next time, drop AuthKey_<KEYID>.p8 + an asc_issuer file at the repo root (one-time; see scripts/lib/asc-testflight-notes.mjs)."
fi

# ─── Upload ──────────────────────────────────────────────────────────────────
if ((DRY)); then
  hdr "Dry run"
  ok "Built + verified distribution-signed + notes shown. Nothing uploaded."
  exit 0
fi
hdr "Upload to App Store Connect (TestFlight)"
say "xcrun altool --upload-app -t ios -f \"$IPA\" -u $APPLE_ID"
if xcrun altool --upload-app -t ios -f "$IPA" -u "$APPLE_ID" -p "$APP_PW"; then
  ok "Uploaded. Apple processes the build (a few minutes), then it appears in App Store Connect → TestFlight."
  say "Add testers / a group there."
  # Auto-set the localized "What to Test" notes via the App Store Connect API
  # (altool's password auth can't). The helper JWT-signs with the .p8 key, polls
  # for the build (matched on CFBundleVersion = $BUILD_NUMBER) to register, then
  # upserts the en-GB + da-DK whatsNew. No paste.
  if ((ASC_READY)); then
    hdr "Set TestFlight notes (App Store Connect API — no manual paste)"
    if command -v node >/dev/null && command -v jq >/dev/null; then
      if ASC_KEY="$ASC_KEY" ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER" \
         ASC_BUNDLE_ID="$BUNDLE_ID" ASC_BUILD_VERSION="$BUILD_NUMBER" \
         ASC_NOTES_JSON="$(jq -n --arg en "$EN" --arg da "$DA" '{"en-GB":$en,"da-DK":$da}')" \
         node "$ROOT/scripts/lib/asc-testflight-notes.mjs"; then
        ok "TestFlight 'What to Test' notes set automatically — nothing to paste."
      else
        warn "auto-setting TestFlight notes failed — paste them manually (shown above)."
      fi
    else
      warn "need 'node' + 'jq' on PATH to auto-set notes — paste them manually (shown above)."
    fi
  fi
else
  err "altool upload failed (a 409 = wrong export method or a duplicate CFBundleVersion — bump the +BUILD in pubspec.yaml and rebuild)."
  exit 1
fi
