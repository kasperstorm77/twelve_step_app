#!/usr/bin/env bash
# set-appstore-release-notes.sh — write the App Store version's "What's New"
# for every locale, from the top block of release.md.
#
# This is the STORE PAGE's release notes (appStoreVersionLocalizations.whatsNew),
# not TestFlight's "What to Test" (that is upload-ipa-to-testflight.sh). Nothing
# used to write it, so it drifted: the Danish locale carried English notes and
# en-GB carried none, while both descriptions were correctly localized.
#
# Usage:
#   bash scripts/set-appstore-release-notes.sh            # dry run
#   bash scripts/set-appstore-release-notes.sh --yes      # write
#   bash scripts/set-appstore-release-notes.sh --version 2.3.5
set -euo pipefail
cd "$(dirname "$0")/.."

apply=0
version=""
notes_file="release.md"
while (( $# )); do
  case "$1" in
    --version) shift; version="${1:?--version needs a value}" ;;
    --notes)   shift; notes_file="${1:?--notes needs a path}" ;;
    -y|--yes)  apply=1 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

# Default to the version in the build SSOT, so notes can't be attached to the
# wrong version by accident.
[ -n "$version" ] || version=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*([0-9.]+)\+.*/\1/')

extract() { awk -v tag="$1" '$0=="<" tag ">"{g=1;next} $0=="</" tag ">"{if(g)exit} g{print}' "$notes_file"; }
en=$(extract "en-GB"); da=$(extract "da-DK")
[ -n "$en" ] && [ -n "$da" ] || { echo "could not read <en-GB>/<da-DK> from $notes_file" >&2; exit 1; }

top=$(awk '/^[0-9]+\.[0-9]+\.[0-9]+ - /{print $1; exit}' "$notes_file")
if [ "$top" != "$version" ]; then
  echo "release.md's top block is $top but targeting $version — refusing to attach stale notes" >&2
  exit 1
fi

key="${ASC_KEY:-$(ls AuthKey_*.p8 2>/dev/null | head -1)}"
[ -n "$key" ] && [ -f "$key" ] || { echo "AuthKey_<KEYID>.p8 not found" >&2; exit 1; }
[ -f asc_issuer ] || { echo "./asc_issuer not found" >&2; exit 1; }

ASC_KEY="$key" \
ASC_KEY_ID="$(basename "$key" | sed -E 's/^AuthKey_(.+)\.p8$/\1/')" \
ASC_ISSUER_ID="$(tr -d ' \n' < asc_issuer)" \
ASC_VERSION="$version" \
ASC_APPLY="$apply" \
ASC_NOTES_JSON="$(jq -n --arg en "$en" --arg da "$da" '{"en-GB":$en,"da-DK":$da}')" \
  node scripts/lib/asc-version-notes.mjs
