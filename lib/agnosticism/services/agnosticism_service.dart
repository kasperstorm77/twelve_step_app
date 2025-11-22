import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/agnosticism_paper.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../../fourth_step/models/inventory_entry.dart';

class AgnosticismService {
  static const _uuid = Uuid();

  /// Get or create the active paper
  AgnosticismPaper getOrCreateActivePaper(Box<AgnosticismPaper> box) {
    // Find existing active paper
    final activePaper = box.values.firstWhere(
      (paper) => paper.isActive,
      orElse: () => _createNewPaper(),
    );

    // If we created a new paper, save it
    if (!box.values.contains(activePaper)) {
      box.put(activePaper.id, activePaper);
      _triggerSync();
    }

    return activePaper;
  }

  /// Create a new paper
  AgnosticismPaper _createNewPaper() {
    return AgnosticismPaper(
      id: _uuid.v4(),
      status: PaperStatus.active,
      sideA: [],
      sideB: [],
      createdAt: DateTime.now(),
    );
  }

  /// Add barrier to Side A
  Future<void> addBarrier(Box<AgnosticismPaper> box, String paperId, String barrier) async {
    final paper = box.get(paperId);
    if (paper == null) return;

    paper.sideA.add(barrier);
    await paper.save();
    _triggerSync();
  }

  /// Remove barrier from Side A
  Future<void> removeBarrier(Box<AgnosticismPaper> box, String paperId, int index) async {
    final paper = box.get(paperId);
    if (paper == null || index < 0 || index >= paper.sideA.length) return;

    paper.sideA.removeAt(index);
    await paper.save();
    _triggerSync();
  }

  /// Add attribute to Side B
  Future<void> addAttribute(Box<AgnosticismPaper> box, String paperId, String attribute) async {
    final paper = box.get(paperId);
    if (paper == null) return;

    paper.sideB.add(attribute);
    await paper.save();
    _triggerSync();
  }

  /// Remove attribute from Side B
  Future<void> removeAttribute(Box<AgnosticismPaper> box, String paperId, int index) async {
    final paper = box.get(paperId);
    if (paper == null || index < 0 || index >= paper.sideB.length) return;

    paper.sideB.removeAt(index);
    await paper.save();
    _triggerSync();
  }

  /// Finalize paper and move to archive
  Future<void> finalizePaper(Box<AgnosticismPaper> box, String paperId) async {
    final paper = box.get(paperId);
    if (paper == null) return;

    paper.status = PaperStatus.archived;
    paper.finalizedAt = DateTime.now();
    await paper.save();
    _triggerSync();
  }

  /// Get all archived papers sorted by date (newest first)
  List<AgnosticismPaper> getArchivedPapers(Box<AgnosticismPaper> box) {
    final archived = box.values.where((paper) => paper.isArchived).toList();
    archived.sort((a, b) => (b.finalizedAt ?? b.createdAt).compareTo(a.finalizedAt ?? a.createdAt));
    return archived;
  }

  /// Delete a paper
  Future<void> deletePaper(Box<AgnosticismPaper> box, String paperId) async {
    await box.delete(paperId);
    _triggerSync();
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
