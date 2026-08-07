import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/shared/app_identity.dart';
import 'package:twelvestepsapp/shared/localizations.dart';

/// The fellowship is never named — not in the app, not in the store, not in
/// its own literature by title.
///
/// A public listing or an in-app string that names it implies an affiliation
/// and an endorsement this app does not have. The concepts carry the meaning on
/// their own: step work, sponsor, moral inventory, amends, sobriety, higher
/// power. Citing the fellowship's book by name identifies it just as surely as
/// the initials do, which is how three help sections and the privacy policy
/// broke this rule while every obvious spelling was already absent.
///
/// This test covers what ships and what the public reads: every UI string, the
/// bundled assets, the store listing copy, and the privacy policy the store
/// pages link to.
void main() {
  // Word-boundary anchored so ordinary words survive: "an", "away", "aa" inside
  // a Danish compound, and so on.
  final forbidden = <String, RegExp>{
    'the initials': RegExp(r'\bA\.?A\.?\b'),
    'the full name': RegExp(r'alcoholics\s+anonymous', caseSensitive: false),
    'the Danish name': RegExp(r'anonyme\s+alkoholikere', caseSensitive: false),
    'a sibling fellowship': RegExp(r'narcotics\s+anonymous|\bN\.?A\.?\b'),
    'its book, in English': RegExp(r'big\s+book', caseSensitive: false),
    'its book, in Danish': RegExp(r'store\s+bog', caseSensitive: false),
  };

  void checkText(String label, String text) {
    forbidden.forEach((description, pattern) {
      final match = pattern.firstMatch(text);
      expect(
        match,
        isNull,
        reason:
            '$label names the fellowship ($description): '
            '"...${_around(text, match?.start ?? 0)}..."',
      );
    });
  }

  group('every user-visible string', () {
    for (final locale in const ['en', 'da']) {
      test('$locale strings never name it', () {
        final strings = localizedValues[locale]!;
        for (final entry in strings.entries) {
          checkText('$locale/${entry.key}', entry.value);
        }
      });
    }
  });

  test('bundled assets never name it', () {
    // These ship inside the app binary.
    final assets = Directory(
      'assets',
    ).listSync(recursive: true).whereType<File>();
    for (final file in assets) {
      if (file.path.endsWith('.png') || file.path.endsWith('.jpg')) continue;
      checkText(file.path, file.readAsStringSync());
    }
  });

  test('the store listing copy never names it', () {
    // What the public reads on Google Play and the App Store.
    checkText(
      'PLAY_STORE_DESCRIPTIONS.md',
      File(
        'docs/play_store-retain/PLAY_STORE_DESCRIPTIONS.md',
      ).readAsStringSync(),
    );
  });

  test('the privacy policy never names it', () {
    // Linked from both store pages, so it is as public as the listing.
    checkText(
      'PRIVACY_POLICY.md',
      File('PRIVACY_POLICY.md').readAsStringSync(),
    );
  });

  test('the readme never names it', () {
    checkText('README.md', File('README.md').readAsStringSync());
  });

  test('the guard actually catches the phrasings that got through', () {
    // Regression on the test itself: these are the real strings that shipped.
    for (final offender in const [
      'The Big Book (p.86) instructs: "Review the day."',
      'Den Store Bog (s.86-88) beskriver morgenmeditationen',
      'a recovery toolkit designed for the AA (Alcoholics Anonymous) program',
      'Sober member of AA',
      'following the Big Book method',
    ]) {
      expect(
        forbidden.values.any((p) => p.hasMatch(offender)),
        isTrue,
        reason: 'the guard must reject: $offender',
      );
    }
  });

  group('the app has exactly one name', () {
    // It has carried four at once: "12 Steps App" on the launcher,
    // "Twelve Steps app"/"Tolv Trins app" on the desktop window (off the
    // *system* locale, so a Danish UI could show an English title),
    // "12 Steps App - Recovery" staged on the App Store and
    // "12 Trins App - Værktøjer" briefly on Play.
    test('android:label matches', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:label="$appDisplayName"'));
    });

    test('CFBundleDisplayName matches', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final match = RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>',
      ).firstMatch(plist);
      expect(match?.group(1), appDisplayName);
    });

    test('the store listing titles match', () {
      final doc = File(
        'docs/play_store-retain/PLAY_STORE_DESCRIPTIONS.md',
      ).readAsStringSync();
      // Every "### Title (…)" / "### Name" block's fenced value.
      final titles = RegExp(
        r'###\s+(?:Title\s*\([^)]*\)|Name)[^\n]*\n+```\n([^\n]*)\n```',
      ).allMatches(doc).map((m) => m.group(1)!.trim()).toList();
      expect(titles, isNotEmpty, reason: 'no listing titles found to check');
      for (final title in titles) {
        expect(
          title,
          appDisplayName,
          reason: 'a store listing title must be the app name, untranslated',
        );
      }
    });

    test('no Dart file hardcodes a rival name', () {
      // app_identity.dart documents the old names in prose; everything else
      // must go through the constant.
      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        if (file.path.endsWith('app_identity.dart')) continue;
        final text = file.readAsStringSync();
        for (final rival in const [
          "'Twelve Steps app'",
          "'Tolv Trins app'",
          "'12 Steps App - Recovery'",
          "'12 Trins App",
        ]) {
          if (text.contains(rival)) offenders.add('${file.path}: $rival');
        }
      }
      expect(offenders, isEmpty);
    });
  });

  test('ordinary recovery language still passes', () {
    // The rule is about naming the fellowship, not about the concepts.
    for (final allowed in const [
      'Follow your sponsor\'s guidance for step work.',
      'a searching and fearless moral inventory',
      'twelve step recovery',
      'Your higher power',
      'This supplements the traditional methods.',
      'Aftenritual - en daglig gennemgang',
      'Vi arbejder videre', // contains "aa"? no — guards against over-matching
    ]) {
      expect(
        forbidden.values.any((p) => p.hasMatch(allowed)),
        isFalse,
        reason: 'the guard must not reject: $allowed',
      );
    }
  });
}

String _around(String text, int index) {
  final start = (index - 40).clamp(0, text.length);
  final end = (index + 40).clamp(0, text.length);
  return text.substring(start, end).replaceAll('\n', ' ');
}
