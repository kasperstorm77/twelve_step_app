#!/usr/bin/env bash
# upload-aab-to-play.sh — push an already-built release AAB to a Google Play
# closed-testing track, with bilingual (en-GB + da-DK) release notes lifted
# straight from release.md.
#
# It drives the Google Play Developer API (Android Publisher v3 `edits`
# transaction — https://developers.google.com/android-publisher):
#
#   edits.insert → bundles.upload → tracks.update → edits.commit
#
# Release notes: the FIRST version block in release.md is the one being shipped.
# Its <en-GB>…</en-GB> and <da-DK>…</da-DK> bodies map 1:1 onto Play's `language`
# codes, so they go straight into the API's releaseNotes array (Play caps each
# locale at 500 characters — checked up front).
#
# Auth: a Google Cloud service account with the Android Publisher API enabled,
# invited under Play Console → Users & permissions with "Release to testing
# tracks" for this app. Its JSON key is a *publishing* credential (write access
# to the store listing) — NOT committed; it lives git-ignored at
# ./play-service-account.json (override with --key or $PLAY_SERVICE_ACCOUNT_JSON).
#
# Caveat: Play requires the VERY FIRST bundle for a new app to be uploaded by
# hand in the Console before the API will accept uploads. After that, this script
# handles every subsequent closed-testing release.
#
# Prereqs:
#   • A release AAB already built — run scripts/build-aab.sh first.
#   • jq, curl, openssl on PATH.
#
# Usage:
#   bash scripts/upload-aab-to-play.sh                      # publish to "alpha" (Closed testing), prompts before commit
#   bash scripts/upload-aab-to-play.sh --dry-run           # everything except commit (validates auth + upload + notes)
#   bash scripts/upload-aab-to-play.sh --track my-testers  # a custom closed-testing track id
#   bash scripts/upload-aab-to-play.sh --draft             # stage as a draft release (review in Console before rollout)
#   bash scripts/upload-aab-to-play.sh --yes               # skip the confirmation prompt
#   bash scripts/upload-aab-to-play.sh --aab path/to.aab --key path/to/sa.json --notes release.md

set -euo pipefail
cd "$(dirname "$0")/.."

# ─── style helpers (shared shape with build-aab.sh) ──────────────────────────
if [[ -t 1 ]]; then
  c_reset=$'\033[0m'; c_bold=$'\033[1m'
  c_red=$'\033[31m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_blue=$'\033[34m'; c_cyan=$'\033[36m'
else
  c_reset=""; c_bold=""; c_red=""; c_green=""; c_yellow=""; c_blue=""; c_cyan=""
fi
say()    { printf "%s→%s %s\n" "$c_blue"   "$c_reset" "$*"; }
ok()     { printf "%s✓%s %s\n" "$c_green"  "$c_reset" "$*"; }
warn()   { printf "%s!%s %s\n" "$c_yellow" "$c_reset" "$*"; }
err()    { printf "%s✗%s %s\n" "$c_red"    "$c_reset" "$*" >&2; }
header() { printf "\n%s%s%s\n" "$c_bold$c_cyan" "$1" "$c_reset"; printf "%s%s%s\n" "$c_bold$c_cyan" "────────────────────────────────────────────────────────────" "$c_reset"; }

# ─── args ────────────────────────────────────────────────────────────────────
track="alpha"            # Play's default "Closed testing" track; or a custom closed-track id
status="completed"       # completed = released to all testers; draft = staged for Console review
aab="build/app/outputs/bundle/release/app-release.aab"
key="${PLAY_SERVICE_ACCOUNT_JSON:-play-service-account.json}"
notes_file="release.md"
package="dk.stormstyrken.twelvestepsapp"   # the Android applicationId (override with --package)
dry_run=0
assume_yes=0

while (( $# )); do
  case "$1" in
    --track)    shift; track="${1:?--track needs a value}" ;;
    --status)   shift; status="${1:?--status needs a value}" ;;
    --draft)    status="draft" ;;
    --aab)      shift; aab="${1:?--aab needs a path}" ;;
    --key)      shift; key="${1:?--key needs a path}" ;;
    --notes)    shift; notes_file="${1:?--notes needs a path}" ;;
    --package)  shift; package="${1:?--package needs a value}" ;;
    --dry-run)  dry_run=1 ;;
    -y|--yes)   assume_yes=1 ;;
    -h|--help)  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown flag: $1"; exit 2 ;;
  esac
  shift
