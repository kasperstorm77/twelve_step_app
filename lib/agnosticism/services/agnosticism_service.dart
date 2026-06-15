import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/barrier_power_pair.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../../fourth_step/models/inventory_entry.dart';

class AgnosticismService {
  static const _uuid = Uuid();
  static const int maxActivePairs = 5;

  /// Get all active (non-archived) pairs sorted by position
  List<BarrierPowerPair> getActivePairs(Box<BarrierPowerPair> box) {
    final pairs = box.values.where((p) => !p.isArchived).toList();
    pairs.sort((a, b) => a.position.compareTo(b.position));
    return pairs;
  }

  /// Get all archived pairs sorted by archived date (newest first)
  List<BarrierPowerPair> getArchivedPairs(Box<BarrierPowerPair> box) {
    final pairs = box.values.where((p) => p.isArchived).toList();
    pairs.sort(
      (a, b) =>
          (b.archivedAt ?? b.createdAt).compareTo(a.archivedAt ?? a.createdAt),
    );
    return pairs;
  }

  /// Get active pair count
  int getActivePairCount(Box<BarrierPowerPair> box) {
    return box.values.where((p) => !p.isArchived).length;
  }

  /// Check if can add more pairs
  bool canAddPair(Box<BarrierPowerPair> box) {
    return getActivePairCount(box) < maxActivePairs;
  }

  /// Add a new barrier/power pair
  Future<BarrierPowerPair?> addPair(
    Box<BarrierPowerPair> box,
    String barrier,
    String power,
  ) async {
    if (!canAddPair(box)) {
      return null; // Max pairs reached
    }

    final activePairs = getActivePairs(box);
    final nextPosition = activePairs.isEmpty ? 0 : activePairs.length;

    final pair = BarrierPowerPair(
      id: _uuid.v4(),
      barrier: barrier,
      power: power,
      isArchived: false,
      createdAt: DateTime.now(),
      position: nextPosition,
    );

    await box.put(pair.id, pair);
    _triggerSync();
    return pair;
  }

  /// Update an existing pair
  Future<void> updatePair(
    Box<BarrierPowerPair> box,
    String id,
    String barrier,
    String power,
  ) async {
    final pair = box.get(id);
    if (pair == null) return;

    pair.barrier = barrier;
    pair.power = power;
    await pair.save();
    _triggerSync();
  }

  /// Archive a pair
  Future<void> archivePair(Box<BarrierPowerPair> box, String id) async {
    final pair = box.get(id);
    if (pair == null) return;

    pair.isArchived = true;
    pair.archivedAt = DateTime.now();
    await pair.save();

    // Reorder remaining active pairs
    await _reorderActivePairs(box);
    _triggerSync();
  }

  /// Restore an archived pair (if space available)
  Future<bool> restorePair(Box<BarrierPowerPair> box, String id) async {
    if (!canAddPair(box)) {
      return false; // No space
    }

    final pair = box.get(id);
    if (pair == null || !pair.isArchived) return false;

    final activePairs = getActivePairs(box);
    pair.isArchived = false;
    pair.archivedAt = null;
    pair.position = activePairs.length;
    await pair.save();
    _triggerSync();
    return true;
  }

  /// Delete an archived pair
  Future<void> deletePair(Box<BarrierPowerPair> box, String id) async {
    final pair = box.get(id);
    if (pair == null || !pair.isArchived) {
      return; // Only archived pairs can be deleted
    }

    await box.delete(id);
    _triggerSync();
  }

  /// Reorder active pairs after archiving
  Future<void> _reorderActivePairs(Box<BarrierPowerPair> box) async {
    final activePairs = getActivePairs(box);
    for (var i = 0; i < activePairs.length; i++) {
      if (activePairs[i].position != i) {
        activePairs[i].position = i;
        await activePairs[i].save();
      }
    }
  }

  /// Get a pair by ID
  BarrierPowerPair? getPair(Box<BarrierPowerPair> box, String id) {
    return box.get(id);
  }

  /// Trigger background sync after changes
  void _triggerSync() {
    try {
      final entriesBox = Hive.box<InventoryEntry>('entries');
      AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
    } catch (e) {
      if (kDebugMode) {
        print('Sync not available or failed: $e');
      }
    }
  }
}
