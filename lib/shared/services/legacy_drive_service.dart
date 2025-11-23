import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import 'google_drive_client.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/sync_utils.dart';
import 'all_apps_drive_service.dart';

// --------------------------------------------------------------------------
// Legacy DriveService - Backward Compatibility Wrapper
// --------------------------------------------------------------------------

/// Legacy DriveService for backward compatibility
/// Delegates to the new clean AllAppsDriveService architecture
class DriveService {
  DriveService._privateConstructor() {
    // Initialize new service
    _initializeNewService();
  }
  
  static final DriveService instance = DriveService._privateConstructor();

  // New service delegate
  final AllAppsDriveService _newService = AllAppsDriveService.instance;
  
  // Legacy fields for backward compatibility
  GoogleDriveClient? _client;

  // Getters that delegate to new service
  Stream<int> get onUpload => _newService.onUpload;
  bool get syncEnabled => _newService.syncEnabled;
  GoogleDriveClient? get client => _client; // Keep for backward compatibility

  /// Initialize the new service
  void _initializeNewService() {
    _newService.initialize().catchError((e) {
      if (kDebugMode) print('DriveService: Failed to initialize new service: $e');
    });
  }

  // Call this after GoogleSignIn completes
  Future<void> setClient(GoogleDriveClient client) async {
    _client = client;
    // The new service handles authentication differently
    // This is kept for backward compatibility but not used internally
  }

  /// Clear the currently set GoogleDriveClient (used on sign-out)
  void clearClient() {
    _client = null;
    _newService.signOut();
  }

  // Initialize sync toggle from Hive
  Future<void> loadSyncState() async {
    // Delegate to new service - it handles Hive internally
    await _newService.initialize();
  }

  Future<void> setSyncEnabled(bool value) async {
    await _newService.setSyncEnabled(value);
  }

  // ------------------ CRUD ------------------
  Future<void> uploadFile(String content) async {
    // Delegate to new service
    await _newService.uploadContent(content);
  }

  /// Schedule debounced upload from a Hive box
  void scheduleUploadFromBox(Box<InventoryEntry> box) {
    _newService.scheduleUploadFromBox(box);
  }

  /// Upload from box with UI notification (for user-initiated actions)
  Future<void> uploadFromBoxWithNotification(Box<InventoryEntry> box) async {
    await _newService.uploadFromBoxWithNotification(box);
  }

  /// Download file content
  Future<String?> downloadFile() async {
    // This method isn't directly available in new service as it returns parsed data
    // For backward compatibility, we'll need to handle this differently
    try {
      final entries = await _newService.downloadEntries();
      if (entries == null) return null;
      
      // Convert back to JSON string for backward compatibility
      return await compute(serializeEntries, entries.map((e) => {
        'resentment': e.resentment,
        'reason': e.reason,
        'affect': e.affect,
        'part': e.part,
        'defect': e.defect,
      }).toList());
    } catch (e) {
      if (kDebugMode) print('DriveService: downloadFile error: $e');
      return null;
    }
  }

  /// List available backup restore points
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    return await _newService.listAvailableBackups();
  }

  /// Download content from a specific backup file
  Future<String?> downloadBackupContent(String fileName) async {
    return await _newService.downloadBackupContent(fileName);
  }

  /// Delete file
  Future<void> deleteFile() async {
    await _newService.deleteInventoryFile();
  }

  /// Check if file exists
  Future<bool> fileExists() async {
    return await _newService.inventoryFileExists();
  }

  /// Legacy method - Upload from box (maintained for compatibility)
  Future<void> uploadFromBox(Box<InventoryEntry> box) async {
    await _newService.uploadFromBox(box);
  }
}