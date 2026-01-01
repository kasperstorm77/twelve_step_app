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
  bool get isAuthenticated => _authService.isSignedIn || _driveClient != null;
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

  /// Set external client from access token (for when authentication happens outside this service)
  Future<void> setExternalClientFromToken(String accessToken) async {
    _driveClient = await GoogleDriveCrudClient.create(
      accessToken: accessToken,
      config: _authService.config,
    );
  }

  /// Clear the external client (used on sign-out)
  void clearExternalClient() {
    _driveClient = null;
  }

  /// Upload content to Drive
  Future<void> uploadContent(String content) async {
    if (kDebugMode) print('MobileDriveService.uploadContent() called - syncEnabled=$_syncEnabled, _driveClient=${_driveClient != null ? "set" : "null"}');
    
    if (!_syncEnabled) {
      if (kDebugMode) print('MobileDriveService.uploadContent() - skipped: sync not enabled');
      return;
    }

    if (_driveClient == null) {
      if (kDebugMode) print('MobileDriveService.uploadContent() - _driveClient is null, trying _ensureAuthenticated');
      if (!await _ensureAuthenticated()) {
        _errorController.add('Upload failed - not authenticated');
        if (kDebugMode) print('MobileDriveService.uploadContent() - _ensureAuthenticated failed');
        return;
      }
    }

    try {
      if (kDebugMode) print('MobileDriveService.uploadContent() - creating dated backup');
      // Create dated backup with timestamp
      await _createDatedBackup(content);
      _uploadController.add('Upload successful');
      if (kDebugMode) print('MobileDriveService.uploadContent() - success!');
    } catch (e) {
      final errorMsg = 'Upload failed: $e';
      _errorController.add(errorMsg);
      if (kDebugMode) print('MobileDriveService.uploadContent() - error: $e');
      rethrow;
    }
  }

  /// Create dated backup and clean up old backups
  /// Today: keep all backups with timestamps
  /// Previous 7 days: keep only one backup per day (latest)
  Future<void> _createDatedBackup(String content) async {
    final now = DateTime.now();
    if (kDebugMode) print('MobileDriveService._createDatedBackup() - timestamp: $now');
    
    // Create today's backup first (so it exists before cleanup)
    final fileId = await _driveClient!.createDatedBackupFile(content, now);
    if (kDebugMode) print('MobileDriveService._createDatedBackup() - created backup with fileId: $fileId');
    
    // Then clean up old backups
    await _cleanupOldBackups();
  }

  /// Clean up backups: keep last 7 days, but only one backup per day for previous days
  /// Current day can have multiple backups until the day rolls over
  Future<void> _cleanupOldBackups() async {
    await _cleanupOldBackupsInternal();
  }

  /// Internal cleanup that fetches files directly (used by both upload and listAvailableBackups)
  Future<void> _cleanupOldBackupsInternal() async {
    if (_driveClient == null) return;
    
    try {
      // Fetch files directly to avoid recursion with listAvailableBackups
      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final pattern = '${baseName}_*.json';
      final files = await _driveClient!.findBackupFiles(pattern);
      if (files.isEmpty) return;
      
      // Parse files into backup info
      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        final regex = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:_(\d{2})-(\d{2})-(\d{2}))?');
        final match = regex.firstMatch(file.name ?? '');
        if (match != null) {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          int hour = 0, minute = 0, second = 0;
          if (match.group(4) != null) {
            hour = int.parse(match.group(4)!);
            minute = int.parse(match.group(5)!);
            second = int.parse(match.group(6)!);
          }
          final date = DateTime(year, month, day, hour, minute, second);
          backups.add({'fileName': file.name, 'date': date});
        }
      }
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekCutoff = today.subtract(const Duration(days: 7));
      final yearCutoff = DateTime(now.year - 1, now.month, now.day);
      
      // Group backups by date (for daily) and by month (for monthly)
      final backupsByDate = <DateTime, List<Map<String, dynamic>>>{};
      final backupsByMonth = <String, List<Map<String, dynamic>>>{};
      
      for (final backup in backups) {
        final backupDate = backup['date'] as DateTime;
        final dateOnly = DateTime(backupDate.year, backupDate.month, backupDate.day);
        final monthKey = '${backupDate.year}-${backupDate.month.toString().padLeft(2, '0')}';
        
        if (!backupsByDate.containsKey(dateOnly)) {
          backupsByDate[dateOnly] = [];
        }
        backupsByDate[dateOnly]!.add(backup);
        
        if (!backupsByMonth.containsKey(monthKey)) {
          backupsByMonth[monthKey] = [];
        }
        backupsByMonth[monthKey]!.add(backup);
      }
      
      // Track which backups to keep (by fileName)
      final backupsToKeep = <String>{};
      
      // Process daily backups (today and last 7 days)
      for (final entry in backupsByDate.entries) {
        final date = entry.key;
        final dateBackups = entry.value;
        
        if (date.isAtSameMomentAs(today) || date.isAfter(today)) {
          // Today: keep all
          for (final backup in dateBackups) {
            backupsToKeep.add(backup['fileName'] as String);
          }
        } else if (date.isAfter(weekCutoff) || date.isAtSameMomentAs(weekCutoff)) {
          // Last 7 days: keep only the latest per day
          dateBackups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
          backupsToKeep.add(dateBackups.first['fileName'] as String);
        }
        // Older than 7 days: handled by monthly logic below
      }
      
      // Process monthly backups (for dates older than 7 days but within last year)
      for (final entry in backupsByMonth.entries) {
        final monthBackups = entry.value;
        
        // Filter to only backups older than 7 days and within the last year
        final eligibleBackups = monthBackups.where((backup) {
          final backupDate = backup['date'] as DateTime;
          final dateOnly = DateTime(backupDate.year, backupDate.month, backupDate.day);
          return dateOnly.isBefore(weekCutoff) && 
                 (dateOnly.isAfter(yearCutoff) || dateOnly.isAtSameMomentAs(yearCutoff));
        }).toList();
        
        if (eligibleBackups.isNotEmpty) {
          // Keep only the latest backup for this month
          eligibleBackups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
          backupsToKeep.add(eligibleBackups.first['fileName'] as String);
        }
      }
      
      // Delete all backups not in the keep set
      for (final backup in backups) {
        final fileName = backup['fileName'] as String;
        if (!backupsToKeep.contains(fileName)) {
          await _deleteBackup(fileName);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to cleanup old backups: $e');
    }
  }
  
  /// Delete a backup file by name
  /// Returns true if deleted, false if not found or error
  Future<bool> _deleteBackup(String fileName) async {
    try {
      final query = "name='$fileName' and trashed=false";
      final result = await _driveClient!.listFiles(query: query);
      if (result.isEmpty) {
        // File not found - may have already been deleted
        if (kDebugMode) print('Backup not found (already deleted?): $fileName');
        return false;
      }
      await _driveClient!.deleteFile(result.first.id!);
      if (kDebugMode) print('Deleted backup: $fileName');
      return true;
    } catch (e) {
      // 404 means file was already deleted - treat as success
      if (e.toString().contains('404') || e.toString().contains('File not found')) {
        if (kDebugMode) print('Backup already deleted: $fileName');
        return false;
      }
      if (kDebugMode) print('Failed to delete backup $fileName: $e');
      return false;
    }
  }

  /// Delete all backup files (DEBUG ONLY)
  Future<int> deleteAllBackups() async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        return 0;
      }
    }

    try {
      final backups = await listAvailableBackups();
      int deletedCount = 0;
      
      for (final backup in backups) {
        final fileName = backup['fileName'] as String;
        await _deleteBackup(fileName);
        deletedCount++;
      }
      
      if (kDebugMode) print('Deleted $deletedCount backup files');
      return deletedCount;
    } catch (e) {
      if (kDebugMode) print('Failed to delete all backups: $e');
      return 0;
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
      // NOTE: Cleanup is NOT run here - only after uploading a new backup.
      // This ensures users can see and restore from old backups on fresh installs.
      
      // Find all backup files matching pattern
      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final pattern = '${baseName}_*.json';
      if (kDebugMode) print('MobileDriveService: searching for backup files with pattern: $pattern');
      final files = await _driveClient!.findBackupFiles(pattern);
      if (kDebugMode) print('MobileDriveService: found ${files.length} backup files');
      
      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        // Extract date and time from filename (e.g., twelve_steps_backup_2025-12-03_14-30-15.json)
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

  /// Get the newest backup's Drive-modified timestamp (fast path for conflict checks).
  ///
  /// This avoids downloading/parsing the JSON backup content just to read `lastModified`.
  ///
  /// If [runCleanup] is true, retention cleanup runs first (may be slower).
  Future<DateTime?> getNewestBackupModifiedTime({bool runCleanup = false}) async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        return null;
      }
    }

    try {
      if (runCleanup) {
        await _cleanupOldBackupsInternal();
      }

      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final pattern = '${baseName}_*.json';
      final driveClient = _driveClient;
      if (driveClient == null) return null;

      final files = await driveClient.findBackupFiles(pattern);
      if (files.isEmpty) return null;

      DateTime? newest;
      for (final file in files) {
        final ts = file.modifiedTime ?? file.createdTime;
        if (ts == null) continue;
        if (newest == null) {
          newest = ts;
        } else if (ts.isAfter(newest)) {
          newest = ts;
        }
      }

      return newest?.toUtc();
    } catch (e) {
      if (kDebugMode) print('MobileDriveService.getNewestBackupModifiedTime() failed: $e');
      return null;
    }
  }

  /// Get the newest backup's `lastModified` timestamp from the JSON itself.
  ///
  /// This matches the app's conflict-detection semantics and avoids comparing against
  /// Drive's file-level `modifiedTime` (which can be slightly later than the JSON timestamp).
  ///
  /// Uses a small prefix download to extract the field, falling back to a full download
  /// only if needed.
  Future<DateTime?> getNewestBackupJsonLastModified({bool runCleanup = false}) async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        return null;
      }
    }

    try {
      if (runCleanup) {
        await _cleanupOldBackupsInternal();
      }

      final driveClient = _driveClient;
      if (driveClient == null) return null;

      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final pattern = '${baseName}_*.json';
      final files = await driveClient.findBackupFiles(pattern);
      if (files.isEmpty) return null;

      // Pick newest by timestamp in filename if possible (most robust across APIs).
      final regex = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:_(\d{2})-(\d{2})-(\d{2}))?');
      DateTime? bestTs;
      String? bestId;

      for (final file in files) {
        final name = file.name ?? '';
        final match = regex.firstMatch(name);
        if (match == null) continue;

        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
        final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
        final second = int.tryParse(match.group(6) ?? '0') ?? 0;
        final ts = DateTime(year, month, day, hour, minute, second).toUtc();

        if (bestTs == null || ts.isAfter(bestTs)) {
          bestTs = ts;
          bestId = file.id;
        }
      }

      // Fallback if parsing failed: use the first file returned (Drive API sorts by name desc).
      final fileId = bestId ?? files.first.id;
      if (fileId == null) return null;

      final lastModifiedRegex = RegExp(r'"lastModified"\s*:\s*"([^"]+)"');
      for (final maxBytes in const [8192, 65536]) {
        final prefix = await driveClient.readFilePrefix(fileId, maxBytes: maxBytes);
        if (prefix == null) continue;

        final match = lastModifiedRegex.firstMatch(prefix);
        if (match != null) {
          return DateTime.parse(match.group(1)!).toUtc();
        }
      }

      // Last resort: full download and JSON parse.
      final full = await driveClient.readFile(fileId);
      if (full == null) return null;

      final match = lastModifiedRegex.firstMatch(full);
      if (match == null) return null;
      return DateTime.parse(match.group(1)!).toUtc();
    } catch (e) {
      if (kDebugMode) print('MobileDriveService.getNewestBackupJsonLastModified() failed: $e');
      return null;
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

  /// Download content from Drive (reads the most recent backup file)
  Future<String?> downloadContent() async {
    if (_driveClient == null) {
      if (!await _ensureAuthenticated()) {
        _errorController.add('Download failed - not authenticated');
        return null;
      }
    }

    try {
      // Find the most recent backup file
      final backups = await listAvailableBackups();
      if (backups.isEmpty) {
        if (kDebugMode) print('No backup files found on Drive');
        return null;
      }
      
      // backups are sorted newest first, so take the first one
      final mostRecent = backups.first;
      final fileName = mostRecent['fileName'] as String;
      if (kDebugMode) print('Downloading most recent backup: $fileName');
      
      final content = await _driveClient!.readBackupFile(fileName);
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
    // If we already have a drive client (e.g., from setExternalClientFromToken), we're authenticated
    if (_driveClient != null) {
      return true;
    }
    
    // Otherwise, check if the auth service has a signed-in user
    if (_authService.isSignedIn) {
      await _createDriveClient();
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