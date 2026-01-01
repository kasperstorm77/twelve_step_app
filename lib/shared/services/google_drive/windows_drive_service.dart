// --------------------------------------------------------------------------
// Windows Drive Service - Windows Only
// --------------------------------------------------------------------------
// 
// PLATFORM SUPPORT: Windows only
// This service provides standalone Google Drive integration for Windows,
// completely separate from mobile implementation.
// 
// Features:
// - Automatic OAuth with local HTTP server
// - Secure credential caching
// - Silent sign-in
// - Automatic token refresh
// 
// Usage: Only use when PlatformHelper.isWindows returns true.
// --------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'windows_google_auth_service.dart';
import 'drive_config.dart';
import 'drive_crud_client.dart';

/// Windows-specific Google Drive service
class WindowsDriveService {
  final WindowsGoogleAuthService _authService;
  
  WindowsDriveService({required WindowsGoogleAuthService authService})
      : _authService = authService;

  /// Get config for accessing file name
  GoogleDriveConfig get config => _authService.config;

  /// Factory constructor to create service with default configuration
  static Future<WindowsDriveService> create() async {
    // Open or create credentials box for Windows
    final credentialsBox = await Hive.openBox('windows_google_credentials');
    
    // Use same config as mobile for cross-platform sync
    const config = GoogleDriveConfig(
      fileName: 'twelve_steps_backup.json',
      mimeType: 'application/json',
      scope: 'https://www.googleapis.com/auth/drive.appdata',
      parentFolder: 'appDataFolder',
    );
    
    final authService = WindowsGoogleAuthService(
      config: config,
      credentialsBox: credentialsBox,
    );
    
    return WindowsDriveService(authService: authService);
  }

  /// Check if user is signed in
  bool get isSignedIn => _authService.isSignedIn;
  
  /// Check if user has cached credentials
  bool get hasCachedCredentials => _authService.hasCachedCredentials;
  
  /// Current access token
  String? get accessToken => _authService.accessToken;

  /// Initialize and attempt silent sign-in
  Future<bool> initializeAuth() async {
    try {
      return await _authService.initializeAuth();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Initialize auth failed: $e');
      return false;
    }
  }

  /// Interactive sign-in (opens browser automatically)
  Future<bool> signIn() async {
    try {
      return await _authService.signIn();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Sign-in failed: $e');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Upload file to Google Drive AppData folder
  /// Automatically creates a dated backup and cleans up old backups
  Future<String?> uploadFile({
    required String fileName,
    required String content,
  }) async {
    try {
      // Ensure we have valid credentials
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      // Create dated backup with timestamp (this is the only file we store now)
      final now = DateTime.now();
      final fileId = await createDatedBackup(content, now);
      
      // Clean up old backups (keeps today's all, 1 per day for last 7 days)
      await cleanupOldBackups();
      
      return fileId;
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Upload failed: $e');
      return null;
    }
  }

  /// Download file from Google Drive AppData folder
  Future<String?> downloadFile({required String fileName}) async {
    try {
      // Ensure we have valid credentials
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      return await client.readFileContent();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Download failed: $e');
      return null;
    }
  }

  /// Check if file exists in Google Drive AppData folder
  Future<bool> fileExists({required String fileName}) async {
    try {
      // Ensure we have valid credentials
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return false;
      }

      return await client.fileExists();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: File exists check failed: $e');
      return false;
    }
  }

  /// Get file metadata (including lastModified timestamp)
  Future<Map<String, dynamic>?> getFileMetadata({
    required String fileName,
  }) async {
    try {
      // Ensure we have valid credentials
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      final file = await client.getFileMetadata();
      if (file != null) {
        return {
          'id': file.id,
          'name': file.name,
          'modifiedTime': file.modifiedTime?.toIso8601String(),
          'createdTime': file.createdTime?.toIso8601String(),
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Get metadata failed: $e');
      return null;
    }
  }

  /// Delete file from Google Drive AppData folder
  Future<bool> deleteFile({required String fileName}) async {
    try {
      // Ensure we have valid credentials
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return false;
      }

      return await client.deleteFileByName();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Delete failed: $e');
      return false;
    }
  }

  /// List available backup files from Drive
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    try {
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return [];
      }

      // NOTE: Cleanup is NOT run here - only after uploading a new backup.
      // This ensures users can see and restore from old backups on fresh installs.
      
      // Find all backup files matching pattern
      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final files = await client.findBackupFiles('${baseName}_*.json');
      
      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        // Extract date and time from filename (e.g., twelve_steps_backup_2025-12-03_14-30-15.json)
        final regex = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:_(\d{2})-(\d{2})-(\d{2}))?');
        final match = regex.firstMatch(file.name ?? '');
        
        if (match != null) {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          
          // Parse time if available
          int hour = 0, minute = 0, second = 0;
          if (match.group(4) != null) {
            hour = int.parse(match.group(4)!);
            minute = int.parse(match.group(5)!);
            second = int.parse(match.group(6)!);
          }
          
          final date = DateTime(year, month, day, hour, minute, second);
          final displayDate = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          final displayTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          
          backups.add({
            'fileName': file.name,
            'displayDate': '$displayDate $displayTime',
            'date': date,
          });
        }
      }
      
