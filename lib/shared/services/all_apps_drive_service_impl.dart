import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../eighth_step/models/person.dart';
import '../../evening_ritual/models/reflection_entry.dart';
import '../../morning_ritual/models/ritual_item.dart';
import '../../morning_ritual/models/morning_ritual_entry.dart';
import '../../gratitude/models/gratitude_entry.dart';
import '../../agnosticism/models/barrier_power_pair.dart';
import 'google_drive/drive_config.dart';
import 'google_drive/mobile_drive_service.dart';
import 'google_drive/windows_drive_service_wrapper.dart';
import '../utils/platform_helper.dart';

// --------------------------------------------------------------------------
// All Apps Drive Service - Platform-Aware Implementation
// --------------------------------------------------------------------------

/// Google Drive service that syncs all 5 apps
/// Uses platform-specific drive services (mobile or Windows)
class AllAppsDriveService {
  static AllAppsDriveService? _instance;
  static AllAppsDriveService get instance {
    _instance ??= AllAppsDriveService._();
    return _instance!;
  }

  // Platform-specific drive services
  MobileDriveService? _mobileDriveService;
  WindowsDriveServiceWrapper? _windowsDriveService;
  
  final StreamController<int> _uploadCountController = StreamController<int>.broadcast();

  AllAppsDriveService._() {
    _initializePlatformService();
  }

  /// Initialize the appropriate platform-specific service
  void _initializePlatformService() {
    // Configure for inventory app
    const config = GoogleDriveConfig(
      fileName: 'twelve_steps_backup.json',
      mimeType: 'application/json',
      scope: 'https://www.googleapis.com/auth/drive.appdata',
      parentFolder: 'appDataFolder',
    );

    if (PlatformHelper.isWindows) {
      // Windows uses WindowsDriveServiceWrapper
      if (kDebugMode) print('AllAppsDriveService: Initializing for Windows');
      // Will be created async in initialize()
    } else {
      // Mobile (Android/iOS) uses MobileDriveService
      if (kDebugMode) print('AllAppsDriveService: Initializing for Mobile');
      _mobileDriveService = MobileDriveService(config: config);
    }
    
    // Note: We don't auto-listen to all upload events anymore
    // UI notifications are only triggered for user-initiated actions
  }