done

# ─── pre-flight ──────────────────────────────────────────────────────────────
header "Pre-flight"

for tool in jq curl openssl; do
  command -v "$tool" >/dev/null 2>&1 || { err "$tool not on PATH — required."; exit 1; }
done
ok "jq / curl / openssl present"

if [ ! -f "$aab" ]; then
  err "AAB not found: $aab"
  err "Build one first: bash scripts/build-aab.sh"
  exit 1
fi
aab_abs=$(realpath "$aab")
size_mb=$(( $(stat -c%s "$aab_abs" 2>/dev/null || stat -f%z "$aab_abs") / 1024 / 1024 ))
ok "AAB: $aab_abs (${size_mb} MB)"

if [ ! -f "$key" ]; then
  err "Service-account key not found: $key"
  err "Create one (Google Cloud → service account → enable Android Publisher API),"
  err "invite its email under Play Console → Users & permissions with 'Release to"
  err "testing tracks', download the JSON key to ./play-service-account.json"
  err "(git-ignored), or pass --key / set \$PLAY_SERVICE_ACCOUNT_JSON."
  exit 1
fi
if ! jq -e '.client_email and .private_key' "$key" >/dev/null 2>&1; then
  err "$key is not a valid service-account JSON (missing client_email / private_key)."
  exit 1
fi
ok "Service-account key: $key ($(jq -r .client_email "$key"))"
ok "Play package: $package"

# ─── parse release notes (FIRST block in release.md = the release being shipped) ─
header "Release notes"

extract_block() { # $1=tag → inner text of the FIRST <tag>…</tag> in $notes_file
  awk -v tag="$1" '
    $0=="<" tag ">"  {grab=1; next}
    $0=="</" tag ">" {if(grab) exit}
    grab {print}
  ' "$notes_file"
}

[ -f "$notes_file" ] || { err "release notes file not found: $notes_file"; exit 1; }
version=$(awk '/^[0-9]+\.[0-9]+\.[0-9]+ - /{print $1; exit}' "$notes_file")
notes_en=$(extract_block "en-GB")
notes_da=$(extract_block "da-DK")

[ -n "$version" ]   || { err "Couldn't find a 'X.Y.Z - DATE:' version line in $notes_file"; exit 1; }
[ -n "$notes_en" ]  || { err "No <en-GB>…</en-GB> block under the top version in $notes_file"; exit 1; }
[ -n "$notes_da" ]  || { err "No <da-DK>…</da-DK> block under the top version in $notes_file"; exit 1; }

# Cross-check the notes version against the build SSOT (pubspec.yaml) so stale
# notes can't ship.
conf_version=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*([0-9.]+)\+.*/\1/')
if [ "$version" != "$conf_version" ]; then
  warn "release.md top block is $version but pubspec.yaml is $conf_version — notes may be stale."
fi

# Play caps each locale's notes at 500 characters (locale-aware count).
len_en=$(printf '%s' "$notes_en" | wc -m | tr -d ' ')
len_da=$(printf '%s' "$notes_da" | wc -m | tr -d ' ')
for pair in "en-GB:$len_en" "da-DK:$len_da"; do
  loc=${pair%%:*}; n=${pair##*:}
  if [ "$n" -gt 500 ]; then
    err "$loc release notes are $n chars — Play's limit is 500. Trim release.md."
    exit 1
  fi
done
ok "v$version — en-GB ${len_en} chars, da-DK ${len_da} chars (≤ 500)"

# ─── authenticate (service-account JWT → OAuth access token) ──────────────────
header "Authenticate"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s); exp=$((now + 3600))
client_email=$(jq -r .client_email "$key")
token_uri=$(jq -r '.token_uri // "https://oauth2.googleapis.com/token"' "$key")

jwt_header='{"alg":"RS256","typ":"JWT"}'
jwt_claim=$(jq -cn --arg iss "$client_email" --arg aud "$token_uri" \
  --argjson iat "$now" --argjson exp "$exp" \
  '{iss:$iss, scope:"https://www.googleapis.com/auth/androidpublisher", aud:$aud, iat:$iat, exp:$exp}')

