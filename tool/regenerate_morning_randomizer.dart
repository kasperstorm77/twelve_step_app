import 'dart:convert';
import 'dart:io';

import 'morning_randomizer_generator.dart';

/// Regenerates the bundled Just for Today catalog from Emotional Sobriety's
/// Workshop catalog — the only supported way to change that asset.
///
///     dart run tool/regenerate_morning_randomizer.dart
///     dart run tool/regenerate_morning_randomizer.dart --check
///     dart run tool/regenerate_morning_randomizer.dart --source <path>
///
/// `--check` writes nothing and exits 2 if the asset is out of date, which is
/// what you want on a machine that has both checkouts. The test suite runs the
/// same comparison against a captured fixture, so drift is caught even without
/// the sibling repo (plan P3.4).
const _defaultSource =
    '../emotional_sobriety/assets/defaults/workshop_exercises_v1.json';
const _assetPath = 'assets/content/morning_randomizer_v1.json';

Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');
  final sourceIndex = args.indexOf('--source');
  final sourcePath = sourceIndex >= 0 && sourceIndex + 1 < args.length
      ? args[sourceIndex + 1]
      : _defaultSource;

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Workshop catalog not found: $sourcePath');
    stderr.writeln(
      'Point --source at Emotional Sobriety\'s '
      'assets/defaults/workshop_exercises_v1.json.',
    );
    exit(1);
  }

  final workshop =
      jsonDecode(await sourceFile.readAsString()) as Map<String, dynamic>;
  final generated = buildCatalogJson(workshop);

  final asset = File(_assetPath);
  final current = asset.existsSync() ? await asset.readAsString() : '';

  if (current == generated) {
    stdout.writeln('$_assetPath is up to date with $sourcePath');
    return;
  }

  if (checkOnly) {
    stderr.writeln('$_assetPath is OUT OF DATE with $sourcePath');
    stderr.writeln('Run: dart run tool/regenerate_morning_randomizer.dart');
    exit(2);
  }

  await asset.writeAsString(generated);
  stdout.writeln('Wrote $_assetPath from $sourcePath');
  stdout.writeln(
    'Update test/fixtures/emotional_sobriety_workshop_v1.json in the same '
    'change so the drift test compares against the new upstream.',
  );
}
