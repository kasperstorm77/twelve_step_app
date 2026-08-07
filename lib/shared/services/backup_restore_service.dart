import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/services/inventory_service.dart';
import '../../eighth_step/models/person.dart';
import '../../evening_ritual/models/reflection_entry.dart';
import '../../gratitude/models/gratitude_entry.dart';
import '../../agnosticism/models/barrier_power_pair.dart';
import '../../agnosticism/services/agnosticism_service.dart';
import '../../morning_ritual/models/ritual_item.dart';
import '../../morning_ritual/models/morning_ritual_entry.dart';
import '../../morning_ritual/services/morning_randomizer_source.dart';
import '../../morning_ritual/services/morning_ritual_service.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notifications_service.dart';
import 'app_settings_service.dart';
import 'data_refresh_service.dart';
import 'local_backup_service.dart';

// --------------------------------------------------------------------------
// Backup Restore Service - Unified Import/Restore Logic
// --------------------------------------------------------------------------
//
// Single source of truth for restoring/importing backup data.
// Used by: Drive restore, local backup restore, JSON file import.
//
// Features:
// - Validates payload structure before any destructive operation
// - Creates automatic safety backup before restore
// - Handles backwards compatibility with old schema versions
// - Provides consistent restore behavior across all platforms
// --------------------------------------------------------------------------

/// Result of payload validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  String toString() =>
      'ValidationResult(isValid: $isValid, errors: $errors, warnings: $warnings)';
}

/// Result of restore operation
class RestoreResult {
  final bool success;
  final String? error;
  final RestoreCounts counts;

  const RestoreResult({
    required this.success,
    this.error,
    this.counts = const RestoreCounts(),
  });

  @override
  String toString() =>
      'RestoreResult(success: $success, error: $error, counts: $counts)';
}

/// What a foreign (other-product) payload would bring in, so the confirmation
/// dialog can name exactly which datasets are replaced before anything is
/// touched.
class ForeignImportSummary {
  const ForeignImportSummary({
    required this.product,
    required this.version,
    required this.sectionCounts,
    required this.ignoredSections,
  });

  /// The `product` tag on the file, e.g. `emotional-sobriety`.
  final String product;

  /// The foreign schema version, e.g. `1.0`.
  final String? version;

  /// Canonical section key → number of records, for the sections this app
  /// models. A section absent from the file is absent here and its box is left
  /// alone.
  final Map<String, int> sectionCounts;

  /// Sections present in the file that this app has no home for. They are
  /// skipped; they never fail the import.
  final List<String> ignoredSections;
}

/// Counts of restored items per category
class RestoreCounts {
  final int entries;
  final int iAmDefinitions;
  final int people;
  final int reflections;
  final int gratitude;
  final int agnosticism;
  final int morningRitualItems;
  final int morningRitualEntries;
  final int notifications;
  final bool hasAppSettings;

  /// Records that could not be decoded and were left out. Always 0 for a
  /// payload this app wrote; a foreign file can carry a record this app has no
  /// shape for, and dropping it beats failing the whole import.
  final int skippedRecords;

  const RestoreCounts({
    this.entries = 0,
    this.iAmDefinitions = 0,
    this.people = 0,
    this.reflections = 0,
    this.gratitude = 0,
    this.agnosticism = 0,
    this.morningRitualItems = 0,
    this.morningRitualEntries = 0,
    this.notifications = 0,
    this.hasAppSettings = false,
    this.skippedRecords = 0,
  });

  @override
  String toString() =>
      'RestoreCounts(entries: $entries, iAms: $iAmDefinitions, people: $people, '
      'reflections: $reflections, gratitude: $gratitude, agnosticism: $agnosticism, '
      'ritualItems: $morningRitualItems, ritualEntries: $morningRitualEntries, '
      'notifications: $notifications, appSettings: $hasAppSettings, '
      'skipped: $skippedRecords)';
}

/// A section decoded ahead of the destructive write, so a record this app
/// cannot read never leaves a box half-rewritten.
class _DecodedSection<T> {
  const _DecodedSection(this.items, this.skipped);

  final List<T> items;
  final int skipped;
}

/// Centralized service for restoring/importing backup data
class BackupRestoreService {
  BackupRestoreService._();

