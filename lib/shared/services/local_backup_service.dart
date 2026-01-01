import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'sync_payload_builder.dart';

// --------------------------------------------------------------------------
// Local Backup Service - Mirrors Drive backup functionality locally
// --------------------------------------------------------------------------

/// Local backup service that mirrors Drive backup behavior exactly.
/// - Same file naming pattern (twelve_steps_backup_YYYY-MM-DD_HH-MM-SS.json)
/// - Same retention policy (today: all backups, previous 7 days: one per day)
/// - Same list/create/restore interface
/// 
/// Used when user is not signed into Google Drive, providing offline backup capability.
/// Drive backups always take precedence when user is signed in.
class LocalBackupService {
  static LocalBackupService? _instance;
  static LocalBackupService get instance {
    _instance ??= LocalBackupService._();
    return _instance!;
  }

  LocalBackupService._();

  /// Base filename (matches Drive backup naming)
  static const String _baseFileName = 'twelve_steps_backup';
  
  /// Debounce timer for scheduling backups
  Timer? _backupDebounceTimer;
  static const Duration _backupDebounceDelay = Duration(milliseconds: 1000);
  
  /// Flag to prevent concurrent backups
  bool _backupInProgress = false;

  /// Get the local backup directory
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Schedule a debounced backup (mirrors Drive's scheduleUploadFromBox)
  void scheduleBackup() {
    if (kDebugMode) print('LocalBackupService: scheduleBackup called');
    
    // Cancel any pending backup and reset the timer
    _backupDebounceTimer?.cancel();
    
    _backupDebounceTimer = Timer(_backupDebounceDelay, () async {
      await _performDebouncedBackup();
    });
    
    if (kDebugMode) print('LocalBackupService: Backup scheduled (debounced ${_backupDebounceDelay.inMilliseconds}ms)');
  }

  /// Internal method to perform the actual backup after debounce
  Future<void> _performDebouncedBackup() async {
    if (_backupInProgress) {
      if (kDebugMode) print('LocalBackupService: Backup skipped - already in progress');
      return;
    }
    
    _backupInProgress = true;

    try {
      final content = _buildBackupContent();
      await _createDatedBackup(content);
      if (kDebugMode) print('LocalBackupService: Debounced backup completed');
    } catch (e) {
      if (kDebugMode) print('LocalBackupService: Backup failed: $e');
    } finally {
      _backupInProgress = false;
    }
  }

  /// Build the backup JSON content using centralized SyncPayloadBuilder
  /// This ensures local backup format is identical to Drive backup
  String _buildBackupContent() {
    return SyncPayloadBuilder.buildJsonString();
  }

  /// Create a dated backup file (mirrors Drive's _createDatedBackup)
  Future<void> _createDatedBackup(String content) async {
    final now = DateTime.now();
    final backupDir = await _getBackupDirectory();
    
    // Generate dated filename with timestamp (e.g., twelve_steps_backup_2025-12-03_14-30-15.json)
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final fileName = '${_baseFileName}_${dateStr}_$timeStr.json';
    
    final file = File('${backupDir.path}/$fileName');
    await file.writeAsString(content);
    
    if (kDebugMode) print('LocalBackupService: Created backup: $fileName');
    
    // Clean up old backups after creating new one
    await _cleanupOldBackups();
  }

  /// Clean up backups: keep last 7 days, but only one backup per day for previous days
  /// Current day can have multiple backups until the day rolls over
  Future<void> _cleanupOldBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files = await backupDir.list().toList();
      
      final backupFiles = <File>[];
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          final fileName = entity.path.split('/').last;
          if (fileName.startsWith(_baseFileName)) {
            backupFiles.add(entity);
          }
        }
      }
      
      if (backupFiles.isEmpty) return;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoffDate = today.subtract(const Duration(days: 7));
      
      // Group backups by date
      final backupsByDate = <DateTime, List<File>>{};
      for (final file in backupFiles) {
        final date = _extractDateFromFileName(file.path.split('/').last);
        if (date != null) {
          final dateOnly = DateTime(date.year, date.month, date.day);
          backupsByDate.putIfAbsent(dateOnly, () => []).add(file);
        }
      }
      
      // Process each date
      for (final entry in backupsByDate.entries) {
        final date = entry.key;
        final files = entry.value;
        
        // Delete backups older than 7 days
        if (date.isBefore(cutoffDate)) {
          for (final file in files) {
            await file.delete();
            if (kDebugMode) print('LocalBackupService: Deleted old backup: ${file.path}');
          }
          continue;
        }
        
        // For previous days (not today), keep only the latest backup
        if (date.isBefore(today) && files.length > 1) {
          // Sort by date extracted from filename (newest first)
          files.sort((a, b) {
            final dateA = _extractDateFromFileName(a.path.split('/').last);
            final dateB = _extractDateFromFileName(b.path.split('/').last);
            if (dateA == null || dateB == null) return 0;
            return dateB.compareTo(dateA);
          });
          
          // Keep first (newest), delete rest
          for (int i = 1; i < files.length; i++) {
            await files[i].delete();
            if (kDebugMode) print('LocalBackupService: Deleted duplicate backup: ${files[i].path}');
          }
        }
        // Today's backups: keep all
      }
    } catch (e) {
      if (kDebugMode) print('LocalBackupService: Cleanup failed: $e');
    }
  }

  /// Extract date from filename (e.g., twelve_steps_backup_2025-12-03_14-30-15.json)
  DateTime? _extractDateFromFileName(String fileName) {
    final regex = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:_(\d{2})-(\d{2})-(\d{2}))?');
    final match = regex.firstMatch(fileName);
    
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
      
      return DateTime(year, month, day, hour, minute, second);
    }
    return null;
  }

  /// List available local backup files (mirrors Drive's listAvailableBackups)
  Future<List<Map<String, dynamic>>> listAvailableBackups() async {
    if (kDebugMode) print('LocalBackupService.listAvailableBackups() called');
    
    try {
      // NOTE: Cleanup is NOT run here - only after creating a new backup.
      // This ensures users can see and restore from old backups.
      
      final backupDir = await _getBackupDirectory();
      final files = await backupDir.list().toList();
      
      final backups = <Map<String, dynamic>>[];
      
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          final fileName = entity.path.split('/').last;
          if (!fileName.startsWith(_baseFileName)) continue;
          
          final date = _extractDateFromFileName(fileName);
          if (date == null) continue;
          
          final dateOnly = DateTime(date.year, date.month, date.day);
          
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
            'fileName': fileName,
            'filePath': entity.path,
            'date': date,
            'dateOnly': dateOnly,
            'displayDate': displayDate,
          });
        }
      }
      
      // Sort by date descending (newest first)
      backups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      if (kDebugMode) print('LocalBackupService: Found ${backups.length} local backups');
      return backups;
    } catch (e) {
      if (kDebugMode) print('LocalBackupService: Failed to list backups: $e');
      return [];
    }
  }

  /// Download/read content from a specific local backup file
  Future<String?> downloadBackupContent(String fileName) async {
    try {
      final backupDir = await _getBackupDirectory();
      final file = File('${backupDir.path}/$fileName');
      
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('LocalBackupService: Failed to read backup: $e');
      return null;
    }
  }

  /// Read the latest backup content (for "Latest" option)
  Future<String?> downloadLatestBackupContent() async {
    final backups = await listAvailableBackups();
    if (backups.isEmpty) return null;
    
    final latestFileName = backups.first['fileName'] as String;
    return await downloadBackupContent(latestFileName);
  }

  /// Delete all backups (DEBUG ONLY)
  Future<int> deleteAllBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files = await backupDir.list().toList();
      
      int deletedCount = 0;
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
          deletedCount++;
        }
      }
      
      if (kDebugMode) print('LocalBackupService: Deleted $deletedCount backup files');
      return deletedCount;
    } catch (e) {
      if (kDebugMode) print('LocalBackupService: Failed to delete all backups: $e');
      return 0;
    }
  }

  /// Check if any local backups exist
  Future<bool> hasBackups() async {
    final backups = await listAvailableBackups();
    return backups.isNotEmpty;
  }

  /// Create a backup immediately (non-debounced, for manual backup button)
  Future<void> createBackupNow() async {
    if (_backupInProgress) {
      if (kDebugMode) print('LocalBackupService: Manual backup skipped - already in progress');
      return;
    }
    
    _backupInProgress = true;
    
    try {
      final content = _buildBackupContent();
      await _createDatedBackup(content);
      if (kDebugMode) print('LocalBackupService: Manual backup completed');
    } catch (e) {
      if (kDebugMode) print('LocalBackupService: Manual backup failed: $e');
      rethrow;
    } finally {
      _backupInProgress = false;
    }
  }
}
