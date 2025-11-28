import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../eighth_step/models/person.dart';
import '../../evening_ritual/models/reflection_entry.dart';
import '../../gratitude/models/gratitude_entry.dart';
import '../../agnosticism/models/agnosticism_paper.dart';
import 'google_drive/drive_config.dart';
import 'google_drive/mobile_drive_service.dart'
    if (dart.library.html) 'google_drive/mobile_drive_service_web.dart';

// --------------------------------------------------------------------------
// All Apps Drive Service - Platform-Aware Implementation
// --------------------------------------------------------------------------

/// Google Drive service that syncs all 5 apps
/// Uses platform-specific MobileDriveService (mobile/web stub)
class AllAppsDriveService {
  static AllAppsDriveService? _instance;
  static AllAppsDriveService get instance {
    _instance ??= AllAppsDriveService._();
    return _instance!;
  }

  late final MobileDriveService _driveService;
  final StreamController<int> _uploadCountController = StreamController<int>.broadcast();

  AllAppsDriveService._() {
    // Configure for inventory app
    const config = GoogleDriveConfig(
      fileName: 'aa4step_inventory_data.json',
      mimeType: 'application/json',
      scope: 'https://www.googleapis.com/auth/drive.appdata',
      parentFolder: 'appDataFolder',
    );

    _driveService = MobileDriveService(config: config);
    
    // Note: We don't auto-listen to all upload events anymore
    // UI notifications are only triggered for user-initiated actions
  }

  // Expose underlying service properties
  bool get syncEnabled => _driveService.syncEnabled;
  bool get isAuthenticated => _driveService.isAuthenticated;
  Stream<bool> get onSyncStateChanged => _driveService.onSyncStateChanged;
  Stream<int> get onUpload => _uploadCountController.stream;
  Stream<String> get onError => _driveService.onError;

  /// Initialize the service
  Future<void> initialize() async {
    await _driveService.initialize();
    await _loadSyncState();
  }

  /// Sign in to Google
  Future<bool> signIn() => _driveService.signIn();

  /// Sign out from Google  
  Future<void> signOut() async {
    await _driveService.signOut();
    await _saveSyncState(false);
  }

