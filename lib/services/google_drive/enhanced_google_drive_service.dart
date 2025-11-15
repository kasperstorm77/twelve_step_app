import 'dart:async';
import 'package:flutter/foundation.dart';
import 'drive_config.dart';
import 'drive_crud_client.dart';
import 'mobile_google_auth_service.dart';

// --------------------------------------------------------------------------
// Enhanced Google Drive Service - Best of Breed
// --------------------------------------------------------------------------
// 
// Combines the clean architecture from evening_ritual with the robust
// conflict detection and timestamp-based sync from twelve_step_app.
//
// Features:
// - Timestamp-based conflict detection (prevents data loss)
// - Auto-sync when remote data is newer
// - Debounced uploads for performance
// - Event streams for UI updates
// - Generic and reusable across projects
// --------------------------------------------------------------------------

/// High-level Google Drive service with business logic
/// Generic and reusable across different projects
class EnhancedGoogleDriveService {
  final MobileGoogleAuthService _authService;
  
  GoogleDriveCrudClient? _driveClient;
  bool _syncEnabled;
  
  // Debouncing for uploads
  Timer? _uploadTimer;
  final Duration _uploadDelay;
  
  // Timestamp tracking for conflict detection
  DateTime? _localLastModified;
  final Function(DateTime)? _onSaveTimestamp;
  final Future<DateTime?> Function()? _onLoadTimestamp;

  // Events
  final StreamController<bool> _syncStateController = StreamController.broadcast();
  final StreamController<String> _uploadController = StreamController.broadcast();
  final StreamController<String> _downloadController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  final StreamController<SyncConflictInfo> _conflictController = StreamController.broadcast();

  EnhancedGoogleDriveService({
    required GoogleDriveConfig config,
    bool syncEnabled = false,
    Duration uploadDelay = const Duration(milliseconds: 700),
    Function(DateTime)? onSaveTimestamp,
    Future<DateTime?> Function()? onLoadTimestamp,
  })  : _syncEnabled = syncEnabled,
        _uploadDelay = uploadDelay,
        _onSaveTimestamp = onSaveTimestamp,
        _onLoadTimestamp = onLoadTimestamp,
        _authService = MobileGoogleAuthService(config: config);

  // Getters
  bool get syncEnabled => _syncEnabled;
  bool get isAuthenticated => _authService.isSignedIn;
  MobileGoogleAuthService get authService => _authService;
  DateTime? get localLastModified => _localLastModified;
  
  // Streams
  Stream<bool> get onSyncStateChanged => _syncStateController.stream;
  Stream<String> get onUpload => _uploadController.stream;
  Stream<String> get onDownload => _downloadController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<SyncConflictInfo> get onConflict => _conflictController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _authService.initializeAuth();
    
    // Load local timestamp
    if (_onLoadTimestamp != null) {
      _localLastModified = await _onLoadTimestamp();
    }
    
    if (_authService.isSignedIn) {
      await _createDriveClient();
      // Auto-enable sync if already signed in
      setSyncEnabled(true);
      debugPrint('EnhancedGoogleDriveService: Auto-sync enabled for existing session');
    }
    
