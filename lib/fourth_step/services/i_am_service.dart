import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/models/inventory_entry.dart';
import 'package:uuid/uuid.dart';
import '../../shared/services/all_apps_drive_service.dart';

class IAmService {
  static final IAmService _instance = IAmService._internal();
  factory IAmService() => _instance;
  IAmService._internal();

  final _uuid = const Uuid();

  /// Initialize the I Am definitions box with default value if empty
  /// NOTE: This does NOT trigger a Drive upload - it's for initialization only
  Future<void> initializeDefaults() async {
    final box = Hive.box<IAmDefinition>('i_am_definitions');
    
    if (box.isEmpty) {
      final defaultIAm = IAmDefinition(
        id: _uuid.v4(),
        name: 'Sober member of AA',
        reasonToExist: null,
      );
      // Add directly to box without triggering Drive sync
      // This is initialization only, not a user action
      await box.add(defaultIAm);
    }
  }

  /// Add a new I Am definition
  Future<void> addDefinition(Box<IAmDefinition> box, IAmDefinition definition) async {
    await box.add(definition);
    // Trigger Drive sync by uploading inventory (which includes I Am definitions)
    final entriesBox = await Hive.openBox<InventoryEntry>('entries');
    AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
  }

  /// Update an existing I Am definition
  Future<void> updateDefinition(Box<IAmDefinition> box, int index, IAmDefinition definition) async {
    await box.putAt(index, definition);
    // Trigger Drive sync
    final entriesBox = await Hive.openBox<InventoryEntry>('entries');
    AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
  }

  /// Delete an I Am definition
  Future<void> deleteDefinition(Box<IAmDefinition> box, int index) async {
    await box.deleteAt(index);
    // Trigger Drive sync
    final entriesBox = await Hive.openBox<InventoryEntry>('entries');
    AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
  }

  /// Get all I Am definitions
  List<IAmDefinition> getAllDefinitions(Box<IAmDefinition> box) {
    return box.values.toList();
  }

  /// Find I Am definition by ID
  /// Returns null if not found (clean API - caller handles null case)
  IAmDefinition? findById(Box<IAmDefinition> box, String? id) {
    if (id == null || id.isEmpty) return null;
    
    try {
      return box.values.firstWhere((def) => def.id == id);
    } catch (e) {
      // Not found
      return null;
    }
  }

  /// Get the name of an I Am definition by ID
  /// Returns null if not found or if id is null/empty
  String? getNameById(Box<IAmDefinition> box, String? id) {
    final definition = findById(box, id);
    return definition?.name;
  }

  /// Count how many entries reference a specific I Am definition
  /// Checks both legacy single iAmId and new iAmIds list
  int getUsageCount(Box<InventoryEntry> entriesBox, String iAmId) {
    return entriesBox.values.where((entry) => entry.effectiveIAmIds.contains(iAmId)).length;
  }

  /// Get all entries that reference a specific I Am definition
  /// Checks both legacy single iAmId and new iAmIds list
  List<InventoryEntry> getEntriesUsingIAm(Box<InventoryEntry> entriesBox, String iAmId) {
    return entriesBox.values.where((entry) => entry.effectiveIAmIds.contains(iAmId)).toList();
  }

  /// Check if an I Am definition is in use by any entry
  /// Checks both legacy single iAmId and new iAmIds list
  bool isInUse(Box<InventoryEntry> entriesBox, String iAmId) {
    return entriesBox.values.any((entry) => entry.effectiveIAmIds.contains(iAmId));
  }

  /// Find orphaned entries (entries with iAmId that doesn't exist in definitions)
  List<InventoryEntry> findOrphanedEntries(Box<InventoryEntry> entriesBox, Box<IAmDefinition> iAmBox) {
    final validIds = iAmBox.values.map((def) => def.id).toSet();
    return entriesBox.values.where((entry) {
      final ids = entry.effectiveIAmIds;
      if (ids.isEmpty) return false;
      // Entry is orphaned if ANY of its iAmIds don't exist
      return ids.any((id) => !validIds.contains(id));
    }).toList();
  }

  /// Generate a new UUID
  String generateId() {
    return _uuid.v4();
  }
}
