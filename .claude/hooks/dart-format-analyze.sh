#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): format + analyze the touched Dart file.
#
# Reads the hook JSON on stdin, acts only on .dart source files, and skips
# generated *.g.dart adapters (owned by build_runner). Formatting is silent;
# analyzer findings are surfaced back to Claude via exit code 2 so they get
# fixed in the same turn. Infra failures (no dart, etc.) never block an edit.
set -uo pipefail

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

case "$f" in
  *.g.dart) exit 0 ;;   # generated — never format/analyze (and edits are blocked anyway)
  *.dart)   ;;
  *)        exit 0 ;;   # not a Dart file
esac

[ -f "$f" ] || exit 0
command -v dart >/dev/null 2>&1 || exit 0

# Format in place (fast, idempotent).
dart format "$f" >/dev/null 2>&1 || true

# Analyze just this file; surface any problems back to Claude.
out=$(dart analyze "$f" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'dart analyze flagged %s:\n%s\n' "$f" "$out" >&2
  exit 2
fi
exit 0