      // Sort by date (newest first)
      backups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      return backups;
    } catch (e) {
      if (kDebugMode) print('Windows Drive: List backups failed: $e');
      return [];
    }
  }

  /// Get the newest backup's Drive-modified timestamp (fast path for conflict checks).
  ///
  /// This avoids downloading/parsing the JSON backup content just to read `lastModified`.
  ///
  /// If [runCleanup] is true, retention cleanup runs first (may be slower).
  Future<DateTime?> getNewestBackupModifiedTime({bool runCleanup = false}) async {
    try {
      await _authService.refreshTokenIfNeeded();
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      if (runCleanup) {
        await _cleanupOldBackupsInternal(client);
      }

      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final files = await client.findBackupFiles('${baseName}_*.json');
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
      if (kDebugMode) print('Windows Drive: getNewestBackupModifiedTime failed: $e');
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
    try {
      await _authService.refreshTokenIfNeeded();
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      if (runCleanup) {
        await _cleanupOldBackupsInternal(client);
      }

      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final files = await client.findBackupFiles('${baseName}_*.json');
      if (files.isEmpty) return null;

      // Pick newest by timestamp in filename if possible.
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

      final fileId = bestId ?? files.first.id;
      if (fileId == null) return null;

      final lastModifiedRegex = RegExp(r'"lastModified"\s*:\s*"([^"]+)"');
      for (final maxBytes in const [8192, 65536]) {
        final prefix = await client.readFilePrefix(fileId, maxBytes: maxBytes);
        if (prefix == null) continue;

        final match = lastModifiedRegex.firstMatch(prefix);
        if (match != null) {
          return DateTime.parse(match.group(1)!).toUtc();
        }
      }

      // Last resort: full download.
      final full = await client.readFile(fileId);
      if (full == null) return null;

      final match = lastModifiedRegex.firstMatch(full);
      if (match == null) return null;
      return DateTime.parse(match.group(1)!).toUtc();
    } catch (e) {
      if (kDebugMode) print('Windows Drive: getNewestBackupJsonLastModified failed: $e');
      return null;
    }
  }

  /// Download content from a specific backup file
  Future<String?> downloadBackupContent(String fileName) async {
    try {
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      return await client.readBackupFile(fileName);
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Download backup failed: $e');
      return null;
    }
  }

  /// Create dated backup file
  Future<String?> createDatedBackup(String content, DateTime date) async {
    try {
      await _authService.refreshTokenIfNeeded();
      
      final client = await _authService.createDriveClient();
      if (client == null) {
        if (kDebugMode) print('Windows Drive: Not signed in');
        return null;
      }

      return await client.createDatedBackupFile(content, date);
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Create backup failed: $e');
      return null;
    }
  }

  /// Clean up old backups: keep last 7 days, but only one backup per day for previous days
  Future<void> cleanupOldBackups() async {
    try {
      await _authService.refreshTokenIfNeeded();
      final client = await _authService.createDriveClient();
      if (client == null) return;
      await _cleanupOldBackupsInternal(client);
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Cleanup failed: $e');
    }
  }

  /// Internal cleanup that uses provided client (used by both upload and listAvailableBackups)
  Future<void> _cleanupOldBackupsInternal(GoogleDriveCrudClient client) async {
    try {
      // Fetch files directly to avoid recursion with listAvailableBackups
      final baseName = _authService.config.fileName.replaceAll('.json', '');
      final files = await client.findBackupFiles('${baseName}_*.json');
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
          await _deleteBackupFile(fileName);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Windows Drive: Cleanup failed: $e');
    }
  }

  /// Delete a specific backup file by name
  /// Returns true if deleted, false if not found or error
  Future<bool> _deleteBackupFile(String fileName) async {
    try {
      final client = await _authService.createDriveClient();
      if (client == null) return false;
      
      // Find the file
      final files = await client.findBackupFiles(fileName);
      if (files.isEmpty) {
        // File not found - may have already been deleted
        if (kDebugMode) print('Windows Drive: Backup not found (already deleted?): $fileName');
        return false;
      }
      await client.deleteFile(files.first.id!);
      if (kDebugMode) print('Windows Drive: Deleted backup: $fileName');
      return true;
    } catch (e) {
      // 404 means file was already deleted - treat as success
      if (e.toString().contains('404') || e.toString().contains('File not found')) {
        if (kDebugMode) print('Windows Drive: Backup already deleted: $fileName');
        return false;
      }
      if (kDebugMode) print('Windows Drive: Failed to delete backup $fileName: $e');
      return false;
    }
  }
}
