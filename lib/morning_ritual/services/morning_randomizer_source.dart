import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Data-driven reading sources for randomized Morning Ritual prayer items.
///
/// The options are **not** Dart literals: they live in
/// `assets/content/morning_randomizer_v1.json`, whose option IDs and bilingual
/// text are the ones Emotional Sobriety froze for its `just_for_today`
/// Workshop exercise. A history snapshot written here therefore means the same
/// thing when the file is imported there, and vice versa.
abstract final class MorningRandomizerContract {
  /// The only source both apps currently ship. Stored in
  /// `RitualItem.randomizerSourceId` and travels through the shared JSON.
  static const justForTodaySourceId = 'just_for_today';

  static bool isRandomized(String? randomizerSourceId) =>
      randomizerSourceId != null && randomizerSourceId.trim().isNotEmpty;
}

/// One selectable reading. [id] is stable across locales and across the two
/// apps; [text] is the resolved copy for the requested locale.
@immutable
class MorningRandomizerOption {
  const MorningRandomizerOption({required this.id, required this.text});

  final String id;
  final String text;
}

/// A selection made once when a day's ritual starts, held for the whole run so
/// resume and "previous" never redraw it.
@immutable
class MorningRandomizerSelection {
  const MorningRandomizerSelection({
    required this.ritualItemId,
    required this.selectedContentId,
    required this.selectedContentText,
  });

  final String ritualItemId;
  final String selectedContentId;
  final String selectedContentText;

  Map<String, dynamic> toJson() => {
    'ritualItemId': ritualItemId,
    'selectedContentId': selectedContentId,
    'selectedContentText': selectedContentText,
  };

  /// Returns null for anything that isn't a complete selection, so a draft
  /// written by an older build (or a hand-edited one) degrades to "no
  /// selection" instead of throwing on resume.
  static MorningRandomizerSelection? fromJson(Object? json) {
    if (json is! Map) return null;
    final itemId = json['ritualItemId'];
    final contentId = json['selectedContentId'];
    final contentText = json['selectedContentText'];
    if (itemId is! String ||
        contentId is! String ||
        contentText is! String ||
        itemId.isEmpty ||
        contentId.isEmpty ||
        contentText.isEmpty) {
      return null;
    }
    return MorningRandomizerSelection(
      ritualItemId: itemId,
      selectedContentId: contentId,
      selectedContentText: contentText,
    );
  }
}

/// Loads and resolves the bundled randomizer catalog.
class MorningRandomizerSource {
  MorningRandomizerSource._();

  static const assetPath = 'assets/content/morning_randomizer_v1.json';
  static const _schemaVersion = 1;

  /// sourceId → localeCode → options (in catalog order).
  static Map<String, Map<String, List<MorningRandomizerOption>>>? _catalog;

  static bool get isLoaded => _catalog != null;

  /// The source IDs this build can resolve.
  static List<String> get availableSourceIds =>
      _catalog?.keys.toList(growable: false) ?? const [];

  /// Load the catalog once. Safe to call repeatedly; failures are swallowed so
  /// a missing or malformed asset degrades the feature instead of breaking the
  /// ritual (the runner falls back to the item's own `prayerText`).
  static Future<bool> ensureLoaded({AssetBundle? bundle}) async {
    if (_catalog != null) return true;
    try {
      final raw = await (bundle ?? rootBundle).loadString(assetPath);
      _catalog = _parse(raw);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('MorningRandomizerSource: failed to load $assetPath - $e');
      }
      return false;
    }
  }

  /// Options for [sourceId] in [localeCode], falling back to English and then
  /// to whatever the catalog has. Returns an empty list for an unknown source
  /// so an imported definition naming a source this build doesn't ship is
  /// preserved rather than rejected.
  static List<MorningRandomizerOption> optionsFor(
    String sourceId,
    String localeCode,
  ) {
    final byLocale = _catalog?[sourceId];
    if (byLocale == null || byLocale.isEmpty) return const [];
    return byLocale[localeCode] ?? byLocale['en'] ?? byLocale.values.first;
  }

  /// Resolve the text for a previously snapshotted option, so history recorded
  /// in one language can be re-rendered in the other. Returns null when the
  /// option is unknown here — callers keep the stored snapshot text.
  static String? textForOption(
    String sourceId,
    String optionId,
    String localeCode,
  ) {
    for (final option in optionsFor(sourceId, localeCode)) {
      if (option.id == optionId) return option.text;
    }
    return null;
  }

  @visibleForTesting
  static void resetForTest() => _catalog = null;

  @visibleForTesting
  static void loadFromStringForTest(String raw) => _catalog = _parse(raw);

  static Map<String, Map<String, List<MorningRandomizerOption>>> _parse(
    String raw,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Randomizer catalog root must be an object');
    }
    if (decoded['schemaVersion'] != _schemaVersion) {
      throw FormatException(
        'Unsupported randomizer catalog version: ${decoded['schemaVersion']}',
      );
    }
    final sources = decoded['sources'];
    if (sources is! List || sources.isEmpty) {
      throw const FormatException('Randomizer catalog needs a source list');
    }

    final catalog = <String, Map<String, List<MorningRandomizerOption>>>{};
    for (final rawSource in sources) {
      if (rawSource is! Map<String, dynamic>) {
        throw const FormatException('A randomizer source must be an object');
      }
      final sourceId = rawSource['id'];
      if (sourceId is! String || sourceId.trim().isEmpty) {
        throw const FormatException('A randomizer source needs an ID');
      }
      final rawOptions = rawSource['options'];
      if (rawOptions is! List || rawOptions.isEmpty) {
        throw FormatException('Randomizer source has no options: $sourceId');
      }

      // Catalog order is the option order; `order` is authoritative so the two
      // apps enumerate the same options in the same sequence.
      final ordered = [...rawOptions]
        ..sort(
          (a, b) => ((a as Map)['order'] as int).compareTo(
            ((b as Map)['order'] as int),
          ),
        );

      final byLocale = <String, List<MorningRandomizerOption>>{};
      final seenIds = <String>{};
      for (final rawOption in ordered) {
        final option = rawOption as Map<String, dynamic>;
        final optionId = option['id'];
        if (optionId is! String || optionId.trim().isEmpty) {
          throw FormatException('Randomizer option needs an ID: $sourceId');
        }
        if (!seenIds.add(optionId)) {
          throw FormatException('Duplicate randomizer option: $optionId');
        }
        final text = option['text'];
        if (text is! Map<String, dynamic> || text.isEmpty) {
          throw FormatException('Randomizer option needs text: $optionId');
        }
        for (final locale in text.keys) {
          final value = text[locale];
          if (value is! String || value.trim().isEmpty) {
            throw FormatException(
              'Randomizer option text must be non-blank: $optionId/$locale',
            );
          }
          (byLocale[locale] ??= <MorningRandomizerOption>[]).add(
            MorningRandomizerOption(id: optionId, text: value),
          );
        }
      }
      // Every option must exist in every locale the catalog claims, or a
      // Danish user would silently see a different set than an English one.
      final counts = byLocale.values.map((list) => list.length).toSet();
      if (!byLocale.containsKey('en') ||
          !byLocale.containsKey('da') ||
          counts.length != 1) {
        throw FormatException(
          'Randomizer source needs matching en + da options: $sourceId',
        );
      }
      catalog[sourceId] = {
        for (final entry in byLocale.entries)
          entry.key: List<MorningRandomizerOption>.unmodifiable(entry.value),
      };
    }
    return Map<String, Map<String, List<MorningRandomizerOption>>>.unmodifiable(
      catalog,
    );
  }
}
