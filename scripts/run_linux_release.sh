#!/usr/bin/env bash
# Build the Linux release bundle and run it.
# Usage: ./scripts/run_linux_release.sh [extra args passed through to the app]

set -euo pipefail

# Resolve the repo root so the script works from any working directory
# (it lives in <root>/scripts).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Matches BINARY_NAME in linux/CMakeLists.txt.
BINARY_NAME="twelvestepsapp"

echo "Building Linux release..."
flutter build linux --release

# Flutter writes the bundle under build/linux/<arch>/release/bundle.
BUNDLE_DIR=""
for arch in x64 arm64; do
  candidate="build/linux/${arch}/release/bundle"
  if [[ -x "${candidate}/${BINARY_NAME}" ]]; then
    BUNDLE_DIR="$candidate"
    break
  fi
done

if [[ -z "$BUNDLE_DIR" ]]; then
  echo "Error: could not find the release bundle for '${BINARY_NAME}'." >&2
  echo "Looked under build/linux/{x64,arm64}/release/bundle." >&2
  exit 1
fi

echo "Launching ${BUNDLE_DIR}/${BINARY_NAME}..."
exec "${BUNDLE_DIR}/${BINARY_NAME}" "$@"