pk_file=$(mktemp); trap 'rm -f "$pk_file"' EXIT
jq -r .private_key "$key" > "$pk_file"

signing_input="$(printf '%s' "$jwt_header" | b64url).$(printf '%s' "$jwt_claim" | b64url)"
signature=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$pk_file" | b64url)
jwt="${signing_input}.${signature}"

token_resp=$(curl -sS -X POST "$token_uri" \
  --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  --data-urlencode "assertion=$jwt")
access_token=$(jq -r '.access_token // empty' <<<"$token_resp")
if [ -z "$access_token" ]; then
  err "Token exchange failed:"
  jq . <<<"$token_resp" >&2 2>/dev/null || printf '%s\n' "$token_resp" >&2
  exit 1
fi
ok "Access token acquired"

# ─── Play API helper ─────────────────────────────────────────────────────────
api="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package"
upload_api="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package"
auth=(-H "Authorization: Bearer $access_token")

http() { # http METHOD URL [extra curl args…] → body on stdout; aborts on non-2xx
  local method="$1" url="$2"; shift 2
  local out code body
  out=$(curl -sS -X "$method" "${auth[@]}" "$@" -w $'\n%{http_code}' "$url")
  code=${out##*$'\n'}; body=${out%$'\n'*}
  if [[ "$code" != 2* ]]; then
    err "Play API $method ${url##*/} → HTTP $code"
    jq . <<<"$body" >&2 2>/dev/null || printf '%s\n' "$body" >&2
    exit 1
  fi
  printf '%s' "$body"
}

# ─── 1. open an edit ─────────────────────────────────────────────────────────
header "Open edit"
edit_id=$(http POST "$api/edits" | jq -r .id)
ok "Edit $edit_id"

# ─── 2. upload the bundle ────────────────────────────────────────────────────
header "Upload bundle"
say "uploading ${size_mb} MB…"
upload_resp=$(http POST "$upload_api/edits/$edit_id/bundles?uploadType=media" \
  -H "Content-Type: application/octet-stream" --data-binary "@$aab_abs")
version_code=$(jq -r .versionCode <<<"$upload_resp")
[ -n "$version_code" ] && [ "$version_code" != "null" ] || { err "Upload returned no versionCode."; exit 1; }
ok "Uploaded — versionCode $version_code"

# ─── 3. assign to the track with bilingual release notes ─────────────────────
header "Assign to track '$track' ($status)"
track_payload=$(jq -cn \
  --arg track "$track" --arg vc "$version_code" --arg status "$status" \
  --arg en "$notes_en" --arg da "$notes_da" \
  '{track:$track, releases:[{versionCodes:[$vc], status:$status, releaseNotes:[
      {language:"en-GB", text:$en},
      {language:"da-DK", text:$da}
    ]}]}')
http PUT "$api/edits/$edit_id/tracks/$track" \
  -H "Content-Type: application/json" -d "$track_payload" >/dev/null
ok "v$version (versionCode $version_code) staged on '$track' with en-GB + da-DK notes"

# ─── 4. commit (or discard on --dry-run) ─────────────────────────────────────
if [ "$dry_run" -eq 1 ]; then
  header "Dry run — discarding edit"
  http DELETE "$api/edits/$edit_id" >/dev/null
  ok "Edit discarded. Nothing was published. Auth + upload + notes all validated."
  exit 0
fi

if [ "$assume_yes" -ne 1 ]; then
  printf '\n%sPublish v%s (versionCode %s) to track "%s" as %s for testers? [y/N] %s' \
    "$c_bold" "$version" "$version_code" "$track" "$status" "$c_reset"
  read -r reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    http DELETE "$api/edits/$edit_id" >/dev/null
    warn "Aborted — edit discarded. Nothing was published."
    exit 1
  fi
fi

header "Commit"
http POST "$api/edits/$edit_id:commit" >/dev/null
ok "Committed. v$version is live on the '$track' track for closed testers."
echo
echo "  ${c_bold}Track:${c_reset} $track    ${c_bold}versionCode:${c_reset} $version_code    ${c_bold}status:${c_reset} $status"
echo "  Watch rollout at Play Console → Testing → ${track}."
