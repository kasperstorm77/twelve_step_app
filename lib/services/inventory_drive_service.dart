import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../models/i_am_definition.dart';
import 'google_drive/drive_config.dart';
import 'google_drive/mobile_drive_service.dart';

// --------------------------------------------------------------------------
// App-Specific Inventory Drive Service - Mobile Only
// --------------------------------------------------------------------------

/// App-specific Google Drive service for inventory data (mobile platforms)
/// Uses the MobileDriveService with inventory-specific logic
class InventoryDriveService {
  static InventoryDriveService? _instance;
  static InventoryDriveService get instance {
    _instance ??= InventoryDriveService._();
    return _instance!;
  }

  late final MobileDriveService _driveService;
  final StreamController<int> _uploadCountController = StreamController<int>.broadcast();

  InventoryDriveService._() {
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

      // Prepare complete export data with I Am definitions
      final entries = box.values.map((e) => e.toJson()).toList();
      
      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '2.0',
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
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

      // Prepare complete export data with I Am definitions
      final entries = box.values.map((e) => e.toJson()).toList();
      
      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '2.0',
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
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
      if (kDebugMode) print('InventoryDriveService: Download skipped - not authenticated');
      return null;
    }

    try {
      final content = await _driveService.downloadContent();
      if (content == null) return null;

      return await _parseInventoryContent(content);
    } catch (e) {
      if (kDebugMode) print('InventoryDriveService: Download failed - $e');
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
      if (kDebugMode) print('InventoryDriveService: Failed to load sync state - $e');
    }
  }

  /// Save sync state to Hive
  Future<void> _saveSyncState(bool enabled) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      await settingsBox.put('syncEnabled', enabled);
    } catch (e) {
      if (kDebugMode) print('InventoryDriveService: Failed to save sync state - $e');
    }
  }

  /// Save last modified timestamp
  Future<void> _saveLastModified(DateTime timestamp) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      await settingsBox.put('lastModified', timestamp.toIso8601String());
    } catch (e) {
      if (kDebugMode) print('InventoryDriveService: Failed to save lastModified - $e');
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
      if (kDebugMode) print('InventoryDriveService: Failed to get lastModified - $e');
    }
    return null;
  }

  /// Check if remote data is newer than local and auto-sync if needed
  Future<bool> checkAndSyncIfNeeded() async {
    if (kDebugMode) print('InventoryDriveService: Checking for remote updates...');
    
    if (!syncEnabled) {
      if (kDebugMode) print('InventoryDriveService: Sync disabled, skipping check');
      return false;
    }
    
    if (!isAuthenticated) {
      if (kDebugMode) print('InventoryDriveService: Not authenticated, skipping check');
      return false;
    }

    try {
      // Download remote content
      if (kDebugMode) print('InventoryDriveService: Downloading remote file...');
      final content = await _driveService.downloadContent();
      if (content == null) {
        if (kDebugMode) print('InventoryDriveService: No remote file found');
        return false;
      }

      // Parse remote timestamp
      final decoded = json.decode(content) as Map<String, dynamic>;
      final remoteTimestampStr = decoded['lastModified'] as String?;
      
      if (remoteTimestampStr == null) {
        if (kDebugMode) print('InventoryDriveService: Remote file has no timestamp, skipping auto-sync');
        return false;
      }

      final remoteTimestamp = DateTime.parse(remoteTimestampStr);
      final localTimestamp = await _getLocalLastModified();

      // If local timestamp is null or remote is newer, sync down
      if (localTimestamp == null || remoteTimestamp.isAfter(localTimestamp)) {
        if (kDebugMode) {
          print('InventoryDriveService: ⚠️ Remote data is NEWER - syncing down');
          print('  Local:  ${localTimestamp?.toIso8601String() ?? "never synced"}');
          print('  Remote: ${remoteTimestamp.toIso8601String()}');
        }

        // Parse and apply the data
        final entries = await _parseInventoryContent(content);
        final iAmDefinitions = decoded['iAmDefinitions'] as List<dynamic>?;

        // Update I Am definitions first
        if (iAmDefinitions != null) {
          final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
          await iAmBox.clear();
          for (final def in iAmDefinitions) {
            final id = def['id'] as String;
            final name = def['name'] as String;
            final reasonToExist = def['reasonToExist'] as String?;
            await iAmBox.put(id, IAmDefinition(id: id, name: name, reasonToExist: reasonToExist));
          }
        }

        // Update entries
        final entriesBox = Hive.box<InventoryEntry>('entries');
        await entriesBox.clear();
        await entriesBox.addAll(entries);

        // Save the remote timestamp as our new local timestamp
        await _saveLastModified(remoteTimestamp);

        if (kDebugMode) print('InventoryDriveService: ✓ Auto-sync complete (${entries.length} entries, ${iAmDefinitions?.length ?? 0} I Ams)');
        return true;
      } else {
        if (kDebugMode) {
          print('InventoryDriveService: ✓ Local data is up to date');
          print('  Local:  ${localTimestamp.toIso8601String()}');
          print('  Remote: ${remoteTimestamp.toIso8601String()}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('InventoryDriveService: ❌ Auto-sync check failed - $e');
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
      if (kDebugMode) print('InventoryDriveService: Failed to get entries count - $e');
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
        .map((item) => InventoryEntry(
              item['resentment']?.toString() ?? '',
              item['reason']?.toString() ?? '',
              item['affect']?.toString() ?? '',
              item['part']?.toString() ?? '',
              item['defect']?.toString() ?? '',
              iAmId: item['iAmId']?.toString(),
            ))
        .toList();
  } catch (e) {
    if (kDebugMode) print('Failed to parse inventory JSON: $e');
    return [];
  }
}