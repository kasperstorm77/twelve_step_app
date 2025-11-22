import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/models/inventory_entry.dart';
import 'package:uuid/uuid.dart';
import '../../shared/services/legacy_drive_service.dart';

class IAmService {
  static final IAmService _instance = IAmService._internal();
  factory IAmService() => _instance;
  IAmService._internal();

  final _uuid = const Uuid();

  /// Initialize the I Am definitions box with default value if empty
  Future<void> initializeDefaults() async {
    final box = Hive.box<IAmDefinition>('i_am_definitions');
    
    if (box.isEmpty) {
      final defaultIAm = IAmDefinition(
        id: _uuid.v4(),
        name: 'Sober member of AA',
        reasonToExist: null,
      );
      await box.add(defaultIAm);
    }
  }

  /// Add a new I Am definition
  Future<void> addDefinition(Box<IAmDefinition> box, IAmDefinition definition) async {
    await box.add(definition);
    // Trigger Drive sync by uploading inventory (which includes I Am definitions)
    final entriesBox = await Hive.openBox<InventoryEntry>('entries');
    DriveService.instance.scheduleUploadFromBox(entriesBox);
  }

  /// Update an existing I Am definition
  Future<void> updateDefinition(Box<IAmDefinition> box, int index, IAmDefinition definition) async {
    await box.putAt(index, definition);
    // Trigger Drive sync
    final entriesBox = await Hive.openBox<InventoryEntry>('entries');
    DriveService.instance.scheduleUploadFromBox(entriesBox);
  }

  /// Delete an I Am definition
  Future<void> deleteDefinition(Box<IAmDefinition> box, int index) async {
    await box.deleteAt(index);
    // Trigger Drive sync
    final entriesBox = await Hive.openBox<InventoryEntry>('entries');
    DriveService.instance.scheduleUploadFromBox(entriesBox);
  }

  /// Get all I Am definitions
  List<IAmDefinition> getAllDefinitions(Box<IAmDefinition> box) {
    return box.values.toList();
  }

  /// Find I Am definition by ID
  IAmDefinition? findById(Box<IAmDefinition> box, String id) {
    return box.values.firstWhere(
      (def) => def.id == id,
      orElse: () => IAmDefinition(id: '', name: ''),
    );
  }

  /// Generate a new UUID
  String generateId() {
    return _uuid.v4();
  }
}