  // ---------------------------------------------------------------------------
  // Known schema keys (current and legacy)
  // ---------------------------------------------------------------------------

  /// All known data keys (for validation)
  static const _knownDataKeys = [
    'entries',
    'iAmDefinitions',
    'people',
    'reflections',
    'gratitude',
    'gratitudeEntries', // Legacy key (pre-v6.0)
    'agnosticism',
    'agnosticismPapers', // Legacy key (pre-v6.0)
    'morningRitualItems',
    'morningRitualEntries',
    'notifications',
    'appSettings',
  ];

  /// Keys that should be lists
  static const _listKeys = [
    'entries',
    'iAmDefinitions',
    'people',
    'reflections',
    'gratitude',
    'gratitudeEntries',
    'agnosticism',
    'agnosticismPapers',
    'morningRitualItems',
    'morningRitualEntries',
    'notifications',
  ];

  // ---------------------------------------------------------------------------
  // Foreign (other-product) payloads
  // ---------------------------------------------------------------------------
  //
  // Emotional Sobriety writes a *different envelope*, not a newer version of
  // this one: it tags itself `"product": "emotional-sobriety"`, `"version":
  // "1.0"`, and names its agnosticism section `agnosticismPairs`. Five of its
  // sections mean the same thing here; the rest (Workshop progress, the Morning
  // draft, its own settings) have no home and are ignored.
  //
  // This app never writes a `product` key, so its own backups are, and stay,
  // "not foreign". Importing another product is an explicit user choice on the
  // manual JSON path only — the automatic Drive path passes
  // `allowForeignProduct: false`, which keeps `isRemoteNewer()` unable to act
  // on someone else's file (hard rule 8).

  static const emotionalSobrietyProductId = 'emotional-sobriety';

  /// Foreign sections mapped onto this app's canonical keys.
  static const _emotionalSobrietySectionMap = <String, String>{
    'iAmDefinitions': 'iAmDefinitions',
    'entries': 'entries',
    'agnosticismPairs': 'agnosticism',
    'morningRitualItems': 'morningRitualItems',
    'morningRitualEntries': 'morningRitualEntries',
  };

  /// Foreign sections this app deliberately drops.
  static const _emotionalSobrietyIgnoredSections = <String>[
    'workshopProgress',
    'morningRitualDraft',
    'emotionalSobrietySettings',
  ];

  /// The `product` tag of [data], or null when the payload is this app's own.
  static String? foreignProductOf(Map<String, dynamic> data) {
    final product = data['product'];
    if (product is! String || product.trim().isEmpty) return null;
    return product.trim();
  }

  /// True when [data] is a payload this app can import via the manual path
  /// after the user confirms.
  static bool isSupportedForeignPayload(Map<String, dynamic> data) =>
      foreignProductOf(data) == emotionalSobrietyProductId;

  /// Describe a foreign payload without touching any box, so the confirmation
  /// dialog can name exactly what will be replaced. Returns null when [data]
  /// is not a foreign payload this app supports.
  static ForeignImportSummary? describeForeignPayload(
    Map<String, dynamic> data,
  ) {
    if (!isSupportedForeignPayload(data)) return null;
    final counts = <String, int>{};
    for (final entry in _emotionalSobrietySectionMap.entries) {
      final value = data[entry.key];
      if (value is List) counts[entry.value] = value.length;
    }
    final ignored = _emotionalSobrietyIgnoredSections
        .where((key) => data[key] != null)
        .toList(growable: false);
    final version = data['version'];
    return ForeignImportSummary(
      product: emotionalSobrietyProductId,
      version: version is String ? version : null,
      sectionCounts: counts,
      ignoredSections: ignored,
    );
  }

