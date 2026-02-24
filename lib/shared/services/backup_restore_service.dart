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
import '../../morning_ritual/models/ritual_item.dart';
import '../../morning_ritual/models/morning_ritual_entry.dart';
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
  String toString() => 'ValidationResult(isValid: $isValid, errors: $errors, warnings: $warnings)';
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
  String toString() => 'RestoreResult(success: $success, error: $error, counts: $counts)';
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
  });

  @override
  String toString() => 'RestoreCounts(entries: $entries, iAms: $iAmDefinitions, people: $people, '
      'reflections: $reflections, gratitude: $gratitude, agnosticism: $agnosticism, '
      'ritualItems: $morningRitualItems, ritualEntries: $morningRitualEntries, '
      'notifications: $notifications, appSettings: $hasAppSettings)';
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
      if (kDebugMode) print('BackupRestoreService: Creating pre-restore safety backup...');
      await LocalBackupService.instance.createBackupNow();
      if (kDebugMode) print('BackupRestoreService: Safety backup created');
    } catch (e) {
      // Don't fail the restore if safety backup fails - just log it
      if (kDebugMode) print('BackupRestoreService: Safety backup failed (continuing anyway): $e');
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
  }) async {
    // Step 1: Validate
    final validation = validate(data);
    if (!validation.isValid) {
      return RestoreResult(
        success: false,
        error: 'Validation failed: ${validation.errors.join(', ')}',
      );
    }

    if (validation.warnings.isNotEmpty && kDebugMode) {
      debugPrint('BackupRestoreService: Validation warnings: ${validation.warnings}');
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
            print('BackupRestoreService: Saved lastModified: ${lastModified.toIso8601String()}');
          }
        } catch (e) {
          if (kDebugMode) print('BackupRestoreService: Failed to save lastModified: $e');
        }
      }

      // Step 5: Notify UI to refresh
      try {
        Modular.get<DataRefreshService>().notifyDataRestored();
      } catch (e) {
        // DataRefreshService might not be available in all contexts
        if (kDebugMode) print('BackupRestoreService: DataRefreshService notify failed: $e');
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
  }) async {
    final data = parseJson(content);
    if (data == null) {
      return const RestoreResult(
        success: false,
        error: 'Failed to parse JSON content',
      );
    }
    return restoreFromPayload(data, createSafetyBackup: createSafetyBackup);
  }

  // ---------------------------------------------------------------------------
  // Apply Payload (Internal)
  // ---------------------------------------------------------------------------

  /// Apply validated payload to all Hive boxes.
  /// 
  /// IMPORTANT: This clears boxes before writing. Validation and safety
  /// backup should be done BEFORE calling this method.
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
    bool hasAppSettings = false;

    // ---------------------------------------------------------------------------
    // I Am Definitions (MUST be imported FIRST - entries reference them)
    // ---------------------------------------------------------------------------
    if (data.containsKey('iAmDefinitions')) {
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefs = data['iAmDefinitions'] as List<dynamic>?;
      if (iAmDefs != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${iAmDefs.length} I Am definitions');
        await iAmBox.clear();
        for (final defJson in iAmDefs) {
          final def = IAmDefinition(
            id: defJson['id'] as String,
            name: defJson['name'] as String,
            reasonToExist: defJson['reasonToExist'] as String?,
          );
          await iAmBox.add(def);
        }
        iAmCount = iAmBox.length;
        if (kDebugMode) print('BackupRestoreService: I Am box now has $iAmCount definitions');
      }
    }

    // ---------------------------------------------------------------------------
    // Inventory Entries (4th Step)
    // ---------------------------------------------------------------------------
    if (data.containsKey('entries')) {
      final entriesBox = Hive.box<InventoryEntry>('entries');
      final entries = data['entries'] as List<dynamic>?;
      if (entries != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${entries.length} entries');
        await entriesBox.clear();
        for (final item in entries) {
          if (item is Map<String, dynamic>) {
            final entry = InventoryEntry.fromJson(item);
            await entriesBox.add(entry);
          }
        }
        entriesCount = entriesBox.length;
        // Migrate order values for backwards compatibility
        await InventoryService.migrateOrderValues();
        if (kDebugMode) print('BackupRestoreService: Entries box now has $entriesCount entries');
      }
    }

    // ---------------------------------------------------------------------------
    // People (8th Step)
    // ---------------------------------------------------------------------------
    if (data.containsKey('people')) {
      final peopleBox = Hive.box<Person>('people_box');
      final peopleList = data['people'] as List<dynamic>?;
      if (peopleList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${peopleList.length} people');
        await peopleBox.clear();
        for (final personJson in peopleList) {
          final person = Person.fromJson(personJson as Map<String, dynamic>);
          await peopleBox.put(person.internalId, person);
        }
        peopleCount = peopleBox.length;
      }
    }

    // ---------------------------------------------------------------------------
    // Reflections (Evening Ritual)
    // ---------------------------------------------------------------------------
    if (data.containsKey('reflections')) {
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
      final reflectionsList = data['reflections'] as List<dynamic>?;
      if (reflectionsList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${reflectionsList.length} reflections');
        await reflectionsBox.clear();
        for (final reflectionJson in reflectionsList) {
          final reflection = ReflectionEntry.fromJson(reflectionJson as Map<String, dynamic>);
          await reflectionsBox.put(reflection.internalId, reflection);
        }
        reflectionsCount = reflectionsBox.length;
      }
    }

    // ---------------------------------------------------------------------------
    // Gratitude (supports legacy 'gratitudeEntries' key)
    // ---------------------------------------------------------------------------
    if (data.containsKey('gratitude') || data.containsKey('gratitudeEntries')) {
      final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
      final gratitudeList = (data['gratitude'] ?? data['gratitudeEntries']) as List<dynamic>?;
      if (gratitudeList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${gratitudeList.length} gratitude entries');
        await gratitudeBox.clear();
        for (final gratitudeJson in gratitudeList) {
          final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
          await gratitudeBox.add(gratitude);
        }
        gratitudeCount = gratitudeBox.length;
      }
    }

    // ---------------------------------------------------------------------------
    // Agnosticism (supports legacy 'agnosticismPapers' key)
    // ---------------------------------------------------------------------------
    if (data.containsKey('agnosticism') || data.containsKey('agnosticismPapers')) {
      final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      final pairsList = (data['agnosticism'] ?? data['agnosticismPapers']) as List<dynamic>?;
      if (pairsList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${pairsList.length} agnosticism pairs');
        await agnosticismBox.clear();
        for (final pairJson in pairsList) {
          final pair = BarrierPowerPair.fromJson(pairJson as Map<String, dynamic>);
          await agnosticismBox.put(pair.id, pair);
        }
        agnosticismCount = agnosticismBox.length;
      }
    }

    // ---------------------------------------------------------------------------
    // Morning Ritual Items (Definitions)
    // ---------------------------------------------------------------------------
    if (data.containsKey('morningRitualItems')) {
      final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
      final itemsList = data['morningRitualItems'] as List<dynamic>?;
      if (itemsList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${itemsList.length} morning ritual items');
        await morningRitualItemsBox.clear();
        for (final itemJson in itemsList) {
          final item = RitualItem.fromJson(itemJson as Map<String, dynamic>);
          await morningRitualItemsBox.put(item.id, item);
        }
        ritualItemsCount = morningRitualItemsBox.length;
      }
    }

    // ---------------------------------------------------------------------------
    // Morning Ritual Entries (Daily Completions)
    // ---------------------------------------------------------------------------
    if (data.containsKey('morningRitualEntries')) {
      final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');
      final entriesList = data['morningRitualEntries'] as List<dynamic>?;
      if (entriesList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${entriesList.length} morning ritual entries');
        await morningRitualEntriesBox.clear();
        for (final entryJson in entriesList) {
          final entry = MorningRitualEntry.fromJson(entryJson as Map<String, dynamic>);
          await morningRitualEntriesBox.put(entry.id, entry);
        }
        ritualEntriesCount = morningRitualEntriesBox.length;
      }
    }

    // ---------------------------------------------------------------------------
    // Notifications
    // ---------------------------------------------------------------------------
    if (data.containsKey('notifications')) {
      final notificationsBox = Hive.box<AppNotification>(NotificationsService.notificationsBoxName);
      final notificationsList = data['notifications'] as List<dynamic>?;
      if (notificationsList != null) {
        if (kDebugMode) print('BackupRestoreService: Importing ${notificationsList.length} notifications');
        await notificationsBox.clear();
        for (final nJson in notificationsList) {
          final n = AppNotification.fromJson(nJson as Map<String, dynamic>);
          await notificationsBox.put(n.id, n);
        }
        notificationsCount = notificationsBox.length;
        // Reschedule all notifications
        await NotificationsService.rescheduleAll();
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
    );
  }
}
