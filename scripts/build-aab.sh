#!/usr/bin/env bash
# build-aab.sh — build a release-signed Android App Bundle (.aab) for Google
# Play, verify it was signed with the RELEASE key (not the debug fallback), and
# print where/how to upload it.
#
# The AAB is Play's **upload** format: Play generates the per-device APKs from
# it. It is ALWAYS a release build. Flutter signs it from the keystore named in
# android/key.properties (storeFile / storePassword / keyAlias / keyPassword) —
# ONLY if that file is present; otherwise Gradle falls back to the debug key and
# Play rejects the upload, which this script warns about up front and verifies
# after the build.
#
# Version comes from pubspec.yaml `version: X.Y.Z+BUILD`: Flutter injects
# versionName=X.Y.Z and versionCode=BUILD. Play needs versionCode to STRICTLY
# INCREASE every upload — bump the `+BUILD` in pubspec.yaml first (a patch
# release bumps both: 2.2.13+106 → 2.2.14+107).
#
# Prereq: the release keystore + android/key.properties (both git-ignored).
#
# Usage:
#   bash scripts/build-aab.sh             # release AAB (default)
#   bash scripts/build-aab.sh --no-build  # skip the build, just locate+verify the last AAB
#   bash scripts/build-aab.sh -h

set -euo pipefail
cd "$(dirname "$0")/.."

# ─── style helpers ───────────────────────────────────────────────────────────
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
do_build=1
while (( $# )); do
  case "$1" in
    --no-build) do_build=0 ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown flag: $1"; exit 2 ;;
  esac
  shift
done

aab_path="build/app/outputs/bundle/release/app-release.aab"

# ─── pre-flight ──────────────────────────────────────────────────────────────
header "Pre-flight"

command -v flutter >/dev/null 2>&1 || { err "flutter not on PATH."; exit 1; }
ok "flutter $(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"

version_line=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
version="${version_line%%+*}"
build_no="${version_line##*+}"
[ -n "$version" ] && [ -n "$build_no" ] || { err "Couldn't parse 'version: X.Y.Z+BUILD' from pubspec.yaml"; exit 1; }
ok "pubspec version: $version (versionCode $build_no)"

# Release keystore — without it Gradle silently signs with the debug key and
# Play rejects the upload. Warn early (verified for real after the build).
if [ -f android/key.properties ]; then
  ok "android/key.properties present (release signing configured)"
else
  warn "android/key.properties missing — Gradle will fall back to the DEBUG key"
  warn "and Play will reject the AAB. Restore it before a real release."
fi

# ─── build ───────────────────────────────────────────────────────────────────
if [ "$do_build" -eq 1 ]; then
  header "Build AAB (flutter build appbundle --release)"
  say "flutter build appbundle --release"
  flutter build appbundle --release
else
  warn "Skipping build (--no-build) — locating the existing AAB."
fi

# ─── locate the AAB ──────────────────────────────────────────────────────────
header "Locate AAB"
if [ ! -f "$aab_path" ]; then
  err "AAB not found at $aab_path"
  err "Run without --no-build to build one first."
  exit 1
fi
size_bytes=$(stat -c%s "$aab_path" 2>/dev/null || stat -f%z "$aab_path")
size_mb=$(( size_bytes / 1024 / 1024 ))
aab_abs=$(realpath "$aab_path")
ok "Built AAB: $aab_abs (${size_mb} MB)"

# ─── verify the signer (must be the release key, not the debug fallback) ──────
header "Verify signer"
if command -v keytool >/dev/null 2>&1; then
  owner=$(keytool -printcert -jarfile "$aab_abs" 2>/dev/null | awk -F': ' '/Owner:/{print $2; exit}')
  if [ -z "$owner" ]; then
    warn "Couldn't read the AAB signer. Verify manually before uploading."
  elif printf '%s' "$owner" | grep -qi "Android Debug"; then
    err "AAB is DEBUG-signed ($owner) — Play will reject it. Restore android/key.properties + keystore and rebuild."
    exit 1
  else
    ok "Release-signed: $owner"
  fi
else
  warn "keytool not on PATH — can't verify the signer. Confirm it's the release key before uploading."
fi

# ─── next step ───────────────────────────────────────────────────────────────
header "Next step"
echo "  ${c_bold}AAB:${c_reset} $aab_abs (${size_mb} MB)"
echo
echo "  ${c_bold}Publish to a closed-testing track${c_reset} (automated — release notes from release.md):"
echo "    bash scripts/upload-aab-to-play.sh --dry-run   # validate auth + upload + notes, commit nothing"
echo "    bash scripts/upload-aab-to-play.sh             # push to 'alpha' (Closed testing) for testers"
echo
echo "  (Or upload by hand: Play Console → Testing → Closed testing → Create release → upload this .aab.)"
echo "  (versionCode must strictly increase — bump the +BUILD in pubspec.yaml before building.)"
