---
name: pre-pr
description: >-
  Pre-PR readiness checklist for this repo — runs analyze + tests, verifies the
  Hive box set is consistently wired across main.dart, the sync builder, and the
  restore service, and reminds you to keep the three docs current. Use before
  opening a PR or reporting a change done.
disable-model-invocation: true
---

# /pre-pr — readiness checklist

Run every step, then report a pass/fail summary. Do not declare the change done
unless analyze is clean and tests pass.

## 1. Analyze (must be clean)
```bash
flutter analyze
```

## 2. Tests (must pass)
```bash
flutter test
```

## 3. Box-set consistency (the silent-upload-crash guard)
A data box must be wired in all three places, or upload/restore breaks.
Compare the box names across:
- opened in [lib/main.dart](../../../lib/main.dart) (with the
  delete-and-recreate-on-corruption try/catch),
- exported in [sync_payload_builder.dart](../../../lib/shared/services/sync_payload_builder.dart)
  (reads every box **unguarded** — a box here but not opened in `main.dart`
  throws at upload),
- imported in [backup_restore_service.dart](../../../lib/shared/services/backup_restore_service.dart).

Quick diff of the box-name literals:
```bash
grep -oE "openBox(<[^>]*>)?\('[a-z_]+'\)" lib/main.dart | grep -oE "'[a-z_]+'" | sort -u
grep -oE "Hive\.box<[^>]*>\('[a-z_]+'\)" lib/shared/services/sync_payload_builder.dart | grep -oE "'[a-z_]+'" | sort -u
```
The data boxes should match (the `settings` box is exported via
`AppSettingsService`, and `windows_google_credentials` is opened only in the
desktop-OAuth code path — not `main.dart` — so neither needs to appear in the
builder's box reads). If a box is missing from
any site, that's a blocker — fix before PR.

## 4. Frozen-schema & localization spot-check
If the diff touches models, boxes, or sync: run the **schema-guardian**
subagent. If it touches UI strings or `localizations.dart`: run the
**l10n-checker** subagent.

## 5. Docs current (same PR)
Per [CLAUDE.md](../../../CLAUDE.md), keep the three docs in step with this change:
- changed invariant → `docs/architecture.md`
- notable pivot/fix → append to `docs/historic_implementation.md`
- landed / new roadmap item → `docs/implementation_plan.md`

## 6. Process reminders
- Do **not** bump `pubspec.yaml` `version:` unless asked — it's the user's call.
- Do **not** commit or push unless explicitly asked.
- Do **not** skip git hooks; if one fails, fix the cause.

## Report
Summarize each step as ✅/❌ with the relevant output for any failure, and list
any box-set or doc gaps found.