  /// Rewrite an Emotional Sobriety payload into this app's canonical shape.
  ///
  /// Only the five shared sections survive. Sections this app owns but the
  /// other product does not (people, reflections, gratitude, notifications,
  /// appSettings) are deliberately *absent* rather than empty, so a restore
  /// leaves those boxes untouched instead of clearing data the other app never
  /// had.
  static Map<String, dynamic> translateEmotionalSobrietyPayload(
    Map<String, dynamic> data,
  ) {
    final translated = <String, dynamic>{
      // The restore path validates against this app's schema; the foreign
      // version is reported separately by [describeForeignPayload].
      'version': '8.0',
    };
    for (final entry in _emotionalSobrietySectionMap.entries) {
      final value = data[entry.key];
      if (value is List) translated[entry.value] = value;
    }
    final lastModified = data['lastModified'];
    if (lastModified is String) translated['lastModified'] = lastModified;
    return translated;
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Validate payload structure before any destructive operation.
  ///
  /// This is permissive validation - only fails on malformed data,
  /// not missing optional fields (for backwards compatibility).
  static ValidationResult validate(Map<String, dynamic> data) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check for version (informational only - old backups may not have it)
    if (!data.containsKey('version')) {
      warnings.add('Backup has no version field (may be very old format)');
    }

    // Must have at least SOME recognizable data
    final hasAnyData = _knownDataKeys.any((key) => data.containsKey(key));
    if (!hasAnyData) {
      errors.add('Backup contains no recognizable data');
    }

    // Type checks - only fail if present AND wrong type
    for (final key in _listKeys) {
      if (data.containsKey(key)) {
        final value = data[key];
        if (value != null && value is! List) {
          errors.add('$key must be a list, got ${value.runtimeType}');
        }
      }
    }

    // appSettings should be a Map if present
    if (data.containsKey('appSettings')) {
      final value = data['appSettings'];
      if (value != null && value is! Map) {
        errors.add('appSettings must be a map, got ${value.runtimeType}');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Parse JSON string into Map, with error handling
  static Map<String, dynamic>? parseJson(String content) {
    try {
      final decoded = json.decode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (kDebugMode) print('BackupRestoreService: JSON is not a Map');
      return null;
    } catch (e) {
      if (kDebugMode) print('BackupRestoreService: JSON parse error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pre-Restore Safety Backup
  // ---------------------------------------------------------------------------

  /// Create a safety snapshot before restore.
  /// This allows rollback if something goes wrong.
  static Future<void> createPreRestoreSafetyBackup() async {
    try {
      if (kDebugMode) {
        print('BackupRestoreService: Creating pre-restore safety backup...');
      }
      await LocalBackupService.instance.createBackupNow();
      if (kDebugMode) print('BackupRestoreService: Safety backup created');
    } catch (e) {
      // Don't fail the restore if safety backup fails - just log it
      if (kDebugMode) {
        print(
          'BackupRestoreService: Safety backup failed (continuing anyway): $e',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Full Restore Flow
  // ---------------------------------------------------------------------------

  /// Full restore flow: validate → safety backup → apply → update lastModified.
  ///
  /// [data] - The parsed backup payload
  /// [createSafetyBackup] - Whether to create a local backup before restoring
  ///
  /// Returns [RestoreResult] with success status and counts
  static Future<RestoreResult> restoreFromPayload(
    Map<String, dynamic> data, {
    bool createSafetyBackup = true,
    bool allowForeignProduct = false,
  }) async {
    // Step 0: Foreign payloads are accepted only where the user explicitly
    // chose the file. The automatic Drive path never sets the flag.
    final foreignProduct = foreignProductOf(data);
    if (foreignProduct != null) {
      if (!allowForeignProduct) {
        return RestoreResult(
          success: false,
          error:
              'Backup belongs to another app ($foreignProduct); '
              'import it explicitly from a JSON file',
        );
      }
      if (foreignProduct != emotionalSobrietyProductId) {
        return RestoreResult(
          success: false,
          error: 'Unsupported backup product: $foreignProduct',
        );
      }
      data = translateEmotionalSobrietyPayload(data);
    }

    // Step 1: Validate
    final validation = validate(data);
    if (!validation.isValid) {
      return RestoreResult(
        success: false,
        error: 'Validation failed: ${validation.errors.join(', ')}',
      );
    }

    if (validation.warnings.isNotEmpty && kDebugMode) {
      debugPrint(
        'BackupRestoreService: Validation warnings: ${validation.warnings}',
      );
    }

    // Step 2: Safety backup (before any destructive operation)
    if (createSafetyBackup) {
      await createPreRestoreSafetyBackup();
    }

    // Step 3: Apply payload
    try {
      final counts = await _applyPayload(data);

      // Step 4: Update lastModified if present
      if (data.containsKey('lastModified')) {
        try {
          final lastModified = DateTime.parse(data['lastModified'] as String);
          final settingsBox = Hive.box('settings');
          await settingsBox.put('lastModified', lastModified.toIso8601String());
          if (kDebugMode) {
            print(
              'BackupRestoreService: Saved lastModified: ${lastModified.toIso8601String()}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('BackupRestoreService: Failed to save lastModified: $e');
          }
        }
      }

      // Step 5: Notify UI to refresh
      try {
        Modular.get<DataRefreshService>().notifyDataRestored();
      } catch (e) {
        // DataRefreshService might not be available in all contexts
        if (kDebugMode) {
          print('BackupRestoreService: DataRefreshService notify failed: $e');
        }
      }

      return RestoreResult(success: true, counts: counts);
    } catch (e) {
      if (kDebugMode) print('BackupRestoreService: Restore failed: $e');
      return RestoreResult(success: false, error: e.toString());
    }
  }

  /// Restore from JSON string (convenience method)
  static Future<RestoreResult> restoreFromJsonString(
    String content, {
    bool createSafetyBackup = true,
    bool allowForeignProduct = false,
  }) async {
    final data = parseJson(content);
    if (data == null) {
      return const RestoreResult(
        success: false,
        error: 'Failed to parse JSON content',
      );
    }
    return restoreFromPayload(
      data,
      createSafetyBackup: createSafetyBackup,
      allowForeignProduct: allowForeignProduct,
    );
  }

  // ---------------------------------------------------------------------------
  // Apply Payload (Internal)
  // ---------------------------------------------------------------------------

  /// Apply validated payload to all Hive boxes.
  ///
  /// IMPORTANT: This clears boxes before writing. Validation and safety
  /// backup should be done BEFORE calling this method.
  ///
  /// Each section is **decoded before its box is cleared**. A record this app
  /// cannot read is left out and counted, instead of throwing part-way through
  /// a rewrite and leaving the box holding a fraction of the backup — with the
  /// rest of the payload never applied. That mattered as soon as foreign files
  /// became importable, but it protects this app's own backups too.
  ///
  /// A section absent from the payload leaves its box untouched. An Emotional
  /// Sobriety file carries no people/reflections/gratitude/notifications, so
  /// importing one adds its five datasets and keeps the rest of this app's
  /// data.
  static Future<RestoreCounts> _applyPayload(Map<String, dynamic> data) async {
    int entriesCount = 0;
    int iAmCount = 0;
    int peopleCount = 0;
    int reflectionsCount = 0;
    int gratitudeCount = 0;
    int agnosticismCount = 0;
    int ritualItemsCount = 0;
    int ritualEntriesCount = 0;
    int notificationsCount = 0;
    int skippedRecords = 0;
    bool hasAppSettings = false;

    // ---------------------------------------------------------------------------
    // I Am Definitions (MUST be imported FIRST - entries reference them)
    // ---------------------------------------------------------------------------
    final iAmSection = _decodeSection<IAmDefinition>(
      data['iAmDefinitions'],
      'iAmDefinitions',
      (json) => IAmDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        reasonToExist: json['reasonToExist'] as String?,
      ),
    );
    if (iAmSection != null) {
      skippedRecords += iAmSection.skipped;
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      await iAmBox.clear();
      for (final def in iAmSection.items) {
        await iAmBox.add(def);
      }
      iAmCount = iAmBox.length;
    }

    // ---------------------------------------------------------------------------
    // Inventory Entries (4th Step)
    // ---------------------------------------------------------------------------
    final entriesSection = _decodeSection<InventoryEntry>(
      data['entries'],
      'entries',
      InventoryEntry.fromJson,
    );
    if (entriesSection != null) {
      skippedRecords += entriesSection.skipped;
      final entriesBox = Hive.box<InventoryEntry>('entries');
      await entriesBox.clear();
      for (final entry in entriesSection.items) {
        await entriesBox.add(entry);
      }
      entriesCount = entriesBox.length;
      // Migrate order values for backwards compatibility
      await InventoryService.migrateOrderValues();
    }

    // ---------------------------------------------------------------------------
    // People (8th Step)
    // ---------------------------------------------------------------------------
    final peopleSection = _decodeSection<Person>(
      data['people'],
      'people',
      Person.fromJson,
    );
    if (peopleSection != null) {
      skippedRecords += peopleSection.skipped;
      final peopleBox = Hive.box<Person>('people_box');
      await peopleBox.clear();
      for (final person in peopleSection.items) {
        await peopleBox.put(person.internalId, person);
      }
      peopleCount = peopleBox.length;
    }

    // ---------------------------------------------------------------------------
    // Reflections (Evening Ritual)
    // ---------------------------------------------------------------------------
    final reflectionsSection = _decodeSection<ReflectionEntry>(
      data['reflections'],
      'reflections',
      ReflectionEntry.fromJson,
    );
    if (reflectionsSection != null) {
      skippedRecords += reflectionsSection.skipped;
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
      await reflectionsBox.clear();
      for (final reflection in reflectionsSection.items) {
        await reflectionsBox.put(reflection.internalId, reflection);
      }
      reflectionsCount = reflectionsBox.length;
    }

    // ---------------------------------------------------------------------------
    // Gratitude (supports legacy 'gratitudeEntries' key)
    // ---------------------------------------------------------------------------
    final gratitudeSection = _decodeSection<GratitudeEntry>(
      data['gratitude'] ?? data['gratitudeEntries'],
      'gratitude',
      GratitudeEntry.fromJson,
    );
    if (gratitudeSection != null) {
      skippedRecords += gratitudeSection.skipped;
      final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
      await gratitudeBox.clear();
      for (final gratitude in gratitudeSection.items) {
        await gratitudeBox.add(gratitude);
      }
      gratitudeCount = gratitudeBox.length;
    }

    // ---------------------------------------------------------------------------
    // Agnosticism (supports legacy 'agnosticismPapers' key; Emotional Sobriety's
    // 'agnosticismPairs' is mapped onto 'agnosticism' before we get here)
    // ---------------------------------------------------------------------------
    final agnosticismSection = _decodeSection<BarrierPowerPair>(
      data['agnosticism'] ?? data['agnosticismPapers'],
      'agnosticism',
      BarrierPowerPair.fromJson,
    );
    if (agnosticismSection != null) {
      skippedRecords += agnosticismSection.skipped;
      final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      await agnosticismBox.clear();
      for (final pair in _withEnforcedActivePairCap(agnosticismSection.items)) {
        await agnosticismBox.put(pair.id, pair);
      }
      agnosticismCount = agnosticismBox.length;
    }

    // ---------------------------------------------------------------------------
    // Morning Ritual Items (Definitions)
    // ---------------------------------------------------------------------------
    final ritualItemsSection = _decodeSection<RitualItem>(
      data['morningRitualItems'],
      'morningRitualItems',
      RitualItem.fromJson,
    );
    if (ritualItemsSection != null) {
      skippedRecords += ritualItemsSection.skipped;
      final morningRitualItemsBox = Hive.box<RitualItem>(
        'morning_ritual_items',
      );
      await morningRitualItemsBox.clear();
      for (final item in _withSingleRandomizedReading(
        ritualItemsSection.items,
      )) {
        await morningRitualItemsBox.put(item.id, item);
      }
      ritualItemsCount = morningRitualItemsBox.length;
      // An imported set can arrive with gaps or duplicate sort orders; the
      // shared contract needs them contiguous from zero before the next export.
      await MorningRitualService.migrateSortOrders();
    }

    // ---------------------------------------------------------------------------
    // Morning Ritual Entries (Daily Completions)
    // ---------------------------------------------------------------------------
    final ritualEntriesSection = _decodeSection<MorningRitualEntry>(
      data['morningRitualEntries'],
      'morningRitualEntries',
      MorningRitualEntry.fromJson,
    );
    if (ritualEntriesSection != null) {
      skippedRecords += ritualEntriesSection.skipped;
      final morningRitualEntriesBox = Hive.box<MorningRitualEntry>(
        'morning_ritual_entries',
      );
      await morningRitualEntriesBox.clear();
      for (final entry in ritualEntriesSection.items) {
        await morningRitualEntriesBox.put(entry.id, entry);
      }
      ritualEntriesCount = morningRitualEntriesBox.length;
    }

    // ---------------------------------------------------------------------------
    // Notifications
    // ---------------------------------------------------------------------------
    final notificationsSection = _decodeSection<AppNotification>(
      data['notifications'],
      'notifications',
      AppNotification.fromJson,
    );
    if (notificationsSection != null) {
      skippedRecords += notificationsSection.skipped;
      final notificationsBox = Hive.box<AppNotification>(
        NotificationsService.notificationsBoxName,
      );
      await notificationsBox.clear();
      for (final n in notificationsSection.items) {
        await notificationsBox.put(n.id, n);
      }
      notificationsCount = notificationsBox.length;
      // Re-register the imported reminders with the OS. This is a side effect,
      // not part of storing the data: it can fail for reasons that have nothing
      // to do with the backup (notification permission revoked, no timezone
      // database, a platform with no plugin implementation). Unguarded, that
      // threw out of the middle of _applyPayload and the whole restore reported
      // failure — with every box up to here already rewritten and `appSettings`
      // never applied. The records are safe on disk either way; the worst case
      // is a reminder that re-registers on next launch.
      try {
        await NotificationsService.rescheduleAll();
      } catch (e) {
        if (kDebugMode) {
          print('BackupRestoreService: rescheduleAll failed after import - $e');
        }
      }
    }

    // ---------------------------------------------------------------------------
    // App Settings (v8.0+)
    // ---------------------------------------------------------------------------
    if (data.containsKey('appSettings')) {
      final appSettingsData = data['appSettings'];
      if (appSettingsData is Map<String, dynamic>) {
        if (kDebugMode) print('BackupRestoreService: Importing app settings');
        await AppSettingsService.importFromSync(appSettingsData);
        hasAppSettings = true;
      }
    }

    return RestoreCounts(
      entries: entriesCount,
      iAmDefinitions: iAmCount,
      people: peopleCount,
      reflections: reflectionsCount,
      gratitude: gratitudeCount,
      agnosticism: agnosticismCount,
      morningRitualItems: ritualItemsCount,
      morningRitualEntries: ritualEntriesCount,
      notifications: notificationsCount,
      hasAppSettings: hasAppSettings,
      skippedRecords: skippedRecords,
    );
  }

  /// Decode one payload section up front. Returns null when the section is
  /// absent or null (leave that box alone); an empty list is a real instruction
  /// to clear the box.
  static _DecodedSection<T>? _decodeSection<T>(
    Object? raw,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (raw == null) return null;
    if (raw is! List) return null;
    final items = <T>[];
    var skipped = 0;
    for (final entry in raw) {
      if (entry is! Map) {
        skipped += 1;
        continue;
      }
      try {
        items.add(decode(Map<String, dynamic>.from(entry)));
      } catch (e) {
        skipped += 1;
        if (kDebugMode) {
          print('BackupRestoreService: Skipped an unreadable $key record: $e');
        }
      }
    }
    if (kDebugMode) {
      print(
        'BackupRestoreService: Importing ${items.length} $key records '
        '($skipped skipped)',
      );
    }
    return _DecodedSection<T>(items, skipped);
  }

  /// Keep this app's five-active-pair rule true for any imported set.
  ///
  /// Excess active pairs are **archived, never dropped** — they are the
  /// person's work, and another app may allow a larger paper. Active positions
  /// are then compacted to 0..n so the paper renders in a stable order.
  static List<BarrierPowerPair> _withEnforcedActivePairCap(
    List<BarrierPowerPair> pairs,
  ) {
    final active = pairs.where((pair) => !pair.isArchived).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final keep = active.take(AgnosticismService.maxActivePairs).toSet();

    var nextPosition = 0;
    return pairs
        .map((pair) {
          if (pair.isArchived) return pair;
          if (keep.contains(pair)) {
            return pair.copyWith(position: nextPosition++);
          }
          return pair.copyWith(
            isArchived: true,
            archivedAt: pair.archivedAt ?? pair.createdAt,
          );
        })
        .toList(growable: false);
  }

  /// Emotional Sobriety rejects a backup carrying two randomized readings, so
  /// only the first survives as one. The extras keep every other field and
  /// simply become ordinary prayer items.
  static List<RitualItem> _withSingleRandomizedReading(List<RitualItem> items) {
    var seenRandomized = false;
    return items
        .map((item) {
          if (!MorningRandomizerContract.isRandomized(
            item.randomizerSourceId,
          )) {
            return item;
          }
          if (!seenRandomized) {
            seenRandomized = true;
            return item;
          }
          return item.copyWith(clearRandomizerSourceId: true);
        })
        .toList(growable: false);
  }
}
