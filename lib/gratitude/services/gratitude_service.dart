import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/gratitude_entry.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../../fourth_step/models/inventory_entry.dart';

class GratitudeService {
  /// Add a new gratitude entry
  Future<void> addEntry(Box<GratitudeEntry> box, GratitudeEntry entry) async {
    await box.add(entry);
    _triggerSync();
  }

  /// Update an existing gratitude entry
  Future<void> updateEntry(
    Box<GratitudeEntry> box,
    int index,
    GratitudeEntry entry,
  ) async {
    await box.putAt(index, entry);
    _triggerSync();
  }

  /// Delete a gratitude entry
  Future<void> deleteEntry(Box<GratitudeEntry> box, int index) async {
    await box.deleteAt(index);
    _triggerSync();
  }

  /// Get all entries sorted by date (newest first)
  List<GratitudeEntry> getAllEntries(Box<GratitudeEntry> box) {
    final entries = box.values.toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  /// Get entries for a specific date
  List<GratitudeEntry> getEntriesForDate(
    Box<GratitudeEntry> box,
    DateTime date,
  ) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return box.values.where((entry) {
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return entryDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  /// Get all entries grouped by date
  Map<DateTime, List<GratitudeEntry>> getEntriesGroupedByDate(
    Box<GratitudeEntry> box,
  ) {
    final entries = getAllEntries(box);
    final grouped = <DateTime, List<GratitudeEntry>>{};

    for (final entry in entries) {
      final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(entry);
    }

    return grouped;
  }

  /// Check if an entry can be edited (only today's entries)
  bool canEditEntry(GratitudeEntry entry) {
    return entry.canEdit;
  }

  /// Check if an entry can be deleted (only today's entries)
  bool canDeleteEntry(GratitudeEntry entry) {
    return entry.canDelete;
  }

  /// Trigger background sync after changes
  void _triggerSync() {
    try {
      // Trigger sync using the centralized AllAppsDriveService
      final entriesBox = Hive.box<InventoryEntry>('entries');
      AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
    } catch (e) {
      if (kDebugMode) {
        print('Sync not available or failed: $e');
      }
      // Sync not available or failed, silently continue
    }
  }
}
