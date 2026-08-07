#!/usr/bin/env bash
# publish-play-listing.sh — replace the Google Play *store listing* text
# (title, short description, full description) for en-GB and da-DK with the
# copy in docs/play_store-retain/PLAY_STORE_DESCRIPTIONS.md.
#
# This is the listing, NOT a release. It ships no APK/AAB and touches no track:
#
#   edits.insert → listings.update ×N → edits.validate → edits.commit
#
# The copy is prose someone wrote and reviewed, so it is read out of the doc
# rather than retyped here — scripts/lib/play-listing.py parses it and enforces
# Play's limits (title 30, short 80, full 4000). The doc is hard-wrapped at ~78
# columns like every other document in this repository; Play renders newlines
# literally, so paragraphs and bullets are unwrapped before sending. Use
# --verbatim to send the doc's own line breaks instead, and --dry-run to read
# exactly what would go up.
#
# Permission: the service account needs **"Manage store presence"** on this app
# (Play Console → Users & permissions → the account → App permissions). With
# only "Release to testing tracks", listings.update returns 200 and then
# edits:validate fails 403 — the write looks fine right up until the commit.
#
# Usage:
#   bash scripts/publish-play-listing.sh --dry-run   # print the copy, commit nothing
#   bash scripts/publish-play-listing.sh             # publish (prompts first)
#   bash scripts/publish-play-listing.sh --yes       # publish without the prompt
#   bash scripts/publish-play-listing.sh --verbatim  # keep the doc's line breaks

set -euo pipefail
cd "$(dirname "$0")/.."

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

key="${PLAY_SERVICE_ACCOUNT_JSON:-play-service-account.json}"
package="dk.stormstyrken.twelvestepsapp"
dry_run=0
assume_yes=0
verbatim=0

while (( $# )); do
  case "$1" in
    --key)      shift; key="${1:?--key needs a path}" ;;
    --package)  shift; package="${1:?--package needs a value}" ;;
    --dry-run)  dry_run=1 ;;
    --verbatim) verbatim=1 ;;
    -y|--yes)   assume_yes=1 ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown flag: $1"; exit 2 ;;
  esac
  shift
done

header "Pre-flight"
for tool in jq curl openssl python3; do
  command -v "$tool" >/dev/null 2>&1 || { err "$tool not on PATH — required."; exit 1; }
done
ok "jq / curl / openssl / python3 present"

[ -f "$key" ] || { err "Service-account key not found: $key"; exit 1; }
jq -e '.client_email and .private_key' "$key" >/dev/null 2>&1 \
  || { err "$key is not a valid service-account JSON."; exit 1; }
ok "Service-account key: $key ($(jq -r .client_email "$key"))"
ok "Play package: $package"

header "Listing copy"
# Built as a string, not an array: macOS ships bash 3.2, where expanding an
# EMPTY array under `set -u` is itself an "unbound variable" error.
parse_flag=""
[ "$verbatim" -eq 1 ] && parse_flag="--verbatim"
if ! listings=$(python3 scripts/lib/play-listing.py $parse_flag); then
  err "Could not read the listing copy (see above)."
  exit 1
fi
languages=$(jq -r 'keys[]' <<<"$listings")
[ -n "$languages" ] || { err "No languages parsed out of the doc."; exit 1; }

while IFS= read -r lang; do
  t=$(jq -r --arg l "$lang" '.[$l].title' <<<"$listings")
  s=$(jq -r --arg l "$lang" '.[$l].short' <<<"$listings")
  f=$(jq -r --arg l "$lang" '.[$l].full'  <<<"$listings")
  printf '  %s%s%s  title %s/30 · short %s/80 · full %s/4000\n' \
    "$c_bold" "$lang" "$c_reset" "${#t}" "${#s}" "${#f}"
done <<<"$languages"
ok "Copy parsed and within Play's limits"

if [ "$dry_run" -eq 1 ]; then
  header "Dry run — the exact text that would be published"
  while IFS= read -r lang; do
    printf '\n%s──── %s ────%s\n' "$c_bold$c_cyan" "$lang" "$c_reset"
    jq -r --arg l "$lang" '"TITLE\n" + .[$l].title + "\n\nSHORT\n" + .[$l].short + "\n\nFULL\n" + .[$l].full' <<<"$listings"
  done <<<"$languages"
