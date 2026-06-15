---
name: regen
description: >-
  Regenerate this repo's Hive type adapters with build_runner and verify the
  result. Use after changing any @HiveType / @HiveField model so the matching
  *.g.dart adapter is rebuilt. The *.g.dart files are generated — never hand-edit
  them.
disable-model-invocation: true
---

# /regen — regenerate Hive adapters and verify

Run this after editing any model annotated with `@HiveType` / `@HiveField`
(e.g. files under `lib/**/models/`). It rebuilds the generated `*.g.dart`
adapters from source and confirms the project still analyzes and tests clean.

## Steps

1. **Regenerate** (deletes stale outputs first so renamed/removed fields don't
   linger):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
   If it reports conflicts it can't resolve, run
   `dart run build_runner clean` then repeat.

2. **Review the regenerated adapters.** `git diff -- '*.g.dart'`. Sanity-check
   against the frozen-schema rules in [CLAUDE.md](../../../CLAUDE.md):
   - typeIds unchanged (next free is 17) and any new adapter is registered in
     [lib/main.dart](../../../lib/main.dart);
   - `@HiveField` indices unchanged/additive, enums appended only.
   If anything looks off, invoke the **schema-guardian** subagent on the diff.

3. **Analyze** — must be clean:
   ```bash
   flutter analyze
   ```

4. **Test** — must pass:
   ```bash
   flutter test
   ```

## Report

State what regenerated (which `*.g.dart` changed), and the analyze/test results.
If analyze or tests fail, show the failing output — do not report success.

Do not bump `pubspec.yaml` `version:` and do not commit unless explicitly asked.
