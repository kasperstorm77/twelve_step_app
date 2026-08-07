/// Builds `assets/content/morning_randomizer_v1.json` from Emotional
/// Sobriety's `assets/defaults/workshop_exercises_v1.json`.
///
/// The option IDs and their `en`/`da` text are a cross-app contract: a Morning
/// Ritual history record snapshots the ID *and* the text, and the other app
/// re-resolves that ID against its own Workshop catalog. If someone edits our
/// asset by hand — even to fix a typo — the two apps start disagreeing about
/// what the same day meant, and nothing would notice (plan P3.4).
///
/// So the asset is generated, never typed. `tool/regenerate_morning_randomizer.dart`
/// runs this against the real file in the sibling checkout, and
/// `test/morning_randomizer_catalog_generation_test.dart` runs it against a
/// captured fixture and fails if the checked-in asset has drifted from it.
library;

import 'dart:convert';

/// The one source both apps ship.
const justForTodayExerciseId = 'just_for_today';

/// The catalog schema our app's loader accepts (`MorningRandomizerSource`).
const catalogSchemaVersion = 1;
const catalogId = 'morning_randomizer_v1';

/// The locales the catalog must carry for every option. Our loader rejects a
/// source that is missing either one, so a partial translation upstream is a
/// generation-time failure rather than a runtime surprise.
const requiredLocales = ['en', 'da'];

/// Extracts the `just_for_today` exercise from a decoded
/// `workshop_exercises_v1.json` and returns our catalog as a JSON string,
/// formatted exactly the way the asset is checked in (2-space indent,
/// trailing newline).
String buildCatalogJson(Map<String, dynamic> workshopCatalog) {
  final exercises = workshopCatalog['exercises'];
  if (exercises is! List) {
    throw const FormatException('Workshop catalog has no exercises list');
  }

  final exercise = exercises.cast<Map<String, dynamic>>().firstWhere(
    (e) => e['id'] == justForTodayExerciseId,
    orElse: () => throw const FormatException(
      'Workshop catalog has no "$justForTodayExerciseId" exercise',
    ),
  );

  final prompts = exercise['prompts'];
  if (prompts is! List || prompts.isEmpty) {
    throw const FormatException('"$justForTodayExerciseId" has no prompts');
  }

  final options = <Map<String, dynamic>>[];
  final seenIds = <String>{};
  for (final rawPrompt in prompts) {
    final prompt = rawPrompt as Map<String, dynamic>;
    final id = prompt['id'];
    final order = prompt['order'];
    final text = prompt['text'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('A prompt is missing its id');
    }
    if (!seenIds.add(id)) {
      throw FormatException('Duplicate prompt id: $id');
    }
    if (order is! int) {
      throw FormatException('Prompt $id is missing an integer order');
    }
    if (text is! Map<String, dynamic>) {
      throw FormatException('Prompt $id is missing its text map');
    }
    for (final locale in requiredLocales) {
      final value = text[locale];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Prompt $id has no $locale text');
      }
    }
    options.add({
      'id': id,
      'order': order,
      // Only the locales our app ships — the Workshop file may carry more.
      'text': {for (final l in requiredLocales) l: text[l] as String},
    });
  }

  options.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

  final title = exercise['title'];
  if (title is! Map<String, dynamic>) {
    throw const FormatException('"$justForTodayExerciseId" has no title map');
  }

  final catalog = <String, dynamic>{
    'schemaVersion': catalogSchemaVersion,
    'catalogId': catalogId,
    'sources': [
      {
        'id': justForTodayExerciseId,
        'title': {for (final l in requiredLocales) l: title[l] as String},
        'options': options,
      },
    ],
  };

  return '${const JsonEncoder.withIndent('  ').convert(catalog)}\n';
}
