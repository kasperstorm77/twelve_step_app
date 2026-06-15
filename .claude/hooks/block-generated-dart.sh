#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): block edits to generated *.g.dart files.
#
# Hive adapters in *.g.dart are produced by build_runner. Hand-editing them is
# overwritten on the next build and risks breaking frozen Hive typeIds
# (CLAUDE.md hard rules #1-#2). Deny the write and point at the real fix.
set -uo pipefail

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

case "$f" in
  *.g.dart)
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"This is a generated Hive adapter (*.g.dart), owned by build_runner. Edit the source model (the matching .dart file) instead, then regenerate with `dart run build_runner build --delete-conflicting-outputs` (or run /regen). Hand edits are overwritten on the next build and can break frozen Hive typeIds."}}
JSON
    exit 0
    ;;
esac
exit 0