  // Expose underlying service properties
  bool get syncEnabled {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService?.syncEnabled ?? false;
    } else {
      return _mobileDriveService?.syncEnabled ?? false;
    }
  }
  
  bool get isAuthenticated {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService?.isAuthenticated ?? false;
    } else {
      return _mobileDriveService?.isAuthenticated ?? false;
    }
  }
  
  Stream<bool> get onSyncStateChanged {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService?.onSyncStateChanged ?? Stream.empty();
    } else {
      return _mobileDriveService?.onSyncStateChanged ?? Stream.empty();
    }
  }
  
  Stream<int> get onUpload => _uploadCountController.stream;
  
  Stream<String> get onError {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService?.onError ?? Stream.empty();
    } else {
      return _mobileDriveService?.onError ?? Stream.empty();
    }
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (PlatformHelper.isWindows) {
      // Create WindowsDriveService and wrap it
      const config = GoogleDriveConfig(
        fileName: 'twelve_steps_backup.json',
        mimeType: 'application/json',
        scope: 'https://www.googleapis.com/auth/drive.appdata',
        parentFolder: 'appDataFolder',
      );
      _windowsDriveService = await WindowsDriveServiceWrapper.create(
        config: config,
        syncEnabled: false,
        uploadDelay: const Duration(milliseconds: 700),
      );
      await _windowsDriveService!.initialize();
    } else {
      await _mobileDriveService!.initialize();
    }
    await _loadSyncState();
  }

  /// Sign in to Google
  Future<bool> signIn() {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService!.driveService.signIn();
    } else {
      return _mobileDriveService!.signIn();
    }
  }

  /// Sign out from Google  
  Future<void> signOut() async {
    if (PlatformHelper.isWindows) {
      await _windowsDriveService!.driveService.signOut();
    } else {
      await _mobileDriveService!.signOut();
    }
    await _saveSyncState(false);
  }

  /// Enable/disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    if (PlatformHelper.isWindows) {
      _windowsDriveService!.setSyncEnabled(enabled);
    } else {
      _mobileDriveService!.setSyncEnabled(enabled);
    }
    await _saveSyncState(enabled);
  }

  /// Set external client from access token (for mobile when auth happens in data management tab)
  Future<void> setClientFromToken(String accessToken) async {
    if (!PlatformHelper.isWindows) {
      await _mobileDriveService?.setExternalClientFromToken(accessToken);
    }
  }

  /// Clear the drive client (used on sign-out)
  void clearClient() {
    if (!PlatformHelper.isWindows) {
      _mobileDriveService?.clearExternalClient();
    }
  }

  /// Load sync state from settings (alias for backward compatibility)
  Future<void> loadSyncState() async {
    await _loadSyncState();
  }

  /// Upload raw content directly
  Future<void> uploadContent(String content) async {
    if (PlatformHelper.isWindows) {
      _windowsDriveService!.scheduleUpload(content);
    } else {
      await _mobileDriveService!.uploadContent(content);
    }
  }

  /// Upload inventory entries from Hive box
  Future<void> uploadFromBox(Box<InventoryEntry> box, {bool notifyUI = false}) async {
    if (!syncEnabled || !isAuthenticated) {
      return;
    }

    try {
      // Get I Am definitions
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefinitions = iAmBox.values.map((def) {
        final map = <String, dynamic>{
          'id': def.id,
          'name': def.name,
        };
        if (def.reasonToExist != null && def.reasonToExist!.isNotEmpty) {
          map['reasonToExist'] = def.reasonToExist;
        }
        return map;
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

      // Get agnosticism barrier/power pairs
      final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      final agnosticismPairs = agnosticismBox.values.map((p) => p.toJson()).toList();

      // Get morning ritual items (definitions)
      final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
      final morningRitualItems = morningRitualItemsBox.values.map((i) => i.toJson()).toList();

      // Get morning ritual entries (daily completions)
      final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');
      final morningRitualEntries = morningRitualEntriesBox.values.map((e) => e.toJson()).toList();

      // Prepare complete export data with I Am definitions and people
      final entries = box.values.map((e) => e.toJson()).toList();
      
      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '7.0', // Increment version to include morning ritual
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
        'people': people, // Add 8th step people
        'reflections': reflections, // Add evening reflections
        'gratitude': gratitudeEntries, // Add gratitude entries
        'agnosticism': agnosticismPairs, // Add agnosticism barrier/power pairs
        'morningRitualItems': morningRitualItems, // Add morning ritual definitions
        'morningRitualEntries': morningRitualEntries, // Add morning ritual daily entries
      };

      // Serialize to JSON string
      final jsonString = json.encode(exportData);

      if (PlatformHelper.isWindows) {
        _windowsDriveService!.scheduleUpload(jsonString);
      } else {
        await _mobileDriveService!.uploadContent(jsonString);
      }
      
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
  /// The box parameter is optional - if not provided, entries will be fetched from the standard entries box
  void scheduleUploadFromBox([Box<InventoryEntry>? box]) {
    if (kDebugMode) print('AllAppsDriveService: scheduleUploadFromBox called - syncEnabled=$syncEnabled, isAuthenticated=$isAuthenticated');
    if (!syncEnabled || !isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: ⚠️ Upload skipped - sync not enabled or not authenticated');
      return;
    }

    try {
      // Get I Am definitions
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefinitions = iAmBox.values.map((def) {
        final map = <String, dynamic>{
          'id': def.id,
          'name': def.name,
        };
        if (def.reasonToExist != null && def.reasonToExist!.isNotEmpty) {
          map['reasonToExist'] = def.reasonToExist;
        }
        return map;
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

      // Get agnosticism barrier/power pairs
      final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      final agnosticismPairs = agnosticismBox.values.map((p) => p.toJson()).toList();

      // Get morning ritual items (definitions)
      final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
      final morningRitualItems = morningRitualItemsBox.values.map((i) => i.toJson()).toList();

      // Get morning ritual entries (daily completions)
      final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');
      final morningRitualEntries = morningRitualEntriesBox.values.map((e) => e.toJson()).toList();

      // Prepare complete export data with I Am definitions and people
      // Get entries from passed box or fetch from standard entries box
      final entriesBox = box ?? Hive.box<InventoryEntry>('entries');
      final entries = entriesBox.values.map((e) => e.toJson()).toList();
      
      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '7.0', // Increment version to include morning ritual
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
        'people': people, // Add 8th step people
        'reflections': reflections, // Add evening reflections
        'gratitude': gratitudeEntries, // Add gratitude entries
        'agnosticism': agnosticismPairs, // Add agnosticism barrier/power pairs
        'morningRitualItems': morningRitualItems, // Add morning ritual definitions
        'morningRitualEntries': morningRitualEntries, // Add morning ritual daily entries
      };

      // Serialize to JSON string
      final jsonString = json.encode(exportData);
      
      // Save the upload timestamp locally (fire and forget)
      _saveLastModified(now);
      
      // Schedule upload (debounced)
      if (PlatformHelper.isWindows) {
        _windowsDriveService!.scheduleUpload(jsonString);
      } else {
        _mobileDriveService!.scheduleUpload(jsonString);
      }
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
      final String? content;
      if (PlatformHelper.isWindows) {
        content = await _windowsDriveService!.downloadContent();
      } else {
        content = await _mobileDriveService!.downloadContent();
      }
      
      if (content == null) return null;

      return await _parseInventoryContent(content);
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Download failed - $e');
      rethrow;
    }
  }

  /// List available backup restore points
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    if (PlatformHelper.isWindows) {
      return await _windowsDriveService!.listAvailableBackups();
    } else {
      return await _mobileDriveService!.listAvailableBackups();
    }
  }

  /// Download and restore from a specific backup file
  Future<String?> downloadBackupContent(String fileName) async {
    if (!isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: Download skipped - not authenticated');
      return null;
    }

    try {
      if (PlatformHelper.isWindows) {
        return await _windowsDriveService!.downloadBackupContent(fileName);
      } else {
        return await _mobileDriveService!.downloadBackupContent(fileName);
      }
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Backup download failed - $e');
      rethrow;
    }
  }

  /// Check if inventory file exists on Drive
  Future<bool> inventoryFileExists() {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService!.fileExists();
    } else {
      return _mobileDriveService!.fileExists();
    }
  }

  /// Delete inventory file from Drive
  Future<bool> deleteInventoryFile() {
    if (PlatformHelper.isWindows) {
      return _windowsDriveService!.deleteContent();
    } else {
      return _mobileDriveService!.deleteContent();
    }
  }

  /// Parse downloaded content into InventoryEntry objects
  Future<List<InventoryEntry>> _parseInventoryContent(String content) async {
    return compute(_parseInventoryJson, content);
  }

  /// Load sync state from Hive
  Future<void> _loadSyncState() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final enabled = settingsBox.get('syncEnabled', defaultValue: false) ?? false;
      if (PlatformHelper.isWindows) {
        _windowsDriveService?.setSyncEnabled(enabled);
      } else {
        _mobileDriveService?.setSyncEnabled(enabled);
      }
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
      final String? content;
      if (PlatformHelper.isWindows) {
        content = await _windowsDriveService!.downloadContent();
      } else {
        content = await _mobileDriveService!.downloadContent();
      }
      
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
        // Handle both old ('gratitudeEntries') and new ('gratitude') field names
        final gratitudeData = (decoded['gratitude'] ?? decoded['gratitudeEntries']) as List<dynamic>?; 
        // Handle both old ('agnosticismPapers') and new ('agnosticism') field names
        final agnosticismData = (decoded['agnosticism'] ?? decoded['agnosticismPapers']) as List<dynamic>?;
        // Get morning ritual data
        final morningRitualItemsData = decoded['morningRitualItems'] as List<dynamic>?;
        final morningRitualEntriesData = decoded['morningRitualEntries'] as List<dynamic>?;

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

        // Update agnosticism barrier/power pairs (if present in remote data)
        if (agnosticismData != null) {
          final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
          await agnosticismBox.clear();
          for (final pairJson in agnosticismData) {
            final pair = BarrierPowerPair.fromJson(pairJson as Map<String, dynamic>);
            await agnosticismBox.put(pair.id, pair);
          }
        }

        // Update morning ritual items (definitions) (if present in remote data)
        if (morningRitualItemsData != null) {
          final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
          await morningRitualItemsBox.clear();
          for (final itemJson in morningRitualItemsData) {
            final item = RitualItem.fromJson(itemJson as Map<String, dynamic>);
            await morningRitualItemsBox.put(item.id, item);
          }
        }

        // Update morning ritual entries (daily completions) (if present in remote data)
        if (morningRitualEntriesData != null) {
          final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');
          await morningRitualEntriesBox.clear();
          for (final entryJson in morningRitualEntriesData) {
            final entry = MorningRitualEntry.fromJson(entryJson as Map<String, dynamic>);
            await morningRitualEntriesBox.put(entry.id, entry);
          }
        }

        // Save the remote timestamp as our new local timestamp
        await _saveLastModified(remoteTimestamp);

        if (kDebugMode) print('AllAppsDriveService: ✓ Auto-sync complete (${entries.length} entries, ${iAmDefinitions?.length ?? 0} I Ams, ${people?.length ?? 0} people, ${reflections?.length ?? 0} reflections, ${gratitudeData?.length ?? 0} gratitude, ${agnosticismData?.length ?? 0} agnosticism, ${morningRitualItemsData?.length ?? 0} morning ritual items, ${morningRitualEntriesData?.length ?? 0} morning ritual entries)');
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
    if (PlatformHelper.isWindows) {
      _windowsDriveService?.dispose();
    } else {
      _mobileDriveService?.dispose();
    }
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

    if (kDebugMode && entries.isNotEmpty) {
      debugPrint('_parseInventoryJson: First entry raw JSON: ${entries.first}');
      debugPrint('_parseInventoryJson: Has iAmId field? ${(entries.first as Map).containsKey('iAmId')}');
      if ((entries.first as Map).containsKey('iAmId')) {
        debugPrint('_parseInventoryJson: iAmId value: ${(entries.first as Map)['iAmId']}');
      }
    }

    return entries
        .cast<Map<String, dynamic>>()
        .map((item) => InventoryEntry.fromJson(item))
        .toList();
  } catch (e) {
    if (kDebugMode) print('Failed to parse inventory JSON: $e');
    return [];
  }
}