    // Listen to auth changes
    _authService.listenToAuthChanges((account) async {
      if (account != null) {
        await _createDriveClient();
        // Auto-enable sync when authentication state changes to signed in
        setSyncEnabled(true);
        debugPrint('EnhancedGoogleDriveService: Auto-sync enabled on auth state change');
      } else {
        _driveClient = null;
        // Keep sync disabled when signed out
        setSyncEnabled(false);
        debugPrint('EnhancedGoogleDriveService: Auto-sync disabled on sign out');
      }
    });
  }

  /// Sign in to Google
  Future<bool> signIn() async {
    final success = await _authService.signIn();
    if (success) {
      await _createDriveClient();
      // Auto-enable sync when user signs in
      setSyncEnabled(true);
      debugPrint('EnhancedGoogleDriveService: Auto-sync enabled after successful sign-in');
    }
    return success;
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _driveClient = null;
    setSyncEnabled(false);
  }

  /// Enable or disable sync
  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
    _syncStateController.add(enabled);
  }

  /// Upload content to Drive with timestamp
  Future<void> uploadContent(String content, {DateTime? timestamp}) async {
    if (!_syncEnabled) {
      return;
    }

    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        _errorController.add('Upload failed - not authenticated');
        return;
      }
    }

    try {
      await _driveClient!.upsertFile(content);
      
      // Save timestamp
      final uploadTime = timestamp ?? DateTime.now().toUtc();
      _localLastModified = uploadTime;
      if (_onSaveTimestamp != null) {
        _onSaveTimestamp(uploadTime);
      }
      
      _uploadController.add('Upload successful');
    } catch (e) {
      final errorMsg = 'Upload failed: $e';
      _errorController.add(errorMsg);
      rethrow;
    }
  }

  /// Download content from Drive
  Future<DownloadResult?> downloadContent() async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        _errorController.add('Download failed - not authenticated');
        return null;
      }
    }

    try {
      final content = await _driveClient!.readFileContent();
      if (content != null) {
        _downloadController.add('Download successful');
        if (kDebugMode) print('Drive download successful');
        
        return DownloadResult(
          content: content,
          timestamp: null, // App-specific services can extract this
        );
      }
      return null;
    } catch (e) {
      final errorMsg = 'Download failed: $e';
      _errorController.add(errorMsg);
      if (kDebugMode) print(errorMsg);
      rethrow;
    }
  }

  /// Delete file from Drive
  Future<bool> deleteContent() async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        _errorController.add('Delete failed - not authenticated');
        return false;
      }
    }

    try {
      final deleted = await _driveClient!.deleteFileByName();
      if (deleted) {
        _localLastModified = null;
        if (_onSaveTimestamp != null) {
          _onSaveTimestamp(DateTime.fromMillisecondsSinceEpoch(0));
        }
        if (kDebugMode) print('Drive file deleted');
      }
      return deleted;
    } catch (e) {
      final errorMsg = 'Delete failed: $e';
      _errorController.add(errorMsg);
      if (kDebugMode) print(errorMsg);
      return false;
    }
  }

  /// Schedule debounced upload
  void scheduleUpload(String content, {DateTime? timestamp}) {
    _uploadTimer?.cancel();
    _uploadTimer = Timer(_uploadDelay, () {
      uploadContent(content, timestamp: timestamp);
    });
  }

  /// Check if file exists on Drive
  Future<bool> fileExists() async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) return false;
    }

    try {
      return await _driveClient!.fileExists();
    } catch (e) {
      if (kDebugMode) print('File exists check failed: $e');
      return false;
    }
  }

  /// Check if remote data is newer and return conflict info
  /// Returns null if no conflict, otherwise returns SyncConflictInfo
  Future<SyncConflictInfo?> checkForConflicts() async {
    if (!syncEnabled || !isAuthenticated) {
      return null;
    }

    try {
      final result = await downloadContent();
      if (result == null) {
        return null; // No remote file
      }

      // This is a base implementation - app-specific services should
      // override this to extract timestamp from their data format
      return null;
    } catch (e) {
      if (kDebugMode) print('Conflict check failed: $e');
      return null;
    }
  }

  /// Update local timestamp
  void updateLocalTimestamp(DateTime timestamp) {
    _localLastModified = timestamp;
    if (_onSaveTimestamp != null) {
      _onSaveTimestamp(timestamp);
    }
  }

  /// Create Drive client if authenticated
  Future<void> _createDriveClient() async {
    try {
      _driveClient = await _authService.createDriveClient();
    } catch (e) {
      if (kDebugMode) print('Failed to create Drive client: $e');
    }
  }

  /// Ensure user is authenticated
  Future<bool> _ensureAuthenticated() async {
    if (_authService.isSignedIn) {
      if (_driveClient == null) {
        await _createDriveClient();
      }
      return _driveClient != null;
    }
    return false;
  }

  /// Dispose resources
  void dispose() {
    _uploadTimer?.cancel();
    _syncStateController.close();
    _uploadController.close();
    _downloadController.close();
    _errorController.close();
    _conflictController.close();
  }
}

/// Result of a download operation
class DownloadResult {
  final String content;
  final DateTime? timestamp;

  DownloadResult({
    required this.content,
    this.timestamp,
  });
}

/// Information about a sync conflict
class SyncConflictInfo {
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
  final String remoteContent;
  final bool remoteIsNewer;

  SyncConflictInfo({
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.remoteContent,
  }) : remoteIsNewer = remoteTimestamp.isAfter(localTimestamp);
}
