import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import 'google_drive/drive_config.dart';
import 'google_drive/mobile_drive_service.dart';
import 'google_drive/windows_drive_service_wrapper.dart';
import '../utils/platform_helper.dart';
import 'local_backup_service.dart';
import 'sync_payload_builder.dart';

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
  
  /// Flag to block uploads when remote has newer data.
  /// This prevents overwriting newer Drive data before user decides what to do.
  bool _uploadsBlocked = false;
  
  /// Stream to notify UI when uploads are blocked due to newer remote data
  final StreamController<bool> _uploadsBlockedController = StreamController<bool>.broadcast();
  
  /// Whether uploads are currently blocked (remote has newer data)
  bool get uploadsBlocked => _uploadsBlocked;
  
  /// Stream that emits when upload blocking state changes
  Stream<bool> get onUploadsBlockedChanged => _uploadsBlockedController.stream;
  
  /// Debounce timer for scheduling uploads (prevents rapid rebuilding of JSON)
  Timer? _uploadDebounceTimer;
  static const Duration _uploadDebounceDelay = Duration(milliseconds: 1000);
  
  /// Flag to prevent concurrent uploads
  bool _uploadInProgress = false;

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
      // Use centralized payload builder
      final payload = SyncPayloadBuilder.buildPayload(entriesBox: box);
      final jsonString = json.encode(payload);
      final timestamp = SyncPayloadBuilder.getPayloadTimestamp(payload);

      if (PlatformHelper.isWindows) {
        _windowsDriveService!.scheduleUpload(jsonString);
      } else {
        await _mobileDriveService!.uploadContent(jsonString);
      }
      
      // Save the upload timestamp locally
      await _saveLastModified(timestamp);
      
      // Only notify UI for user-initiated uploads
      if (notifyUI) {
        _notifyUploadCount();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Block uploads (called when remote has newer data)
  void blockUploads() {
    if (!_uploadsBlocked) {
      _uploadsBlocked = true;
      _uploadsBlockedController.add(true);
      if (kDebugMode) print('AllAppsDriveService: ⚠️ Uploads BLOCKED - remote has newer data');
    }
  }
  
  /// Unblock uploads (called after user fetches data or dismisses the prompt)
  void unblockUploads() {
    if (_uploadsBlocked) {
      _uploadsBlocked = false;
      _uploadsBlockedController.add(false);
      if (kDebugMode) print('AllAppsDriveService: ✓ Uploads UNBLOCKED');
    }
  }

  /// Schedule debounced upload from box (background sync - no UI notifications)
  /// The box parameter is optional - if not provided, entries will be fetched from the standard entries box
  /// Uses debouncing to coalesce rapid changes (e.g., multiple reorders) into a single upload
  /// Also triggers local backup regardless of Drive sync status
  void scheduleUploadFromBox([Box<InventoryEntry>? box]) {
    if (kDebugMode) print('AllAppsDriveService: scheduleUploadFromBox called - syncEnabled=$syncEnabled, isAuthenticated=$isAuthenticated, uploadsBlocked=$_uploadsBlocked');
    
    // Always schedule local backup regardless of Drive sync status
    LocalBackupService.instance.scheduleBackup();
    
    if (!syncEnabled || !isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: ⚠️ Drive upload skipped - sync not enabled or not authenticated');
      return;
    }
    
    // SAFETY: Don't upload if remote has newer data - would overwrite it!
    if (_uploadsBlocked) {
      if (kDebugMode) print('AllAppsDriveService: ⚠️ Upload BLOCKED - remote has newer data, user must fetch or dismiss first');
      return;
    }

    // Cancel any pending upload and reset the timer
    // This ensures rapid changes (like multiple reorders) are coalesced
    _uploadDebounceTimer?.cancel();
    
    _uploadDebounceTimer = Timer(_uploadDebounceDelay, () async {
      await _performDebouncedUpload(box);
    });
    
    if (kDebugMode) print('AllAppsDriveService: Upload scheduled (debounced ${_uploadDebounceDelay.inMilliseconds}ms)');
  }
  
  /// Internal method to perform the actual upload after debounce
  Future<void> _performDebouncedUpload([Box<InventoryEntry>? box]) async {
    // Prevent concurrent uploads
    if (_uploadInProgress) {
      if (kDebugMode) print('AllAppsDriveService: _performDebouncedUpload skipped - upload already in progress');
      return;
    }
    
    if (!syncEnabled || !isAuthenticated || _uploadsBlocked) {
      if (kDebugMode) print('AllAppsDriveService: _performDebouncedUpload skipped - conditions not met');
      return;
    }
    
    _uploadInProgress = true;

    try {
      // Use centralized payload builder
      final payload = SyncPayloadBuilder.buildPayload(entriesBox: box);
      final jsonString = json.encode(payload);
      final timestamp = SyncPayloadBuilder.getPayloadTimestamp(payload);
      
      // Save the upload timestamp locally (fire and forget)
      _saveLastModified(timestamp);
      
      // Perform upload directly (debouncing already happened at this level)
      if (PlatformHelper.isWindows) {
        await _windowsDriveService!.driveService.uploadFile(
          fileName: _windowsDriveService!.driveService.config.fileName,
          content: jsonString,
        );
      } else {
        await _mobileDriveService!.uploadContent(jsonString);
      }
      if (kDebugMode) print('AllAppsDriveService: Debounced upload completed');
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Background sync failed: $e');
      // Background sync failed, will retry on next change
    } finally {
      _uploadInProgress = false;
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

  /// Delete all backup files (DEBUG ONLY)
  Future<int> deleteAllBackups() async {
    if (PlatformHelper.isWindows) {
      return 0;
    } else {
      return await _mobileDriveService!.deleteAllBackups();
    }
  }

  /// Parse downloaded content into InventoryEntry objects
  Future<List<InventoryEntry>> _parseInventoryContent(String content) async {
    return compute(_parseInventoryJson, content);
  }

  /// Load sync state from Hive
  Future<void> _loadSyncState() async {
    try {
      final settingsBox = await _getSettingsBox();
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

  Future<Box<dynamic>> _getSettingsBox() async {
    if (Hive.isBoxOpen('settings')) {
      return Hive.box('settings');
    }
    return Hive.openBox('settings');
  }

  /// Save sync state to Hive
  Future<void> _saveSyncState(bool enabled) async {
    try {
      final settingsBox = await _getSettingsBox();
      await settingsBox.put('syncEnabled', enabled);
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to save sync state - $e');
    }
  }

  /// Save last modified timestamp
  Future<void> _saveLastModified(DateTime timestamp) async {
    try {
      final settingsBox = await _getSettingsBox();
      await settingsBox.put('lastModified', timestamp.toIso8601String());
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to save lastModified - $e');
    }
  }

  /// Get local last modified timestamp
  Future<DateTime?> _getLocalLastModified() async {
    try {
      final settingsBox = await _getSettingsBox();
      final timestampStr = settingsBox.get('lastModified') as String?;
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: Failed to get lastModified - $e');
    }
    return null;
  }

  /// Check if remote data is newer than local data
  /// Returns true if remote is newer, false otherwise
  /// Does NOT modify any data - only compares timestamps
  Future<bool> isRemoteNewer() async {
    if (kDebugMode) print('AllAppsDriveService: isRemoteNewer() - checking timestamps...');
    
    if (!isAuthenticated) {
      if (kDebugMode) print('AllAppsDriveService: isRemoteNewer() - not authenticated');
      return false;
    }

    try {
      final localSw = Stopwatch()..start();
      final localTimestamp = await _getLocalLastModified();
      localSw.stop();
      if (kDebugMode) {
        print('AllAppsDriveService: isRemoteNewer() - local timestamp: ${localTimestamp?.toIso8601String() ?? "null"} (${localSw.elapsedMilliseconds}ms)');
      }

      // Fast-path: extract `lastModified` from the newest backup JSON via prefix download.
      // This avoids downloading/parsing the full JSON backup while matching our conflict semantics.
      final remoteSw = Stopwatch()..start();
      final DateTime? remoteTimestamp;
      if (PlatformHelper.isWindows) {
        remoteTimestamp = await _windowsDriveService!.getNewestBackupJsonLastModified(runCleanup: false);
      } else {
        remoteTimestamp = await _mobileDriveService!.getNewestBackupJsonLastModified(runCleanup: false);
      }
      remoteSw.stop();

      if (remoteTimestamp == null) {
        if (kDebugMode) print('AllAppsDriveService: isRemoteNewer() - no remote backup found (${remoteSw.elapsedMilliseconds}ms)');
        return false;
      }

      if (kDebugMode) {
        print('AllAppsDriveService: isRemoteNewer() - remote timestamp: ${remoteTimestamp.toIso8601String()} (${remoteSw.elapsedMilliseconds}ms)');
      }
      
      // If no local timestamp, remote is considered newer
      if (localTimestamp == null) {
        if (kDebugMode) print('AllAppsDriveService: isRemoteNewer() - no local timestamp, remote is newer');
        return true;
      }
      
      // Compare timestamps
      final isNewer = remoteTimestamp.isAfter(localTimestamp);
      if (kDebugMode) print('AllAppsDriveService: isRemoteNewer() - remote is ${isNewer ? "NEWER" : "not newer"} than local');
      return isNewer;
    } catch (e) {
      if (kDebugMode) print('AllAppsDriveService: isRemoteNewer() - error: $e');
      return false;
    }
  }

  /// @deprecated This method always returns false. Auto-restore is disabled for data safety.
  /// Use [isRemoteNewer] to check if remote has newer data, then prompt user to fetch manually.
  /// Local data is ONLY modified through explicit user action (tap "Restore from backup").
  @Deprecated('Auto-restore disabled. Use isRemoteNewer() and prompt user instead.')
  Future<bool> checkAndSyncIfNeeded() async {
    // SAFETY: Never automatically modify local data.
    return false;
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
    _uploadDebounceTimer?.cancel();
    _uploadCountController.close();
    _uploadsBlockedController.close();
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