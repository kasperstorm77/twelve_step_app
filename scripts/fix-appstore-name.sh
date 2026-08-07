#!/usr/bin/env bash
# fix-appstore-name.sh — report, and optionally correct, the App Store app name.
#
# The store name is the app's NAME: it must equal CFBundleDisplayName /
# android:label / MaterialApp.title exactly — "12 Steps App" — in every
# localization, untranslated and with no marketing suffix. A store page reading
# something else is a different app to the person who installed it.
#
# Apple freezes the name on a LIVE (READY_FOR_SALE) version; only the editable
# appInfo can be patched, so a live mismatch is reported and left alone — it
# changes when the next version is submitted.
#
# Usage:
#   bash scripts/fix-appstore-name.sh            # report only
#   bash scripts/fix-appstore-name.sh --yes      # correct the editable version
#   bash scripts/fix-appstore-name.sh --name "…" # override the expected name
#
# Credentials: ./AuthKey_<KEYID>.p8 (the Key ID is the filename) + ./asc_issuer,
# both git-ignored — the same pair upload-ipa-to-testflight.sh uses.
set -euo pipefail
cd "$(dirname "$0")/.."

name="12 Steps App"
apply=0
while (( $# )); do
  case "$1" in
    --name) shift; name="${1:?--name needs a value}" ;;
    -y|--yes) apply=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

key="${ASC_KEY:-$(ls AuthKey_*.p8 2>/dev/null | head -1)}"
[ -n "$key" ] && [ -f "$key" ] || { echo "AuthKey_<KEYID>.p8 not found at the repo root" >&2; exit 1; }
[ -f asc_issuer ] || { echo "./asc_issuer not found" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node 18+ required" >&2; exit 1; }

ASC_KEY="$key" \
ASC_KEY_ID="$(basename "$key" | sed -E 's/^AuthKey_(.+)\.p8$/\1/')" \
ASC_ISSUER_ID="$(tr -d ' \n' < asc_issuer)" \
ASC_APP_NAME="$name" \
ASC_APPLY="$apply" \
  node scripts/lib/asc-app-name.mjs
