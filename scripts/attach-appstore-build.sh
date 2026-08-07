#!/usr/bin/env bash
# attach-appstore-build.sh — point the pending App Store version at a build.
#
# Uploading to TestFlight does NOT attach the build to the version. That is a
# separate relationship, and it is the one that decides what reviewers and the
# public get. It is also invisible from every other command, which is how a
# pending version sat on build 108 while TestFlight had 112.
#
# Defaults to the version and build in pubspec.yaml, so "attach what I just
# built" is the no-argument case.
#
# Usage:
#   bash scripts/attach-appstore-build.sh          # dry run
#   bash scripts/attach-appstore-build.sh --yes    # attach
#   bash scripts/attach-appstore-build.sh --version 2.3.5 --build 113
set -euo pipefail
cd "$(dirname "$0")/.."

apply=0; version=""; build=""
while (( $# )); do
  case "$1" in
    --version) shift; version="${1:?--version needs a value}" ;;
    --build)   shift; build="${1:?--build needs a value}" ;;
    -y|--yes)  apply=1 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

ssot=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
[ -n "$version" ] || version="${ssot%%+*}"
[ -n "$build" ]   || build="${ssot##*+}"

key="${ASC_KEY:-$(ls AuthKey_*.p8 2>/dev/null | head -1)}"
[ -n "$key" ] && [ -f "$key" ] || { echo "AuthKey_<KEYID>.p8 not found" >&2; exit 1; }
[ -f asc_issuer ] || { echo "./asc_issuer not found" >&2; exit 1; }

ASC_KEY="$key" \
ASC_KEY_ID="$(basename "$key" | sed -E 's/^AuthKey_(.+)\.p8$/\1/')" \
ASC_ISSUER_ID="$(tr -d ' \n' < asc_issuer)" \
ASC_VERSION="$version" ASC_BUILD="$build" ASC_APPLY="$apply" \
  node scripts/lib/asc-attach-build.mjs
