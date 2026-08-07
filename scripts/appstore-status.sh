#!/usr/bin/env bash
# appstore-status.sh — read-only: what would I be submitting to the App Store?
#
# Prints every recent version, its state, the BUILD attached to it, and each
# locale's screenshot count and keywords. Submitting is deliberately not
# automated — it puts the app in front of reviewers and then the public, which
# is the owner's call. This exists so that call is made with the facts, because
# the pending version's attached build can quietly be several builds old.
#
# Usage: bash scripts/appstore-status.sh
# Credentials: ./AuthKey_<KEYID>.p8 + ./asc_issuer (git-ignored), the same pair
# upload-ipa-to-testflight.sh uses.
set -euo pipefail
cd "$(dirname "$0")/.."
key="${ASC_KEY:-$(ls AuthKey_*.p8 2>/dev/null | head -1)}"
[ -n "$key" ] && [ -f "$key" ] || { echo "AuthKey_<KEYID>.p8 not found at the repo root" >&2; exit 1; }
[ -f asc_issuer ] || { echo "./asc_issuer not found" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node 18+ required" >&2; exit 1; }
ASC_KEY="$key" \
ASC_KEY_ID="$(basename "$key" | sed -E 's/^AuthKey_(.+)\.p8$/\1/')" \
ASC_ISSUER_ID="$(tr -d ' \n' < asc_issuer)" \
  node scripts/lib/asc-status.mjs
