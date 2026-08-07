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
# ── This app publishes to CLOSED ALPHA, and nowhere else ─────────────────────
# The track is hard-pinned to "alpha". There is deliberately no --track flag:
# open testing and production are not destinations for this script, and a typo
# must not be able to make one.
#
# ── Why the track-precedence gate exists ─────────────────────────────────────
# Play serves a tester the build from the HIGHEST-PRIORITY track they belong to:
#
#     internal  →  closed (alpha)  →  open (beta)  →  production
#
# So a release left active on `internal` pins every tester who is also an
# internal tester to it, and a freshly published alpha build never reaches them.
# When the stale build's versionCode is *lower* than the new one, Play can
# neither update nor downgrade, so the Store simply offers nothing — which looks
# exactly like a broken package. The publish output stays green throughout,
# because every check verifies what was *uploaded* rather than what the store
# hands out. The sibling app lost hours to this three times.
#
# After committing, this script therefore re-reads the tracks and fails if
# `internal` holds an active release. Draft releases are ignored: a draft serves
# nobody, so an empty draft track must not trip the gate.
#
# Prereqs:
#   • A release AAB already built — run scripts/build-aab.sh first.
#   • jq, curl, openssl on PATH.
#
# Usage:
#   bash scripts/upload-aab-to-play.sh                     # publish to "alpha" (Closed testing), prompts before commit
#   bash scripts/upload-aab-to-play.sh --dry-run          # everything except commit (validates auth + upload + notes)
#   bash scripts/upload-aab-to-play.sh --audit-tracks     # read-only: print every track, run the precedence gate, upload nothing
#   bash scripts/upload-aab-to-play.sh --draft            # stage on alpha as a draft (review in Console before rollout)
#   bash scripts/upload-aab-to-play.sh --yes              # skip the confirmation prompt
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
# The destination is CLOSED ALPHA and nothing else. Not a variable you pass in —
# there is no --track flag on purpose (see the header).
readonly track="alpha"

# Tracks Play ranks ABOVE our closed track. A tester who is also on one of these
# is served that build instead of ours, so an active release here silently
# starves closed testing. `beta` (open) and `production` rank *below* closed and
# cannot shadow us — they are reported by --audit-tracks but never fail the gate.
readonly outranking_tracks=(internal)

# Every track worth printing in an audit, highest priority first.
readonly all_tracks=(internal alpha beta production)

status="completed"       # completed = released to all testers; draft = staged for Console review
aab="build/app/outputs/bundle/release/app-release.aab"
key="${PLAY_SERVICE_ACCOUNT_JSON:-play-service-account.json}"
notes_file="release.md"
package="dk.stormstyrken.twelvestepsapp"   # the Android applicationId (override with --package)
dry_run=0
assume_yes=0
audit_only=0
self_test=0

while (( $# )); do
  case "$1" in
    --status)   shift; status="${1:?--status needs a value}" ;;
    --draft)    status="draft" ;;
    --aab)      shift; aab="${1:?--aab needs a path}" ;;
    --key)      shift; key="${1:?--key needs a path}" ;;
    --notes)    shift; notes_file="${1:?--notes needs a path}" ;;
    --package)  shift; package="${1:?--package needs a value}" ;;
    --dry-run)  dry_run=1 ;;
    --audit-tracks) audit_only=1 ;;
    --self-test)    self_test=1 ;;
    -y|--yes)   assume_yes=1 ;;
    -h|--help)  sed -n '2,62p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --track)
      err "There is no --track flag: this app publishes to closed '$track' only."
      err "Open testing and production are not destinations for this script."
      exit 2 ;;
    *) err "unknown flag: $1"; exit 2 ;;
  esac
  shift
done

# ─── the precedence gate (pure — no network, so --self-test can exercise it) ──
# A release only reaches testers when it is inProgress or completed. `draft`
# serves nobody and `halted` has been stopped, so neither may trip the gate — an
# empty draft track is exactly the false positive this must not produce.
active_releases_on() { # $1=tracks json, $2=track → "status versionCodes" lines
  jq -r --arg t "$2" '
    .tracks[]? | select(.track == $t) | .releases[]?
    | select(.status == "inProgress" or .status == "completed")
    | "\(.status) versionCode=\((.versionCodes // []) | join(","))"
  ' <<<"$1"
}

