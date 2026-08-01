# Morning Randomizer Portable Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve Emotional Sobriety's additive Morning randomizer definition
and history fields through Twelve Steps JSON/Drive import and re-export without
changing current Twelve Steps runner behavior.

**Architecture:** Extend the existing `RitualItem` and `RitualItemRecord`
models with three nullable, append-only fields. Keep enum ordinals and backup
schema `8.0` unchanged, regenerate Hive adapters, prove round-trip behavior,
and defer actual selection/UI behavior to a new canonical roadmap task.

**Tech Stack:** Flutter, Dart, Hive, shared JSON/Google Drive payload, Flutter
unit tests.

**Status:** Passive field implementation, review, documentation, and repository
verification are complete. Final commit, remote synchronization, and SHA
read-back remain in Task 4.

## Global Constraints

- Follow root `CLAUDE.md` plus `lib/morning_ritual/CLAUDE.md` and
  `lib/shared/CLAUDE.md` before changing their files.
- Work on `main` only because the owner explicitly requested a direct
  repository update and push.
- Use TDD and watch the targeted tests fail before production changes.
- Keep `RitualItemType.timer=0` and `RitualItemType.prayer=1` unchanged.
- Add `RitualItem.randomizerSourceId` at Hive 11 / JSON
  `randomizerSourceId`.
- Add `RitualItemRecord.selectedContentId` at Hive 5 / JSON
  `selectedContentId`.
- Add `RitualItemRecord.selectedContentText` at Hive 6 / JSON
  `selectedContentText`.
- Decode all three as null when absent; preserve them when present.
- Do not add random selection, Workshop data, runner rendering, or settings UI
  in this change.
- Keep backup version `8.0` and all top-level keys unchanged.
- Update visible text in English and Danish if any visible text changes; this
  passive compatibility slice should require none.

---

### Task 1: Pin nullable model and JSON round-trip behavior

**Files:**
- Create: `test/morning_ritual_randomizer_portability_test.dart`
- Modify: `lib/morning_ritual/models/ritual_item.dart`
- Modify: `lib/morning_ritual/models/morning_ritual_entry.dart`
- Modify: generated adapters in `lib/morning_ritual/models/`.

**Interfaces:**
- Produces: the three nullable fields at the frozen Hive/JSON IDs.
- Produces: missing-field decoding as null.

- [x] **Step 1: Write the failing model tests**

```dart
expect(
  RitualItem.fromJson(<String, dynamic>{
    ...baseItemJson,
    'randomizerSourceId': 'just_for_today',
  }).randomizerSourceId,
  'just_for_today',
);
expect(RitualItem.fromJson(baseItemJson).randomizerSourceId, isNull);
expect(
  RitualItemRecord.fromJson(<String, dynamic>{
    ...baseRecordJson,
    'selectedContentId': 'present_moment',
    'selectedContentText': 'Just for today...',
  }).toJson(),
  containsPair('selectedContentId', 'present_moment'),
);
```

- [x] **Step 2: Run the test and verify compilation fails for missing fields**

```bash
flutter test test/morning_ritual_randomizer_portability_test.dart
```

- [x] **Step 3: Add the nullable fields and JSON preservation**

Update constructors, `copyWith`, `toJson`, and `fromJson`. Keep missing fields
null. Preserve `lastModified` behavior and all existing defaults.

- [x] **Step 4: Regenerate adapters**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Inspect that `RitualItemAdapter` writes field 11 and
`RitualItemRecordAdapter` writes fields 5 and 6, with nullable reads.

- [x] **Step 5: Run the model test and verify it passes**

Run the Task 1 test command. Expected: pass.

### Task 2: Prove shared payload import and re-export preservation

**Files:**
- Modify: `test/morning_ritual_randomizer_portability_test.dart`
- Test through: `lib/shared/services/sync_payload_builder.dart`
- Test through: `lib/shared/services/backup_restore_service.dart`

**Interfaces:**
- Consumes: model `toJson`/`fromJson`.
- Produces: `8.0` payload round-trip without new top-level fields.

- [x] **Step 1: Add the failing backup round-trip assertion**

Open the normal test Hive boxes, restore a payload containing all three
fields, rebuild with `SyncPayloadBuilder`, and assert:

```dart
final item = (rebuilt['morningRitualItems'] as List).single as Map;
final record = (((rebuilt['morningRitualEntries'] as List).single as Map)
    ['items'] as List).single as Map;
expect(item['randomizerSourceId'], 'just_for_today');
expect(record['selectedContentId'], 'present_moment');
expect(record['selectedContentText'], 'Just for today...');
expect(rebuilt['version'], '8.0');
```

- [x] **Step 2: Run the test and verify the new values are currently dropped**

```bash
flutter test test/morning_ritual_randomizer_portability_test.dart
```

- [x] **Step 3: Make only the minimal restore/export correction if the model change is insufficient**

The expected implementation is no service change because both services call
the model serializers. If the failing test proves otherwise, update only the
single canonical import/export path; do not add an alternate map builder.

- [x] **Step 4: Verify new and existing Morning progress tests pass**

```bash
flutter test test/morning_ritual_randomizer_portability_test.dart test/morning_ritual_progress_test.dart
```

### Task 3: Document the passive contract and future behavior task

**Files:**
- Modify: `lib/morning_ritual/CLAUDE.md`
- Modify: `docs/architecture.md`
- Modify: `docs/historic_implementation.md`
- Modify: `docs/implementation_plan.md`

**Interfaces:**
- Produces: current-state field-ID documentation.
- Produces: incomplete P2 task for full Just for Today randomizer behavior.

- [x] **Step 1: Update current field invariants**

Document `RitualItem` field 11 and `RitualItemRecord` fields 5–6 as nullable,
append-only shared fields. State that current runner behavior remains prayer
text and that unknown/missing values are safe.

- [x] **Step 2: Append the passive-compatibility outcome**

Record why a new enum ordinal was rejected and that schema `8.0` plus top-level
keys remain unchanged.

- [x] **Step 3: Add P2.5 full randomizer implementation task**

The task must require:

- a bilingual, non-hardcoded `just_for_today` option source using the ten
  stable option IDs frozen by Emotional Sobriety;
- one random selection when the daily draft starts;
- resume stability;
- runner and history presentation;
- completion/skip snapshots through the already-landed fields;
- JSON/Drive round-trip and cross-app fixtures; and
- English/Danish UI and content parity.

### Task 4: Verify, commit, sync, and push

**Files:**
- Verify every changed/generated file.

- [x] **Step 1: Format and inspect generated code**

```bash
dart format .
git diff --check
```

- [x] **Step 2: Run complete repository verification**

```bash
flutter analyze
flutter test
```

- [ ] **Step 3: Review intended scope and commit**

```bash
git status --short
git diff --stat
git add lib/morning_ritual docs test/morning_ritual_randomizer_portability_test.dart
git commit -m "feat: preserve morning randomizer fields"
```

- [ ] **Step 4: Fetch, divergence-check, and push main**

```bash
git fetch origin main
git rev-list --left-right --count HEAD...origin/main
git push origin main
```

- [ ] **Step 5: Read back the remote SHA and clean state**

Require local `HEAD`, `origin/main`, and `git ls-remote origin refs/heads/main`
to match and `git status --short` to be empty.
