import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/reflection_entry.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../../fourth_step/models/inventory_entry.dart';

class ReflectionService {
  static final Box<ReflectionEntry> _box = Hive.box<ReflectionEntry>('reflections_box');

  static List<ReflectionEntry> getAllReflections() {
    return _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<ReflectionEntry> getReflectionsByDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _box.values
        .where((reflection) =>
            reflection.date.year == dateOnly.year &&
            reflection.date.month == dateOnly.month &&
            reflection.date.day == dateOnly.day)
        .toList();
  }

  static List<ReflectionEntry> getReflectionsByMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return _box.values
        .where((reflection) =>
            reflection.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            reflection.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> addReflection(ReflectionEntry reflection) async {
    await _box.put(reflection.internalId, reflection);
    _triggerSync();
  }

  static Future<void> updateReflection(ReflectionEntry reflection) async {
    reflection.lastModified = DateTime.now();
    await _box.put(reflection.internalId, reflection);
    _triggerSync();
  }

  static Future<void> deleteReflection(String internalId) async {
    await _box.delete(internalId);
    _triggerSync();
  }

  static ReflectionEntry? getReflectionById(String internalId) {
    return _box.get(internalId);
  }

  static Box<ReflectionEntry> getBox() {
    return _box;
  }

  static Map<DateTime, List<ReflectionEntry>> getReflectionsByDay() {
    final Map<DateTime, List<ReflectionEntry>> map = {};
    for (var reflection in _box.values) {
      final dateKey = DateTime(reflection.date.year, reflection.date.month, reflection.date.day);
      map.putIfAbsent(dateKey, () => []).add(reflection);
    }
    return map;
  }

  static bool hasReflectionsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _box.values.any((reflection) =>
        reflection.date.year == dateOnly.year &&
        reflection.date.month == dateOnly.month &&
        reflection.date.day == dateOnly.day);
  }

  /// Trigger background sync after changes
  static void _triggerSync() {
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