fi

# ─── authenticate ────────────────────────────────────────────────────────────
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
token_resp=$(curl -sS -X POST "$token_uri" \
  --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  --data-urlencode "assertion=${signing_input}.${signature}")
access_token=$(jq -r '.access_token // empty' <<<"$token_resp")
[ -n "$access_token" ] || { err "Token exchange failed:"; jq . <<<"$token_resp" >&2; exit 1; }
ok "Access token acquired"

api="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package"
auth=(-H "Authorization: Bearer $access_token")

http() { # http METHOD URL [curl args…] → body; aborts on non-2xx
  local method="$1" url="$2"; shift 2
  local out code body
  out=$(curl -sS -X "$method" "${auth[@]}" "$@" -w $'\n%{http_code}' "$url")
  code=${out##*$'\n'}; body=${out%$'\n'*}
  if [[ "$code" != 2* ]]; then
    err "Play API $method ${url##*/} → HTTP $code"
    jq . <<<"$body" >&2 2>/dev/null || printf '%s\n' "$body" >&2
    if [ "$code" = "403" ]; then
      err ""
      err "403 here almost always means the service account lacks"
      err "\"Manage store presence\" on this app. Releasing to testing tracks"
      err "is a different permission — writing the listing succeeds without it,"
      err "and only edits:validate/commit fails."
    fi
    exit 1
  fi
  printf '%s' "$body"
}

header "Open edit"
edit_id=$(http POST "$api/edits" | jq -r .id)
ok "Edit $edit_id"

header "Write the listings"
while IFS= read -r lang; do
  payload=$(jq -c --arg l "$lang" \
    '{language:$l, title:.[$l].title, shortDescription:.[$l].short, fullDescription:.[$l].full}' \
    <<<"$listings")
  http PUT "$api/edits/$edit_id/listings/$lang" \
    -H "Content-Type: application/json" -d "$payload" >/dev/null
  ok "$lang written"
done <<<"$languages"

header "Validate"
# This is the step that fails 403 without "Manage store presence" — the writes
# above return 200 either way, so a green run up to here proves nothing.
http POST "$api/edits/$edit_id:validate" >/dev/null
ok "Edit validates"

if [ "$dry_run" -eq 1 ]; then
  header "Dry run — discarding edit"
  http DELETE "$api/edits/$edit_id" >/dev/null
  ok "Edit discarded. Nothing was published. Auth + write + validate all passed."
  exit 0
fi

if [ "$assume_yes" -ne 1 ]; then
  printf '\n%sReplace the live Play store listing for %s? This is public. [y/N] %s' \
    "$c_bold" "$(tr '\n' ' ' <<<"$languages")" "$c_reset"
  read -r reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    http DELETE "$api/edits/$edit_id" >/dev/null
    warn "Aborted — edit discarded. The live listing is unchanged."
    exit 1
  fi
fi

header "Commit"
http POST "$api/edits/$edit_id:commit" >/dev/null
ok "Committed — the live Play listing now shows this copy."

header "Read back"
# A committed edit can no longer be read, so open one throwaway edit, compare
# what the store now holds against what we sent, and discard it. Verifying the
# commit returned 200 would only prove the request was accepted.
verify_id=$(http POST "$api/edits" | jq -r .id)
mismatch=0
while IFS= read -r lang; do
  live=$(http GET "$api/edits/$verify_id/listings/$lang")
  for field in title:title short:shortDescription full:fullDescription; do
    ours=$(jq -r --arg l "$lang" --arg f "${field%%:*}" '.[$l][$f]' <<<"$listings")
    theirs=$(jq -r --arg f "${field##*:}" '.[$f] // ""' <<<"$live")
    if [ "$ours" != "$theirs" ]; then
      err "$lang ${field%%:*} does not match what was sent"
      mismatch=1
    fi
  done
  [ "$mismatch" -eq 0 ] && ok "$lang matches"
done <<<"$languages"
http DELETE "$api/edits/$verify_id" >/dev/null

if [ "$mismatch" -ne 0 ]; then
  err "The live listing is not what this script sent — check Play Console."
  exit 4
fi

echo
say "Live listing updated. The store page can take a few minutes to reflect it:"
echo "  https://play.google.com/store/apps/details?id=$package"
