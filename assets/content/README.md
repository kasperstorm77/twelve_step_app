# Bundled content assets

## `morning_randomizer_v1.json` — generated, never hand-edited

The Just for Today options are a **cross-app contract**. A Morning Ritual
history record snapshots an option's ID *and* its text, and Emotional
Sobriety re-resolves that ID against its own Workshop catalog. Paraphrase
one line here and the two apps disagree about what the same day meant.

Regenerate from the other app's catalog:

```bash
# defaults to ../emotional_sobriety/assets/defaults/workshop_exercises_v1.json
dart run tool/regenerate_morning_randomizer.dart

# fails (exit 2) if this asset is stale — no writes
dart run tool/regenerate_morning_randomizer.dart --check

dart run tool/regenerate_morning_randomizer.dart --source <path>
```

When upstream changes, update `test/fixtures/emotional_sobriety_workshop_v1.json`
in the same change — it is that exercise lifted verbatim from their real file,
and [`test/morning_randomizer_catalog_generation_test.dart`](../../test/morning_randomizer_catalog_generation_test.dart)
regenerates from it and fails if this asset has drifted.
