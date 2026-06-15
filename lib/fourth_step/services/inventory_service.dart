import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../../shared/services/all_apps_drive_service.dart';

class InventoryService {
  final Box<InventoryEntry> _box = Hive.box<InventoryEntry>('entries');

  /// Assign order values to entries that don't have them.
  /// Entries are ordered by their Hive key (creation order), with newest getting highest order.
  /// This is used both at app startup (migration) and after restoring from backup.
  static Future<void> migrateOrderValues() async {
    final entriesBox = Hive.box<InventoryEntry>('entries');
    if (entriesBox.isEmpty) {
      return;
    }

    // Get only entries without order values
    final keysWithoutOrder = entriesBox.keys
        .where((key) => entriesBox.get(key)?.order == null)
        .toList();

    if (keysWithoutOrder.isEmpty) {
      return;
    }

    if (kDebugMode) {
      print(
        'Migrating ${keysWithoutOrder.length} entries without order values...',
      );
    }

    // Sort by key (creation order) - oldest first
    keysWithoutOrder.sort((a, b) => (a as int).compareTo(b as int));

    // Find the current max order value (from entries that already have order)
    int maxOrder = 0;
    for (final entry in entriesBox.values) {
      if (entry.order != null && entry.order! > maxOrder) {
        maxOrder = entry.order!;
      }
    }

    // Assign order values starting from maxOrder + 1
    // Oldest unordered entry gets lowest new order, newest gets highest
    for (int i = 0; i < keysWithoutOrder.length; i++) {
      final entry = entriesBox.get(keysWithoutOrder[i]);
      if (entry != null) {
        entry.order = maxOrder + i + 1;
        await entry.save();
      }
    }

    if (kDebugMode) {
      print('✓ Migrated ${keysWithoutOrder.length} entries with order values');
    }
  }

  // Get all entries sorted by order (highest first = newest on top)
  // Entries without order are treated as oldest (order 0)
  List<InventoryEntry> getAllEntries() {
    final entries = _box.values.toList();
    entries.sort((a, b) => (b.order ?? 0).compareTo(a.order ?? 0));
    return entries;
  }

  // Get the next order value (highest + 1)
  int _getNextOrder() {
    if (_box.isEmpty) return 1;
    int maxOrder = 0;
    for (final entry in _box.values) {
      if ((entry.order ?? 0) > maxOrder) {
        maxOrder = entry.order ?? 0;
      }
    }
    return maxOrder + 1;
  }

  // Add new entry (automatically assigns highest order)
  Future<void> addEntry(InventoryEntry entry) async {
    entry.order = _getNextOrder();
    await _box.add(entry);
    AllAppsDriveService.instance.scheduleUploadFromBox(_box);
  }

  // Update entry at index
  Future<void> updateEntry(int index, InventoryEntry entry) async {
    if (index >= 0 && index < _box.length) {
      await _box.putAt(index, entry);
      AllAppsDriveService.instance.scheduleUploadFromBox(_box);
    }
  }

  // Update entry by key (used for editing)
  Future<void> updateEntryByKey(dynamic key, InventoryEntry entry) async {
    await _box.put(key, entry);
    AllAppsDriveService.instance.scheduleUploadFromBox(_box);
  }

  // Get entry by key
  InventoryEntry? getEntryByKey(dynamic key) {
    return _box.get(key);
  }

  // Reorder entries - moves item from oldIndex to newIndex
  Future<void> reorderEntries(int oldIndex, int newIndex) async {
    final entries = getAllEntries();
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    if (newIndex < 0 || newIndex >= entries.length) return;
    if (oldIndex == newIndex) return;

    if (kDebugMode) {
      print('InventoryService: Reordering from $oldIndex to $newIndex');
    }

    // Reassign order values based on new positions
    // After reorder, rebuild order values from scratch
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);

    // Assign new order values (highest to lowest)
    for (int i = 0; i < entries.length; i++) {
      final newOrder = entries.length - i;
      if (kDebugMode) {
        print(
          'InventoryService: Setting entry ${entries[i].id.substring(0, 8)} order to $newOrder (was ${entries[i].order})',
        );
      }
      entries[i].order = newOrder;
      await entries[i].save(); // HiveObject.save() updates in place
    }

    if (kDebugMode) {
      // Verify the save worked by reading back from box
      final verifyEntries = getAllEntries();
      print(
        'InventoryService: After save, order values are: ${verifyEntries.map((e) => e.order).toList()}',
      );
    }

    AllAppsDriveService.instance.scheduleUploadFromBox(_box);
  }

  // Delete entry at index
  Future<void> deleteEntry(int index) async {
    if (index >= 0 && index < _box.length) {
      await _box.deleteAt(index);
      AllAppsDriveService.instance.scheduleUploadFromBox(_box);
    }
  }

  // Delete entry by key
  Future<void> deleteEntryByKey(dynamic key) async {
    await _box.delete(key);
    AllAppsDriveService.instance.scheduleUploadFromBox(_box);
  }

  // Clear all entries
  Future<void> clearAllEntries() async {
    await _box.clear();
    AllAppsDriveService.instance.scheduleUploadFromBox(_box);
  }

  // Get entry at index
  InventoryEntry? getEntryAt(int index) {
    if (index >= 0 && index < _box.length) {
      return _box.getAt(index);
    }
    return null;
  }

  // Get number of entries
  int get entryCount => _box.length;

  // Stream of entry changes
  Stream<BoxEvent> get entriesStream => _box.watch();
}
