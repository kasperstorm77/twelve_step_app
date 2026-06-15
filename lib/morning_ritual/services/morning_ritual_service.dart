import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ritual_item.dart';
import '../models/morning_ritual_entry.dart';
import '../../shared/services/all_apps_drive_service.dart';

class MorningRitualService {
  static Box<RitualItem>? _ritualItemsBox;
  static Box<MorningRitualEntry>? _entriesBox;

  static Box<RitualItem> get ritualItemsBox {
    _ritualItemsBox ??= Hive.box<RitualItem>('morning_ritual_items');
    return _ritualItemsBox!;
  }

  static Box<MorningRitualEntry> get entriesBox {
    _entriesBox ??= Hive.box<MorningRitualEntry>('morning_ritual_entries');
    return _entriesBox!;
  }

  // ============ Ritual Items (Definitions) ============

  /// Get all active ritual items in order
  static List<RitualItem> getActiveRitualItems() {
    return ritualItemsBox.values.where((item) => item.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get all ritual items (including inactive) in order
  static List<RitualItem> getAllRitualItems() {
    return ritualItemsBox.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Add a new ritual item
  static Future<void> addRitualItem(RitualItem item) async {
    // Set sort order to be last
    final maxOrder = ritualItemsBox.values.isEmpty
        ? -1
        : ritualItemsBox.values
              .map((i) => i.sortOrder)
              .reduce((a, b) => a > b ? a : b);
    final newItem = item.copyWith(sortOrder: maxOrder + 1);
    await ritualItemsBox.put(newItem.id, newItem);
    _triggerSync();
  }

  /// Update an existing ritual item
  static Future<void> updateRitualItem(RitualItem item) async {
    final updatedItem = item.copyWith(); // This updates lastModified
    await ritualItemsBox.put(updatedItem.id, updatedItem);
    _triggerSync();
  }

  /// Delete a ritual item
  static Future<void> deleteRitualItem(String id) async {
    await ritualItemsBox.delete(id);
    _triggerSync();
  }

  /// Reorder ritual items
  static Future<void> reorderRitualItems(int oldIndex, int newIndex) async {
    final items = getActiveRitualItems();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update sort orders
    for (int i = 0; i < items.length; i++) {
      final updatedItem = items[i].copyWith(sortOrder: i);
      await ritualItemsBox.put(updatedItem.id, updatedItem);
    }
    _triggerSync();
  }

  /// Get a ritual item by ID
  static RitualItem? getRitualItemById(String id) {
    return ritualItemsBox.get(id);
  }

  // ============ Morning Ritual Entries ============

  /// Get all entries sorted by date descending
  static List<MorningRitualEntry> getAllEntries() {
    return entriesBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get entry for a specific date
  static MorningRitualEntry? getEntryByDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    try {
      return entriesBox.values.firstWhere(
        (entry) =>
            entry.date.year == dateOnly.year &&
            entry.date.month == dateOnly.month &&
            entry.date.day == dateOnly.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if there's an entry for a specific date
  static bool hasEntryForDate(DateTime date) {
    return getEntryByDate(date) != null;
  }

  /// Add or update an entry
  static Future<void> saveEntry(MorningRitualEntry entry) async {
    await entriesBox.put(entry.id, entry);
    _triggerSync();
  }

  /// Delete an entry
  static Future<void> deleteEntry(String id) async {
    await entriesBox.delete(id);
    _triggerSync();
  }

  /// Get entries by month
  static List<MorningRitualEntry> getEntriesByMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return entriesBox.values
        .where(
          (entry) =>
              entry.date.isAfter(
                startOfMonth.subtract(const Duration(days: 1)),
              ) &&
              entry.date.isBefore(endOfMonth.add(const Duration(days: 1))),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get entries grouped by day
  static Map<DateTime, MorningRitualEntry> getEntriesByDay() {
    final Map<DateTime, MorningRitualEntry> map = {};
    for (var entry in entriesBox.values) {
      final dateKey = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      map[dateKey] = entry;
    }
    return map;
  }

  /// Create a "missed" entry for a past date when ritual wasn't started
  static Future<MorningRitualEntry> createMissedEntry(DateTime date) async {
    final activeItems = getActiveRitualItems();
    final missedRecords = activeItems
        .map(
          (item) => RitualItemRecord(
            ritualItemId: item.id,
            ritualItemName: item.name,
            status: RitualItemStatus.missed,
          ),
        )
        .toList();

    final entry = MorningRitualEntry(
      date: date,
      items: missedRecords,
      startedAt: null,
      completedAt: null,
    );

    await saveEntry(entry);
    return entry;
  }

  // ============ In-Progress Ritual (device-local draft) ============
  //
  // The in-progress ritual (which items are done, where the user is) is saved
  // here so it survives navigating away, switching apps, or restarting the app,
  // and is restored when the user returns the SAME day. A new calendar day
  // resets it. This draft is stored in the device-local `settings` box and is
  // deliberately NOT part of the Drive sync payload (only the finished
  // [MorningRitualEntry] syncs) — partial progress is per-device, and keeping it
  // out of sync means the schema/backups are unchanged and fully backwards
  // compatible.

  static const String _progressKey = 'morning_ritual_progress';

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Persist the in-progress ritual for [date]. Best-effort.
  static Future<void> saveProgress({
    required DateTime date,
    required int currentItemIndex,
    required DateTime? startedAt,
    required List<RitualItemRecord> records,
  }) async {
    if (!Hive.isBoxOpen('settings')) return;
    try {
      final data = {
        'date': _dayKey(date),
        'currentItemIndex': currentItemIndex,
        'startedAt': startedAt?.toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      };
      await Hive.box('settings').put(_progressKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) {
        print('MorningRitualService: Failed to save progress - $e');
      }
    }
  }

  /// Load the saved in-progress ritual if it belongs to [today]. A draft from an
  /// earlier day is stale (a new day resets the ritual) and is discarded.
  /// Returns null when there is nothing valid to resume.
  static Map<String, dynamic>? loadProgress(DateTime today) {
    if (!Hive.isBoxOpen('settings')) return null;
    final box = Hive.box('settings');
    final raw = box.get(_progressKey) as String?;
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['date'] != _dayKey(today)) {
        // Different/previous day — clear so it can't resurface.
        box.delete(_progressKey);
        return null;
      }
      return data;
    } catch (_) {
      box.delete(_progressKey);
      return null;
    }
  }

  /// Clear any saved in-progress ritual (called when the ritual is finished).
  static Future<void> clearProgress() async {
    if (!Hive.isBoxOpen('settings')) return;
    try {
      await Hive.box('settings').delete(_progressKey);
    } catch (e) {
      if (kDebugMode) {
        print('MorningRitualService: Failed to clear progress - $e');
      }
    }
  }

  /// Trigger background sync after changes
  static void _triggerSync() {
    try {
      // Trigger sync using the centralized AllAppsDriveService
      // No box parameter needed - it will fetch all data internally
      AllAppsDriveService.instance.scheduleUploadFromBox();
    } catch (e) {
      if (kDebugMode) {
        print('Sync not available or failed: $e');
      }
    }
  }
}
