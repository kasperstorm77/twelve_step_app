import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/morning_randomizer_generator.dart';

/// The Just for Today catalog is generated from Emotional Sobriety's Workshop
/// catalog, and its option IDs and text are a cross-app contract — a history
/// record snapshots the ID and the text, and the other app re-resolves that ID
/// against its own copy. Nothing used to stop someone editing our asset by
/// hand, and the only signal would have been a user seeing different words in
/// each app (plan P3.4).
///
/// `emotional_sobriety_workshop_v1.json` is the `just_for_today` exercise
/// lifted verbatim out of that app's real `workshop_exercises_v1.json` — not
/// hand-authored. Regenerating from it must reproduce the shipped asset
/// exactly.
void main() {
  final asset = File('assets/content/morning_randomizer_v1.json');
  final fixture = File('test/fixtures/emotional_sobriety_workshop_v1.json');

  test('the shipped catalog is exactly what the generator produces', () {
    final workshop =
        jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;

    expect(
      buildCatalogJson(workshop),
      asset.readAsStringSync(),
      reason:
          'assets/content/morning_randomizer_v1.json has drifted from the '
          'upstream Workshop catalog. Do not hand-edit it — run '
          '`dart run tool/regenerate_morning_randomizer.dart` and update '
          'test/fixtures/emotional_sobriety_workshop_v1.json in the same '
          'change.',
    );
  });

  test('every option carries both locales and a unique stable id', () {
    final catalog =
        jsonDecode(asset.readAsStringSync()) as Map<String, dynamic>;
    final source = (catalog['sources'] as List).single as Map<String, dynamic>;
    final options = (source['options'] as List).cast<Map<String, dynamic>>();

    expect(source['id'], justForTodayExerciseId);
    expect(options, hasLength(10));
    expect(
      options.map((o) => o['id']).toSet(),
      hasLength(options.length),
      reason: 'option IDs are the cross-app key and must be unique',
    );
    for (final option in options) {
      final text = option['text'] as Map<String, dynamic>;
      expect(
        text.keys.toSet(),
        requiredLocales.toSet(),
        reason: 'option ${option['id']} must carry exactly en + da',
      );
      for (final locale in requiredLocales) {
        expect((text[locale] as String).trim(), isNotEmpty);
      }
    }
  });

  test('the generator refuses upstream content it cannot represent', () {
    // A prompt that lost its Danish translation upstream must fail generation
    // rather than ship a source our own loader would reject at runtime.
    final workshop =
        jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
    final exercise =
        (workshop['exercises'] as List).first as Map<String, dynamic>;
    ((exercise['prompts'] as List).first as Map<String, dynamic>)['text'] =
        <String, dynamic>{'en': 'English only'};

    expect(() => buildCatalogJson(workshop), throwsFormatException);
  });
}
