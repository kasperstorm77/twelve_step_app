import 'dart:async';
import 'package:flutter/foundation.dart';
import 'drive_config.dart';
import 'windows_drive_service.dart';

// --------------------------------------------------------------------------
// Windows Drive Service Wrapper - Windows Only
// --------------------------------------------------------------------------

/// High-level Google Drive service wrapper for Windows
/// Matches MobileDriveService API with debouncing, events, and backup management
class WindowsDriveServiceWrapper {
  final WindowsDriveService _driveService;
  
  bool _syncEnabled;
  
  // Debouncing for uploads
  Timer? _uploadTimer;
  final Duration _uploadDelay;

  // Events
  final StreamController<bool> _syncStateController = StreamController.broadcast();
  final StreamController<String> _uploadController = StreamController.broadcast();
  final StreamController<String> _downloadController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();

  WindowsDriveServiceWrapper({
    required WindowsDriveService driveService,
    bool syncEnabled = false,
    Duration uploadDelay = const Duration(milliseconds: 700),
  })  : _driveService = driveService,
        _syncEnabled = syncEnabled,
        _uploadDelay = uploadDelay;

  // Factory constructor
  static Future<WindowsDriveServiceWrapper> create({
    required GoogleDriveConfig config,
    bool syncEnabled = false,
    Duration uploadDelay = const Duration(milliseconds: 700),
  }) async {
    final driveService = await WindowsDriveService.create();
    return WindowsDriveServiceWrapper(
      driveService: driveService,
      syncEnabled: syncEnabled,
      uploadDelay: uploadDelay,
    );
  }

  // Getters
  bool get syncEnabled => _syncEnabled;
  bool get isAuthenticated => _driveService.isSignedIn;
  WindowsDriveService get driveService => _driveService;
  
  // Streams
  Stream<bool> get onSyncStateChanged => _syncStateController.stream;
  Stream<String> get onUpload => _uploadController.stream;
  Stream<String> get onDownload => _downloadController.stream;
  Stream<String> get onError => _errorController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _driveService.initializeAuth();
  }

  /// Set sync enabled state
  Future<void> setSyncEnabled(bool enabled) async {
    _syncEnabled = enabled;
    _syncStateController.add(enabled);
  }

  /// Schedule an upload with debouncing (700ms delay by default)
  void scheduleUpload(String content) {
    if (!_syncEnabled || !_driveService.isSignedIn) return;

    // Cancel existing timer
    _uploadTimer?.cancel();

    // Schedule new upload
    _uploadTimer = Timer(_uploadDelay, () async {
      await _performUpload(content);
    });
  }

  /// Perform the actual upload with backup creation
  Future<void> _performUpload(String content) async {
    if (!_syncEnabled || !_driveService.isSignedIn) return;

    try {
      // Upload to main file (automatically creates dated backup and cleans up old ones)
      final fileId = await _driveService.uploadFile(
        fileName: _driveService.config.fileName,
        content: content,
      );

      if (fileId != null) {
        _uploadController.add(content);
        if (kDebugMode) print('Windows Drive: Upload successful');
      }
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Upload failed: $e');
      _errorController.add(e.toString());
    }
  }

  /// Download content from Drive
  Future<String?> downloadContent() async {
    if (!_driveService.isSignedIn) {
      if (kDebugMode) print('Windows Drive: Not signed in');
      return null;
    }

    try {
      final content = await _driveService.downloadFile(
        fileName: _driveService.config.fileName,
      );
      
      if (content != null) {
        _downloadController.add(content);
      }
      
      return content;
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Download failed: $e');
      _errorController.add(e.toString());
      return null;
    }
  }

  /// List available backup files from Drive
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    if (!_driveService.isSignedIn) {
      if (kDebugMode) print('Windows Drive: Not signed in');
      return [];
    }

    try {
      return await _driveService.listAvailableBackups();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: List backups failed: $e');
      _errorController.add(e.toString());
      return [];
    }
  }

  /// Download content from a specific backup file
  Future<String?> downloadBackupContent(String fileName) async {
    if (!_driveService.isSignedIn) {
      if (kDebugMode) print('Windows Drive: Not signed in');
      return null;
    }

    try {
      return await _driveService.downloadBackupContent(fileName);
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Download backup failed: $e');
      _errorController.add(e.toString());
      return null;
    }
  }

  /// Check if file exists on Drive
  Future<bool> fileExists() async {
    if (!_driveService.isSignedIn) return false;
    
    try {
      return await _driveService.fileExists(
        fileName: _driveService.config.fileName,
      );
    } catch (e) {
      if (kDebugMode) print('Windows Drive: File exists check failed: $e');
      return false;
    }
  }

  /// Delete file from Drive
  Future<bool> deleteContent() async {
    if (!_driveService.isSignedIn) return false;
    
    try {
      return await _driveService.deleteFile(
        fileName: _driveService.config.fileName,
      );
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Delete failed: $e');
      _errorController.add(e.toString());
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _uploadTimer?.cancel();
    _syncStateController.close();
    _uploadController.close();
    _downloadController.close();
    _errorController.close();
  }
}
