import 'dart:async';
import 'package:flutter/foundation.dart';
import 'drive_config.dart';
import 'drive_crud_client.dart';
import 'mobile_google_auth_service.dart';

// --------------------------------------------------------------------------
// Mobile Google Drive Service - Android/iOS Only
// --------------------------------------------------------------------------

/// High-level Google Drive service for mobile platforms (Android/iOS)
/// Uses GoogleSignIn for authentication
class MobileDriveService {
  final MobileGoogleAuthService _authService;
  
  GoogleDriveCrudClient? _driveClient;
  bool _syncEnabled;
  
  // Debouncing for uploads
  Timer? _uploadTimer;
  final Duration _uploadDelay;

  // Events
  final StreamController<bool> _syncStateController = StreamController.broadcast();
  final StreamController<String> _uploadController = StreamController.broadcast();
  final StreamController<String> _downloadController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();

  MobileDriveService({
    required GoogleDriveConfig config,
    bool syncEnabled = false,
    Duration uploadDelay = const Duration(milliseconds: 700),
  })  : _syncEnabled = syncEnabled,
        _uploadDelay = uploadDelay,
        _authService = MobileGoogleAuthService(config: config);

  // Getters
  bool get syncEnabled => _syncEnabled;
  bool get isAuthenticated => _authService.isSignedIn;
  MobileGoogleAuthService get authService => _authService;
  
  // Streams
  Stream<bool> get onSyncStateChanged => _syncStateController.stream;
  Stream<String> get onUpload => _uploadController.stream;
  Stream<String> get onDownload => _downloadController.stream;
  Stream<String> get onError => _errorController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _authService.initializeAuth();
    if (_authService.isSignedIn) {
      await _createDriveClient();
    }
    