  /// Enable/disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    _driveService.setSyncEnabled(enabled);
    await _saveSyncState(enabled);
  }

  /// Upload raw content directly
  Future<void> uploadContent(String content) async {
    await _driveService.uploadContent(content);
  }

  /// Upload inventory entries from Hive box
  Future<void> uploadFromBox(Box<InventoryEntry> box, {bool notifyUI = false}) async {
    if (!syncEnabled || !isAuthenticated) {
      return;
    }

    try {
      // Get I Am definitions
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefinitions = iAmBox.values.map((def) => {
        'id': def.id,
        'name': def.name,
        'reasonToExist': def.reasonToExist,
      }).toList();

      // Get 8th step people
      final peopleBox = Hive.box<Person>('people_box');
      final people = peopleBox.values.map((p) => p.toJson()).toList();

      // Get evening reflections
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
      final reflections = reflectionsBox.values.map((r) => r.toJson()).toList();

      // Get gratitude entries
      final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
      final gratitudeEntries = gratitudeBox.values.map((g) => g.toJson()).toList();

      // Get agnosticism papers
      final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');
      final agnosticismPapers = agnosticismBox.values.map((p) => p.toJson()).toList();

      // Prepare complete export data with I Am definitions and people
      final entries = box.values.map((e) => e.toJson()).toList();
      
      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '6.0', // Increment version to include agnosticism
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
        'people': people, // Add 8th step people
        'reflections': reflections, // Add evening reflections
        'gratitude': gratitudeEntries, // Add gratitude entries
        'agnosticism': agnosticismPapers, // Add agnosticism papers
      };

      // Serialize to JSON string
      final jsonString = json.encode(exportData);

      await _driveService.uploadContent(jsonString);
      
      // Save the upload timestamp locally
      await _saveLastModified(now);
      
      // Only notify UI for user-initiated uploads
      if (notifyUI) {
        _notifyUploadCount();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Schedule debounced upload from box (background sync - no UI notifications)
  void scheduleUploadFromBox(Box<InventoryEntry> box) {
    if (!syncEnabled || !isAuthenticated) return;

    try {
      // Get I Am definitions
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefinitions = iAmBox.values.map((def) => {
        'id': def.id,
        'name': def.name,
        'reasonToExist': def.reasonToExist,
      }).toList();

      // Get 8th step people
      final peopleBox = Hive.box<Person>('people_box');
      final people = peopleBox.values.map((p) => p.toJson()).toList();

      // Get evening reflections
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
      final reflections = reflectionsBox.values.map((r) => r.toJson()).toList();

      // Get gratitude entries
      final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
      final gratitudeEntries = gratitudeBox.values.map((g) => g.toJson()).toList();

      // Get agnosticism papers
      final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');
      final agnosticismPapers = agnosticismBox.values.map((p) => p.toJson()).toList();

      // Prepare complete export data with I Am definitions and people
      final entries = box.values.map((e) => e.toJson()).toList();
      
      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '6.0', // Increment version to include agnosticism
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
        'people': people, // Add 8th step people
        'reflections': reflections, // Add evening reflections
        'gratitude': gratitudeEntries, // Add gratitude entries
        'agnosticism': agnosticismPapers, // Add agnosticism papers
      };

      // Serialize to JSON string
      final jsonString = json.encode(exportData);
      
      // Save the upload timestamp locally (fire and forget)
      _saveLastModified(now);
      
      // Schedule upload (debounced)
      _driveService.scheduleUpload(jsonString);
    } catch (e) {
      // Background sync failed, will retry on next change
    }
  }

  /// Upload from box with UI notification (for user-initiated actions)
  Future<void> uploadFromBoxWithNotification(Box<InventoryEntry> box) async {
    await uploadFromBox(box, notifyUI: true);
  }

  /// Download and restore inventory entries
  Future<List<InventoryEntry>?> downloadEntries() async {
    if (!isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: Download skipped - not authenticated');
      return null;
    }

    try {
      final content = await _driveService.downloadContent();
      if (content == null) return null;

      return await _parseInventoryContent(content);
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Download failed - $e');
      rethrow;
    }
  }

  /// List available backup restore points
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    return await _driveService.listAvailableBackups();
  }

  /// Download and restore from a specific backup file
  Future<String?> downloadBackupContent(String fileName) async {
    if (!isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: Download skipped - not authenticated');
      return null;
    }

    try {
      return await _driveService.downloadBackupContent(fileName);
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Backup download failed - $e');
      rethrow;
    }
  }

  /// Check if inventory file exists on Drive
  Future<bool> inventoryFileExists() => _driveService.fileExists();

  /// Delete inventory file from Drive
  Future<bool> deleteInventoryFile() => _driveService.deleteContent();

  /// Parse downloaded content into InventoryEntry objects
  Future<List<InventoryEntry>> _parseInventoryContent(String content) async {
    return compute(_parseInventoryJson, content);
  }

  /// Load sync state from Hive
  Future<void> _loadSyncState() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final enabled = settingsBox.get('syncEnabled', defaultValue: false) ?? false;
      _driveService.setSyncEnabled(enabled);
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to load sync state - $e');
    }
  }

  /// Save sync state to Hive
  Future<void> _saveSyncState(bool enabled) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      await settingsBox.put('syncEnabled', enabled);
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to save sync state - $e');
    }
  }

  /// Save last modified timestamp
  Future<void> _saveLastModified(DateTime timestamp) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      await settingsBox.put('lastModified', timestamp.toIso8601String());
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to save lastModified - $e');
    }
  }

  /// Get local last modified timestamp
  Future<DateTime?> _getLocalLastModified() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final timestampStr = settingsBox.get('lastModified') as String?;
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to get lastModified - $e');
    }
    return null;
  }

  /// Check if remote data is newer than local and auto-sync if needed
  Future<bool> checkAndSyncIfNeeded() async {
    if (kDebugMode) print('AllAppsDriveService: Checking for remote updates...');
    
    if (!syncEnabled) {
      if (kDebugMode) print('AllAppsDriveService: Sync disabled, skipping check');
      return false;
    }
    
    if (!isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: Not authenticated, skipping check');
      return false;
    }

    try {
      // Download remote content
      if (kDebugMode) print('AllAppsDriveService: Downloading remote file...');
      final content = await _driveService.downloadContent();
      if (content == null) {
        if (kDebugMode) print('AllAppsDriveService: No remote file found');
        return false;
      }

      // Parse remote timestamp
      final decoded = json.decode(content) as Map<String, dynamic>;
      final remoteTimestampStr = decoded['lastModified'] as String?;
      
      if (remoteTimestampStr == null) {
        if (kDebugMode) print('AllAppsDriveService: Remote file has no timestamp, skipping auto-sync');
        return false;
      }

      final remoteTimestamp = DateTime.parse(remoteTimestampStr);
      final localTimestamp = await _getLocalLastModified();

      // If local timestamp is null or remote is newer, sync down
      if (localTimestamp == null || remoteTimestamp.isAfter(localTimestamp)) {
        if (kDebugMode) {
          print('AllAppsDriveService: ⚠️ Remote data is NEWER - syncing down');
          print('  Local:  ${localTimestamp?.toIso8601String() ?? "never synced"}');
          print('  Remote: ${remoteTimestamp.toIso8601String()}');
        }

        // Parse and apply the data
        final entries = await _parseInventoryContent(content);
        final iAmDefinitions = decoded['iAmDefinitions'] as List<dynamic>?;
        final people = decoded['people'] as List<dynamic>?; // Get people data
        final reflections = decoded['reflections'] as List<dynamic>?; // Get reflections data
        final gratitudeData = decoded['gratitude'] as List<dynamic>?; // Get gratitude data
        final agnosticismData = decoded['agnosticism'] as List<dynamic>?; // Get agnosticism data

        // Update I Am definitions first
        if (iAmDefinitions != null) {
          final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
          await iAmBox.clear();
          if (kDebugMode) print('AllAppsDriveService: Clearing I Am definitions box...');
          for (final def in iAmDefinitions) {
            final id = def['id'] as String;
            final name = def['name'] as String;
            final reasonToExist = def['reasonToExist'] as String?;
            await iAmBox.add(IAmDefinition(id: id, name: name, reasonToExist: reasonToExist));
            if (kDebugMode) print('AllAppsDriveService: Added I Am definition: $name (id: $id)');
          }
          if (kDebugMode) print('AllAppsDriveService: ✓ Imported ${iAmDefinitions.length} I Am definitions');
        }

        // Update entries
        final entriesBox = Hive.box<InventoryEntry>('entries');
        await entriesBox.clear();
        await entriesBox.addAll(entries);

        // Update 8th step people (if present in remote data)
        if (people != null) {
          final peopleBox = Hive.box<Person>('people_box');
          await peopleBox.clear();
          for (final personData in people) {
            final person = Person.fromJson(personData as Map<String, dynamic>);
            await peopleBox.put(person.internalId, person);
          }
        }

        // Update evening reflections (if present in remote data)
        if (reflections != null) {
          final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
          await reflectionsBox.clear();
          for (final reflectionData in reflections) {
            final reflection = ReflectionEntry.fromJson(reflectionData as Map<String, dynamic>);
            await reflectionsBox.put(reflection.internalId, reflection);
          }
        }

        // Update gratitude entries (if present in remote data)
        if (gratitudeData != null) {
          final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
          await gratitudeBox.clear();
          for (final gratitudeJson in gratitudeData) {
            final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
            await gratitudeBox.add(gratitude);
          }
        }

        // Update agnosticism papers (if present in remote data)
        if (agnosticismData != null) {
          final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');
          await agnosticismBox.clear();
          for (final paperJson in agnosticismData) {
            final paper = AgnosticismPaper.fromJson(paperJson as Map<String, dynamic>);
            await agnosticismBox.put(paper.id, paper);
          }
        }

        // Save the remote timestamp as our new local timestamp
        await _saveLastModified(remoteTimestamp);

        if (kDebugMode) print('AllAppsDriveService: ✓ Auto-sync complete (${entries.length} entries, ${iAmDefinitions?.length ?? 0} I Ams, ${people?.length ?? 0} people, ${reflections?.length ?? 0} reflections, ${gratitudeData?.length ?? 0} gratitude, ${agnosticismData?.length ?? 0} agnosticism)');
        return true;
      } else {
        if (kDebugMode) {
          print('AllAppsDriveService: ✓ Local data is up to date');
          print('  Local:  ${localTimestamp.toIso8601String()}');
          print('  Remote: ${remoteTimestamp.toIso8601String()}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: ❌ Auto-sync check failed - $e');
      return false;
    }
  }

  /// Notify upload count to listeners
  void _notifyUploadCount() {
    try {
      if (Hive.isBoxOpen('entries')) {
        final box = Hive.box<InventoryEntry>('entries');
        _uploadCountController.add(box.length);
      }
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to get entries count - $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _driveService.dispose();
    _uploadCountController.close();
  }
}

// --------------------------------------------------------------------------
// Static parsing function for compute isolate
// --------------------------------------------------------------------------

/// Parse JSON content into InventoryEntry list (runs in isolate)  
List<InventoryEntry> _parseInventoryJson(String content) {
  try {
    final decoded = json.decode(content) as Map<String, dynamic>;
    
    final entries = decoded['entries'] as List<dynamic>?;
    if (entries == null) return [];

    return entries
        .cast<Map<String, dynamic>>()
        .map((item) => InventoryEntry.fromJson(item))
        .toList();
  } catch (e) {
    if (kDebugMode) print('Failed to parse inventory JSON: $e');
    return [];
  }
}