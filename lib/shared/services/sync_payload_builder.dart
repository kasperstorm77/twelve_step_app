import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../eighth_step/models/person.dart';
import '../../evening_ritual/models/reflection_entry.dart';
import '../../morning_ritual/models/ritual_item.dart';
import '../../morning_ritual/models/morning_ritual_entry.dart';
import '../../gratitude/models/gratitude_entry.dart';
import '../../agnosticism/models/barrier_power_pair.dart';
import '../../notifications/models/app_notification.dart';
import 'app_settings_service.dart';

// --------------------------------------------------------------------------
// Sync Payload Builder - Centralized JSON Export
// --------------------------------------------------------------------------
// 
// Single source of truth for building the Drive sync JSON payload.
// Used by AllAppsDriveService for both immediate and debounced uploads.
// --------------------------------------------------------------------------

/// Centralized builder for sync/export JSON payload.
/// Single source of truth for schema version and field mapping.
class SyncPayloadBuilder {
  /// Current schema version for sync JSON format
  static const String schemaVersion = '8.0';

  /// Build the complete export payload from all Hive boxes.
  /// 
  /// [entriesBox] is optional; if null, uses the default 'entries' box.
  /// Returns a Map that can be encoded to JSON.
  static Map<String, dynamic> buildPayload({Box<InventoryEntry>? entriesBox}) {
    final now = DateTime.now().toUtc();

    return {
      'version': schemaVersion,
      'exportDate': now.toIso8601String(),
      'lastModified': now.toIso8601String(),
      'iAmDefinitions': _exportIAmDefinitions(),
      'entries': _exportEntries(entriesBox),
      'people': _exportPeople(),
      'reflections': _exportReflections(),
      'gratitude': _exportGratitude(),
      'agnosticism': _exportAgnosticism(),
      'morningRitualItems': _exportMorningRitualItems(),
      'morningRitualEntries': _exportMorningRitualEntries(),
      'notifications': _exportNotifications(),
      'appSettings': AppSettingsService.exportForSync(),
    };
  }

  /// Build payload with a specific timestamp (useful for testing or forced timestamps)
  static Map<String, dynamic> buildPayloadWithTimestamp({
    Box<InventoryEntry>? entriesBox,
    required DateTime timestamp,
  }) {
    final payload = buildPayload(entriesBox: entriesBox);
    payload['exportDate'] = timestamp.toIso8601String();
    payload['lastModified'] = timestamp.toIso8601String();
    return payload;
  }

  /// Build and serialize to JSON string
  static String buildJsonString({Box<InventoryEntry>? entriesBox}) {
    return json.encode(buildPayload(entriesBox: entriesBox));
  }

  /// Get the timestamp from a payload (for saving locally after upload)
  static DateTime getPayloadTimestamp(Map<String, dynamic> payload) {
    return DateTime.parse(payload['lastModified'] as String);
  }

  // ---------------------------------------------------------------------------
  // Private export helpers - one per app/data type
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _exportIAmDefinitions() {
    final box = Hive.box<IAmDefinition>('i_am_definitions');
    return box.values.map((def) {
      final map = <String, dynamic>{
        'id': def.id,
        'name': def.name,
      };
      if (def.reasonToExist != null && def.reasonToExist!.isNotEmpty) {
        map['reasonToExist'] = def.reasonToExist;
      }
      return map;
    }).toList();
  }

  static List<Map<String, dynamic>> _exportEntries(Box<InventoryEntry>? box) {
    final entriesBox = box ?? Hive.box<InventoryEntry>('entries');
    return entriesBox.values.map((e) => e.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportPeople() {
    final box = Hive.box<Person>('people_box');
    return box.values.map((p) => p.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportReflections() {
    final box = Hive.box<ReflectionEntry>('reflections_box');
    return box.values.map((r) => r.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportGratitude() {
    final box = Hive.box<GratitudeEntry>('gratitude_box');
    return box.values.map((g) => g.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportAgnosticism() {
    final box = Hive.box<BarrierPowerPair>('agnosticism_pairs');
    return box.values.map((p) => p.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportMorningRitualItems() {
    final box = Hive.box<RitualItem>('morning_ritual_items');
    return box.values.map((i) => i.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportMorningRitualEntries() {
    final box = Hive.box<MorningRitualEntry>('morning_ritual_entries');
    return box.values.map((e) => e.toJson()).toList();
  }

  static List<Map<String, dynamic>> _exportNotifications() {
    final box = Hive.box<AppNotification>('notifications_box');
    return box.values.map((n) => n.toJson()).toList();
  }
}