    // Listen to auth changes
    _authService.listenToAuthChanges((account) async {
      if (account != null) {
        await _createDriveClient();
      } else {
        _driveClient = null;
      }
    });
  }

  /// Sign in to Google
  Future<bool> signIn() async {
    final success = await _authService.signIn();
    if (success) {
      await _createDriveClient();
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

  /// Upload content to Drive
  Future<void> uploadContent(String content) async {
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
      // Create dated backup (keeps last 3 days)
      await _createDatedBackup(content);
      
      // Also update the main file for backward compatibility
      await _driveClient!.upsertFile(content);
      _uploadController.add('Upload successful');
    } catch (e) {
      final errorMsg = 'Upload failed: $e';
      _errorController.add(errorMsg);
      rethrow;
    }
  }

  /// Create dated backup and clean up old backups (keep last 3 days, one per day except today)
  Future<void> _createDatedBackup(String content) async {
    final now = DateTime.now();
    
    // Clean up today's old backups first (keep only latest per day for previous days)
    await _cleanupOldBackups();
    
    // Create today's backup
    await _driveClient!.createDatedBackupFile(content, now);
  }

  /// Clean up backups: keep last 7 days, but only one backup per day for previous days
  /// Current day can have multiple backups until the day rolls over
  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await listAvailableBackups();
      if (backups.isEmpty) return;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoffDate = today.subtract(const Duration(days: 7));
      
      // Group backups by date
      final backupsByDate = <DateTime, List<Map<String, dynamic>>>{};
      for (final backup in backups) {
        if (backup['date'] != null) {
          final backupDate = backup['date'] as DateTime;
          final dateOnly = DateTime(backupDate.year, backupDate.month, backupDate.day);
          
          if (!backupsByDate.containsKey(dateOnly)) {
            backupsByDate[dateOnly] = [];
          }
          backupsByDate[dateOnly]!.add(backup);
        }
      }
      
      // Process each date
      for (final entry in backupsByDate.entries) {
        final date = entry.key;
        final dateBackups = entry.value;
        
        // Delete backups older than 7 days
        if (date.isBefore(cutoffDate)) {
          for (final backup in dateBackups) {
            await _deleteBackup(backup['fileName'] as String);
          }
        }
        // For previous days (not today), keep only the most recent backup
        else if (date.isBefore(today) && dateBackups.length > 1) {
          // Sort by creation time (newest first)
          dateBackups.sort((a, b) {
            final dateA = a['date'] as DateTime;
            final dateB = b['date'] as DateTime;
            return dateB.compareTo(dateA);
          });
          
          // Keep the first (newest), delete the rest
          for (int i = 1; i < dateBackups.length; i++) {
            await _deleteBackup(dateBackups[i]['fileName'] as String);
          }
        }
        // For today, keep all backups (no cleanup)
      }
    } catch (e) {
      if (kDebugMode) print('Failed to cleanup old backups: $e');
    }
  }
  
  /// Delete a backup file by name
  Future<void> _deleteBackup(String fileName) async {
    try {
      final query = "name='$fileName' and trashed=false";
      final result = await _driveClient!.listFiles(query: query);
      if (result.isNotEmpty) {
        await _driveClient!.deleteFile(result.first.id!);
        if (kDebugMode) print('Deleted backup: $fileName');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to delete backup $fileName: $e');
    }
  }

  /// List available backup files from Drive
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    if (kDebugMode) print('MobileDriveService.listAvailableBackups() called');
    if (_driveClient == null) {
      if (kDebugMode) print('MobileDriveService: _driveClient is null, ensuring authenticated');
      if (!await _ensureAuthenticated()) {
        if (kDebugMode) print('MobileDriveService: _ensureAuthenticated() failed');
        return [];
      }
      if (kDebugMode) print('MobileDriveService: _ensureAuthenticated() succeeded');
    }

    try {
      // Find all backup files matching pattern
      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final pattern = '${baseName}_*.json';
      if (kDebugMode) print('MobileDriveService: searching for backup files with pattern: $pattern');
      final files = await _driveClient!.findBackupFiles(pattern);
      if (kDebugMode) print('MobileDriveService: found ${files.length} backup files');
      
      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        // Extract date and time from filename (e.g., aa4step_inventory_data_2025-11-23_14-30-15.json)
        final regex = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:_(\d{2})-(\d{2})-(\d{2}))?');
        final match = regex.firstMatch(file.name ?? '');
        
        if (kDebugMode) print('MobileDriveService: Processing file: ${file.name}');
        
        if (match != null) {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          
          // Parse time if available (for newer backups with timestamps)
          int hour = 0, minute = 0, second = 0;
          if (match.group(4) != null) {
            hour = int.parse(match.group(4)!);
            minute = int.parse(match.group(5)!);
            second = int.parse(match.group(6)!);
            if (kDebugMode) print('MobileDriveService: Parsed time: $hour:$minute:$second');
          } else {
            if (kDebugMode) print('MobileDriveService: No time found in filename');
          }
          
          final date = DateTime(year, month, day, hour, minute, second);
          final dateOnly = DateTime(year, month, day);
          
          // Format display date with time for current day, date only for previous days
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          String displayDate;
          if (dateOnly.isAtSameMomentAs(today)) {
            // Show time for today's backups
            displayDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          } else {
            // Show only date for previous days
            displayDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
          
          backups.add({
            'fileName': file.name,
            'fileId': file.id,
            'date': date,
            'dateOnly': dateOnly,
            'displayDate': displayDate,
          });
        }
      }
      
      // Sort by date descending (newest first)
      backups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      return backups;
    } catch (e) {
      if (kDebugMode) print('Failed to list backups: $e');
      return [];
    }
  }

  /// Download content from a specific backup file
  Future<String?> downloadBackupContent(String fileName) async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        _errorController.add('Download failed - not authenticated');
        return null;
      }
    }

    try {
      final content = await _driveClient!.readBackupFile(fileName);
      if (content != null) {
        _downloadController.add('Download successful');
        if (kDebugMode) print('Backup download successful: $fileName');
      }
      return content;
    } catch (e) {
      final errorMsg = 'Download failed: $e';
      _errorController.add(errorMsg);
      if (kDebugMode) print(errorMsg);
      rethrow;
    }
  }

  /// Download content from Drive
  Future<String?> downloadContent() async {
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
      }
      return content;
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
      if (kDebugMode) {
        if (deleted) print('Drive file deleted');
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
  void scheduleUpload(String content) {
    _uploadTimer?.cancel();
    _uploadTimer = Timer(_uploadDelay, () {
      uploadContent(content);
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
  }
}