# Does [track] actually serve [versionCode] to testers right now? Exact list
# membership, not a substring match — "11" must not match versionCode 110.
track_serves_version() { # $1=tracks json, $2=track, $3=versionCode → count
  jq -r --arg t "$2" --arg vc "$3" '
    [ .tracks[]? | select(.track == $t) | .releases[]?
      | select(.status == "inProgress" or .status == "completed")
      | select(((.versionCodes // []) | map(tostring)) | index($vc))
    ] | length
  ' <<<"$1"
}

print_track_report() { # $1=tracks json → every release, active or not
  local t line found
  for t in "${all_tracks[@]}"; do
    found=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      found=1
      printf '  %-12s %s\n' "$t" "$line"
    done < <(jq -r --arg t "$t" '
      .tracks[]? | select(.track == $t) | .releases[]?
      | "\(.status // "?") versionCode=\((.versionCodes // []) | join(",") | if . == "" then "-" else . end)"
    ' <<<"$1")
    # A plain `[ … ] && printf` would leave the function's exit status at 1
    # whenever the last track *did* have a release, and `set -e` then kills the
    # script before the gate below ever runs.
    if [ "$found" -eq 0 ]; then
      printf '  %-12s %s\n' "$t" "(no releases)"
    fi
  done
  return 0
}

# Fails when a track Play ranks above ours holds a release testers would be
# served instead of the closed build. Returns 1 rather than exiting, so the
# caller can report a completed publish before the delivery verdict.
assert_no_outranking_release() { # $1=tracks json
  local t releases line bad=0
  for t in "${outranking_tracks[@]}"; do
    releases=$(active_releases_on "$1" "$t")
    if [ -n "$releases" ]; then
      bad=1
      err "Track '$t' outranks '$track' and holds an active release:"
      while IFS= read -r line; do
        [ -n "$line" ] && err "    $line"
      done <<<"$releases"
    fi
  done
  if [ "$bad" -eq 1 ]; then
    err ""
    err "Play serves each tester the highest-priority track they belong to, so"
    err "anyone on '${outranking_tracks[*]}' is offered that build instead of the one"
    err "just published to '$track' — and if its versionCode is lower, Play can"
    err "neither update nor downgrade, so the Store offers nothing at all."
    err "Halt or remove that release in Play Console → Testing, then re-run."
    return 1
  fi
  return 0
}

# ─── --self-test: prove the gate's query before trusting it ──────────────────
# The live tracks only ever exercise one branch (whatever they happen to hold),
# so the cases that matter — a draft-only track, a halted release, an absent
# track — are pinned here against the real functions above.
if [ "$self_test" -eq 1 ]; then
  header "Gate self-test"
  fails=0
  expect() { # $1=label $2=expected(pass|trip) $3=tracks json
    local out verdict
    out=$(assert_no_outranking_release "$3" 2>/dev/null) && verdict=pass || verdict=trip
    if [ "$verdict" = "$2" ]; then ok "$1 → $verdict"; else err "$1 → $verdict (expected $2)"; fails=$((fails+1)); fi
  }
  expect "internal holds only a draft"      pass '{"tracks":[{"track":"internal","releases":[{"status":"draft","versionCodes":["99"]}]}]}'
  expect "internal release halted"          pass '{"tracks":[{"track":"internal","releases":[{"status":"halted","versionCodes":["99"]}]}]}'
  expect "internal track absent"            pass '{"tracks":[{"track":"alpha","releases":[{"status":"completed","versionCodes":["110"]}]}]}'
  expect "no tracks at all"                 pass '{"tracks":[]}'
  expect "internal completed"               trip '{"tracks":[{"track":"internal","releases":[{"status":"completed","versionCodes":["99"]}]}]}'
  expect "internal inProgress"              trip '{"tracks":[{"track":"internal","releases":[{"status":"inProgress","versionCodes":["101"]}]}]}'
  expect "internal draft AND completed"     trip '{"tracks":[{"track":"internal","releases":[{"status":"draft","versionCodes":["120"]},{"status":"completed","versionCodes":["99"]}]}]}'
  # Lower-priority tracks cannot shadow a closed release — they must never trip.
  expect "beta + production active"         pass '{"tracks":[{"track":"beta","releases":[{"status":"completed","versionCodes":["98"]}]},{"track":"production","releases":[{"status":"completed","versionCodes":["106"]}]}]}'

  # The post-commit read-back: does alpha actually serve what we just pushed?
  expect_served() { # $1=label $2=expected count $3=versionCode $4=tracks json
    local got
    got=$(track_serves_version "$4" "$track" "$3")
    if [ "$got" = "$2" ]; then ok "$1 → $got"; else err "$1 → $got (expected $2)"; fails=$((fails+1)); fi
  }
  alpha110='{"tracks":[{"track":"alpha","releases":[{"status":"completed","versionCodes":["110"]}]}]}'
  expect_served "alpha serves 110"          1 110 "$alpha110"
  expect_served "110 is not matched by 11"  0 11  "$alpha110"
  expect_served "alpha does not serve 109"  0 109 "$alpha110"
  expect_served "a draft release counts as unserved" 0 110 \
    '{"tracks":[{"track":"alpha","releases":[{"status":"draft","versionCodes":["110"]}]}]}'
  expect_served "numeric versionCodes match too" 1 110 \
    '{"tracks":[{"track":"alpha","releases":[{"status":"completed","versionCodes":[110]}]}]}'
  echo
  if [ "$fails" -eq 0 ]; then ok "gate self-test passed"; exit 0; fi
  err "$fails self-test case(s) failed"; exit 1
fi

# ─── pre-flight ──────────────────────────────────────────────────────────────
header "Pre-flight"

for tool in jq curl openssl; do
  command -v "$tool" >/dev/null 2>&1 || { err "$tool not on PATH — required."; exit 1; }
done
ok "jq / curl / openssl present"

if [ "$audit_only" -eq 0 ]; then
  if [ ! -f "$aab" ]; then
    err "AAB not found: $aab"
    err "Build one first: bash scripts/build-aab.sh"
    exit 1
  fi
  aab_abs=$(realpath "$aab")
  size_mb=$(( $(stat -c%s "$aab_abs" 2>/dev/null || stat -f%z "$aab_abs") / 1024 / 1024 ))
  ok "AAB: $aab_abs (${size_mb} MB)"
else
  ok "Audit only — no AAB needed, nothing will be uploaded"
fi

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
if [ "$audit_only" -eq 0 ]; then
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
fi

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

# Reading tracks needs an edit, and a committed edit can no longer be read — so
# the post-commit check opens a fresh throwaway edit and discards it.
read_tracks_json() { # → the tracks resource, via a short-lived edit
  local eid body
  eid=$(http POST "$api/edits" | jq -r .id)
  body=$(http GET "$api/edits/$eid/tracks")
  http DELETE "$api/edits/$eid" >/dev/null
  printf '%s' "$body"
}

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

# ─── audit-only mode: report every track, run the gate, upload nothing ───────
if [ "$audit_only" -eq 1 ]; then
  header "Track audit"
  tracks_json=$(read_tracks_json)
  print_track_report "$tracks_json"
  echo

  # Exercise the same read-back the post-commit step uses, against the build
  # SSOT, so the audit reports what the store hands out — not just what exists.
  want_code=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+).*/\1/')
  if [ -n "$want_code" ]; then
    if [ "$(track_serves_version "$tracks_json" "$track" "$want_code")" -gt 0 ]; then
      ok "'$track' serves versionCode $want_code (pubspec.yaml's current build)."
    else
      warn "'$track' does not serve versionCode $want_code — pubspec.yaml is ahead of the store."
    fi
  fi

  if assert_no_outranking_release "$tracks_json"; then
    ok "No track outranking '$track' holds an active release."
    exit 0
  fi
  exit 3
fi

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

# ─── 5. read back what the store actually holds ──────────────────────────────
# Everything above verified what was *uploaded*. This verifies what testers get.
header "Read back"
tracks_json=$(read_tracks_json)
print_track_report "$tracks_json"
echo

landed=$(track_serves_version "$tracks_json" "$track" "$version_code")
if [ "$status" = "draft" ]; then
  warn "Staged as a draft — no active release on '$track' by design; finish it in the Console."
elif [ "$landed" -eq 0 ]; then
  err "'$track' does not report an active release carrying versionCode $version_code."
  err "The commit returned success, so check Play Console → Testing → $track."
  exit 4
else
  ok "'$track' serves versionCode $version_code."
fi

if ! assert_no_outranking_release "$tracks_json"; then
  err ""
  err "The upload itself succeeded — this failure is about DELIVERY, not the build."
  exit 3
fi
ok "No track outranking '$track' holds an active release — testers get this build."
echo
echo "  Watch rollout at Play Console → Testing → ${track}."
