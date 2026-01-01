// --------------------------------------------------------------------------
// Windows Data Management Tab
// --------------------------------------------------------------------------
// 
// PLATFORM SUPPORT: Windows only
// This provides the same Google Drive sync experience as mobile, but using
// WindowsDriveService with deep link OAuth.
// 
// Features match mobile:
// - Sign in with Google (automatic deep link OAuth)
// - Automatic sync toggle
// - JSON export/import for offline backups
// - Backup restore points (Drive when signed in, Local when not)
// --------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../eighth_step/models/person.dart';
import '../../evening_ritual/models/reflection_entry.dart';
import '../../gratitude/models/gratitude_entry.dart';
import '../../agnosticism/models/barrier_power_pair.dart';
import '../../morning_ritual/models/ritual_item.dart';
import '../../morning_ritual/models/morning_ritual_entry.dart';
import '../localizations.dart';
import '../services/all_apps_drive_service_impl.dart';
import '../services/backup_restore_service.dart';
import '../services/local_backup_service.dart';
import '../services/sync_payload_builder.dart';

class DataManagementTab extends StatefulWidget {
  final Box<InventoryEntry> box;

  const DataManagementTab({super.key, required this.box});

  @override
  State<DataManagementTab> createState() => _DataManagementTabState();
}

class _DataManagementTabState extends State<DataManagementTab> {
  bool _isSignedIn = false;
  bool _syncEnabled = false;
  bool _initializingAuth = true;
  
  // Backup selection state
  List<Map<String, dynamic>> _availableBackups = [];
  String? _selectedBackupFileName;
  bool _loadingBackups = false;

  @override
  void initState() {
    super.initState();
    _initWindowsAuth();
    _initSettings();
    // Load local backups immediately (will reload Drive backups after auth if signed in)
    _loadAvailableBackups();
  }

  Future<void> _initWindowsAuth() async {
    try {
      // Initialize AllAppsDriveService which handles platform-specific logic
      await AllAppsDriveService.instance.initialize();
      final signedIn = AllAppsDriveService.instance.isAuthenticated;
      
      if (mounted) {
        setState(() {
          _isSignedIn = signedIn;
          _initializingAuth = false;
        });
        
        // Reload backups from Drive after auth is confirmed
        if (signedIn) {
          _loadAvailableBackups();
          // Check if remote has newer data and prompt user if so
          _checkAndPromptIfRemoteNewer();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Windows auth init failed: $e');
      if (mounted) {
        setState(() {
          _initializingAuth = false;
        });
      }
    }
  }

  void _initSettings() {
    final settingsBox = Hive.box('settings');
    setState(() {
      _syncEnabled = settingsBox.get('syncEnabled', defaultValue: false);
    });
  }

  /// Load available backup restore points (Drive if signed in, Local otherwise)
  Future<void> _loadAvailableBackups() async {
    setState(() {
      _loadingBackups = true;
    });

    try {
      List<Map<String, dynamic>> backups;
      
      if (_isSignedIn) {
        // Load from Google Drive when signed in
        backups = await AllAppsDriveService.instance.listAvailableBackups();
      } else {
        // Load from local storage when not signed in
        backups = await LocalBackupService.instance.listAvailableBackups();
      }
      
      if (mounted) {
        setState(() {
          _availableBackups = backups;
          _loadingBackups = false;
          // Validate selected backup exists in new list, or select most recent
          final selectedExists = _selectedBackupFileName != null && 
              _availableBackups.any((b) => b['fileName'] == _selectedBackupFileName);
          if (!selectedExists && _availableBackups.isNotEmpty) {
            _selectedBackupFileName = _availableBackups.first['fileName'] as String?;
          } else if (_availableBackups.isEmpty) {
            _selectedBackupFileName = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBackups = false;
        });
      }
    }
  }

  Future<void> _handleSignIn() async {
    if (_isSignedIn) {
      // Sign out
      await AllAppsDriveService.instance.signOut();
      setState(() {
        _isSignedIn = false;
        _syncEnabled = false;
        // Clear backup selection on sign out
        _availableBackups = [];
        _selectedBackupFileName = null;
      });
      Hive.box('settings').put('syncEnabled', false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'signed_out'))),
        );
      }
    } else {
      // Sign in
      final success = await AllAppsDriveService.instance.signIn();
      
      if (success) {
        setState(() {
          _isSignedIn = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'signed_in'))),
          );
          
          // Only show sync enable dialog if user hasn't already configured sync
          // Check if they've ever been prompted (syncPrompted flag) or if sync is already enabled
          final settingsBox = Hive.box('settings');
          final alreadyPrompted = settingsBox.get('syncPromptedWindows', defaultValue: false);
          
          // Check for backups FIRST (used for both prompt logic and loading backup list)
          List<Map<String, dynamic>> backups = [];
          try {
            backups = await AllAppsDriveService.instance.listAvailableBackups();
            // Update UI with loaded backups
            if (mounted) {
              setState(() {
                _availableBackups = backups;
                _loadingBackups = false;
                if (_availableBackups.isNotEmpty && _selectedBackupFileName == null) {
                  _selectedBackupFileName = _availableBackups.first['fileName'] as String?;
                }
              });
            }
          } catch (e) {
            if (kDebugMode) print('_handleSignIn: Error loading backups: $e');
            if (mounted) setState(() => _loadingBackups = false);
          }
          
          if (!alreadyPrompted && !_syncEnabled) {
            if (backups.isEmpty) {
              if (kDebugMode) print('_handleSignIn: No data on Drive, skipping fetch prompt');
              // Mark as prompted and enable sync anyway so new data will be backed up
              Hive.box('settings').put('syncPromptedWindows', true);
              Hive.box('settings').put('syncEnabled', true);
              setState(() => _syncEnabled = true);
              await AllAppsDriveService.instance.setSyncEnabled(true);
            } else {
              if (kDebugMode) print('_handleSignIn: Found ${backups.length} backup(s) on Drive, showing prompt');
              _showSyncEnableDialog();
            }
          } else {
            // Already prompted or sync enabled - check if remote has newer data
            _checkAndPromptIfRemoteNewer();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'sign_in_cancelled'))),
          );
        }
      }
    }
  }

  /// Check if remote data is newer than local and prompt user to fetch if so
  Future<void> _checkAndPromptIfRemoteNewer() async {
    if (!mounted) return;
    
    try {
      if (kDebugMode) {
        print('_checkAndPromptIfRemoteNewer: Starting check...');
        print('_checkAndPromptIfRemoteNewer: isAuthenticated=${AllAppsDriveService.instance.isAuthenticated}');
        print('_checkAndPromptIfRemoteNewer: syncEnabled=${AllAppsDriveService.instance.syncEnabled}');
      }
      
      final isNewer = await AllAppsDriveService.instance.isRemoteNewer();
      
      if (kDebugMode) print('_checkAndPromptIfRemoteNewer: Remote is newer = $isNewer');
      
      if (!isNewer || !mounted) {
        // Local is up to date - make sure uploads are unblocked
        AllAppsDriveService.instance.unblockUploads();
        return;
      }
      
      // Remote has newer data - prompt user
      final shouldFetch = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // User must make a choice
        builder: (dialogContext) => AlertDialog(
          title: Text(
            t(context, 'newer_data_available'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(t(context, 'newer_data_prompt')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t(context, 'keep_local')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t(context, 'fetch')),
            ),
          ],
        ),
      );
      
      if (shouldFetch == true && mounted) {
        await _restoreFromBackup();
        // After successful restore, unblock uploads
        AllAppsDriveService.instance.unblockUploads();
      } else {
        // User chose to keep local data - unblock uploads so local changes sync
        AllAppsDriveService.instance.unblockUploads();
        if (kDebugMode) print('User chose to keep local data - uploads unblocked');
      }
    } catch (e) {
      if (kDebugMode) print('_checkAndPromptIfRemoteNewer: Error - $e');
      // On error, unblock uploads to avoid permanently blocking sync
      AllAppsDriveService.instance.unblockUploads();
    }
  }

  void _showSyncEnableDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t(context, 'enable_sync'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'enable_sync_prompt')),
        actions: [
          TextButton(
            onPressed: () {
              // Mark as prompted so we don't show again
              Hive.box('settings').put('syncPromptedWindows', true);
              Navigator.pop(dialogContext);
            },
            child: Text(t(context, 'not_now')),
          ),
          ElevatedButton(
            onPressed: () async {
              // Mark as prompted so we don't show again
              Hive.box('settings').put('syncPromptedWindows', true);
              Navigator.pop(dialogContext);
              
              // Enable sync
              setState(() => _syncEnabled = true);
              await Hive.box('settings').put('syncEnabled', true);
              await AllAppsDriveService.instance.setSyncEnabled(true);
              
              // Now ask if they want to fetch existing data from Drive
              if (mounted && _availableBackups.isNotEmpty) {
                _showFetchDataPrompt();
              }
            },
            child: Text(t(context, 'enable')),
          ),
        ],
      ),
    );
  }

  /// Show prompt asking if user wants to fetch existing data from Drive
  void _showFetchDataPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t(context, 'data_found_on_drive'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'fetch_existing_data_prompt')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // User chose to start fresh - their local data will sync to Drive on next change
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t(context, 'sync_enabled'))),
                );
              }
            },
            child: Text(t(context, 'start_fresh')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // User wants to fetch data from Drive - use direct fetch (no extra confirmation)
              await _fetchFromDriveDirectly();
            },
            child: Text(t(context, 'fetch')),
          ),
        ],
      ),
    );
  }

  /// Fetch data from Drive without showing confirmation dialog (used after user already confirmed)
  Future<void> _fetchFromDriveDirectly() async {
    if (!_isSignedIn) return;

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'fetching_data')),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    try {
      String? content;
      String? backupFileName = _selectedBackupFileName;
      
      // If no backup selected, find the most recent one
      if (backupFileName == null || backupFileName.isEmpty) {
        var backups = _availableBackups;
        if (backups.isEmpty) {
          backups = await AllAppsDriveService.instance.listAvailableBackups();
        }
        
        if (backups.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t(context, 'no_data_found'))),
            );
          }
          return;
        }
        backupFileName = backups.first['fileName'] as String?;
        if (kDebugMode) print('_fetchFromDriveDirectly: Using most recent backup: $backupFileName');
      }
      
      if (backupFileName == null || backupFileName.isEmpty) {
        if (kDebugMode) print('_fetchFromDriveDirectly: No backup file name available');
        return;
      }
      
      content = await AllAppsDriveService.instance.downloadBackupContent(backupFileName);

      if (content == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'no_backup_found'))),
          );
        }
        return;
      }

      final data = jsonDecode(content) as Map<String, dynamic>;
      final restoreResult = await _importData(data);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (restoreResult.success) {
        final c = restoreResult.counts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'fetch_success_count')
                .replaceFirst('%entries%', c.entries.toString())
                .replaceFirst('%iams%', c.iAmDefinitions.toString())
                .replaceFirst('%people%', c.people.toString())
                .replaceFirst('%reflections%', c.reflections.toString())
                .replaceFirst('%gratitude%', c.gratitude.toString())
                .replaceFirst('%agnosticism%', c.agnosticism.toString())
                .replaceFirst('%ritualItems%', c.morningRitualItems.toString())
                .replaceFirst('%ritualEntries%', c.morningRitualEntries.toString())
                .replaceFirst('%notifications%', c.notifications.toString())),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: ${restoreResult.error}')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('_fetchFromDriveDirectly: Error - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _toggleSync(bool? value) async {
    if (value == null) return;
    
    setState(() {
      _syncEnabled = value;
    });
    
    await Hive.box('settings').put('syncEnabled', value);
    await AllAppsDriveService.instance.setSyncEnabled(value);
    
    if (value && _isSignedIn) {
      // Trigger initial sync - check if remote is newer first
      await _performSync();
    }
  }

  Future<void> _performSync() async {
    if (!_isSignedIn) return;
    
    try {
      // Upload current data to Drive
      // Note: Auto-restore is disabled for data safety. User can manually restore from backup.
      final entriesBox = Hive.box<InventoryEntry>('entries');
      await AllAppsDriveService.instance.uploadFromBoxWithNotification(entriesBox);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'sync_complete'))),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'sync_failed')}: $e')),
        );
      }
    }
  }

  /// Create a local backup manually
  Future<void> _createLocalBackup() async {
    try {
      await LocalBackupService.instance.createBackupNow();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'backup_created'))),
      );
      
      // Refresh the backup list
      await _loadAvailableBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'backup_failed')}: $e')),
      );
    }
  }

  /// Restore data from selected backup (Drive if signed in, Local otherwise)
  Future<void> _restoreFromBackup() async {
    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'warning')),
        content: Text(t(context, 'import_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(context, 'continue')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      String? content;
      String? backupFileName = _selectedBackupFileName;
      
      if (_isSignedIn) {
        // Restore from Google Drive
        // If no backup selected, find the most recent one
        if (backupFileName == null || backupFileName.isEmpty) {
          // Use cached list or fetch fresh if empty
          var backups = _availableBackups;
          if (backups.isEmpty) {
            backups = await AllAppsDriveService.instance.listAvailableBackups();
          }
          
          if (backups.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(context, 'no_data_found'))),
              );
            }
            return;
          }
          // Backups are sorted newest first
          backupFileName = backups.first['fileName'] as String?;
          if (kDebugMode) print('_restoreFromBackup: Using most recent Drive backup: $backupFileName');
        }
        
        if (backupFileName == null || backupFileName.isEmpty) {
          if (kDebugMode) print('_restoreFromBackup: No backup file name available');
          return;
        }
        
        content = await AllAppsDriveService.instance.downloadBackupContent(backupFileName);
      } else {
        // Restore from local backup
        // If no backup selected, find the most recent one
        if (backupFileName == null || backupFileName.isEmpty) {
          var backups = _availableBackups;
          if (backups.isEmpty) {
            backups = await LocalBackupService.instance.listAvailableBackups();
          }
          
          if (backups.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(context, 'no_data_found'))),
              );
            }
            return;
          }
          // Backups are sorted newest first
          backupFileName = backups.first['fileName'] as String?;
          if (kDebugMode) print('_restoreFromBackup: Using most recent local backup: $backupFileName');
        }
        
        if (backupFileName == null || backupFileName.isEmpty) {
          if (kDebugMode) print('_restoreFromBackup: No local backup file name available');
          return;
        }
        
        content = await LocalBackupService.instance.downloadBackupContent(backupFileName);
      }

      if (content == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'no_backup_found'))),
          );
        }
        return;
      }

      final data = jsonDecode(content) as Map<String, dynamic>;
      final restoreResult = await _importData(data);

      if (!mounted) return;
      
      if (restoreResult.success) {
        final c = restoreResult.counts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'fetch_success_count')
                .replaceFirst('%entries%', c.entries.toString())
                .replaceFirst('%iams%', c.iAmDefinitions.toString())
                .replaceFirst('%people%', c.people.toString())
                .replaceFirst('%reflections%', c.reflections.toString())
                .replaceFirst('%gratitude%', c.gratitude.toString())
                .replaceFirst('%agnosticism%', c.agnosticism.toString())
                .replaceFirst('%ritualItems%', c.morningRitualItems.toString())
                .replaceFirst('%ritualEntries%', c.morningRitualEntries.toString())
                .replaceFirst('%notifications%', c.notifications.toString())),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: ${restoreResult.error}')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Restore failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final data = _prepareExportData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: t(context, 'export_data'),
        fileName: 'twelve_steps_backup_${DateTime.now().toIso8601String().split('T')[0]}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'export_success'))),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'export_failed')}: $e')),
        );
      }
    }
  }

  /// Prepare export data using centralized SyncPayloadBuilder
  /// This ensures export format is identical to Drive backup and local backup
  Map<String, dynamic> _prepareExportData() {
    return SyncPayloadBuilder.buildPayload();
  }

  Future<void> _importJson() async {
    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(context, 'warning'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'import_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(context, 'continue')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      final path = result.files.single.path!;
      final file = File(path);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final restoreResult = await _importData(data);

      if (!mounted) return;
      
      if (restoreResult.success) {
        final c = restoreResult.counts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'fetch_success_count')
                .replaceFirst('%entries%', c.entries.toString())
                .replaceFirst('%iams%', c.iAmDefinitions.toString())
                .replaceFirst('%people%', c.people.toString())
                .replaceFirst('%reflections%', c.reflections.toString())
                .replaceFirst('%gratitude%', c.gratitude.toString())
                .replaceFirst('%agnosticism%', c.agnosticism.toString())
                .replaceFirst('%ritualItems%', c.morningRitualItems.toString())
                .replaceFirst('%ritualEntries%', c.morningRitualEntries.toString())
                .replaceFirst('%notifications%', c.notifications.toString())),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: ${restoreResult.error}')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Import failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: $e')),
        );
      }
    }
  }

  /// Centralized import method that uses BackupRestoreService for consistent restore behavior.
  /// Returns the RestoreResult with counts and success status.
  Future<RestoreResult> _importData(Map<String, dynamic> data) async {
    // Use centralized BackupRestoreService for consistent restore behavior
    return await BackupRestoreService.restoreFromPayload(
      data,
      createSafetyBackup: true, // Always create safety backup before restore
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializingAuth) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final buttonText = _isSignedIn 
        ? t(context, 'sign_out_google')
        : t(context, 'sign_in_google');

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      children: [
        // Google Sign-In button
        ElevatedButton.icon(
          onPressed: _handleSignIn,
          icon: _isSignedIn ? const Icon(Icons.logout) : const Icon(Icons.login),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Sync toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t(context, 'sync_google_drive'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Tooltip(
              message: _isSignedIn ? '' : t(context, 'sign_in_to_enable_sync'),
              child: Switch(
                value: _syncEnabled,
                onChanged: _isSignedIn ? _toggleSync : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Divider(),
        const SizedBox(height: 16),

        // JSON Export/Import
        Text(
          t(context, 'offline_backups'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        ElevatedButton(
          onPressed: _exportJson,
          child: Text(t(context, 'export_json')),
        ),
        const SizedBox(height: 12),
        
        ElevatedButton(
          onPressed: _importJson,
          child: Text(t(context, 'import_json')),
        ),
        
        const SizedBox(height: 24),
        
        // Backup selection dropdown and restore button
        // Shows Drive backups when signed in, Local backups when not
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _isSignedIn ? Icons.cloud : Icons.folder,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSignedIn
                            ? t(context, 'select_restore_point_drive')
                            : t(context, 'select_restore_point_local'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_loadingBackups)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadAvailableBackups,
                        tooltip: t(context, 'refresh_backups'),
                      ),
                  ],
                ),
                // Show note for local backups
                if (!_isSignedIn) ...[
                  const SizedBox(height: 4),
                  Text(
                    t(context, 'local_backup_note'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_availableBackups.isEmpty && !_loadingBackups)
                  Text(
                    t(context, 'no_backups_available'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedBackupFileName,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelText: t(context, 'restore_point_latest'),
                    ),
                    items: [
                      // Add "Latest" option (uses most recent backup)
                      DropdownMenuItem<String>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(
                              _isSignedIn ? Icons.cloud : Icons.folder,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t(context, 'restore_point_latest'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add dated backups
                      ..._availableBackups.map((backup) {
                        final displayDate = backup['displayDate'] as String;
                        final fileName = backup['fileName'] as String;
                        return DropdownMenuItem<String>(
                          value: fileName,
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayDate,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBackupFileName = value;
                      });
                    },
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _restoreFromBackup,
                  icon: const Icon(Icons.download),
                  label: Text(t(context, 'restore_from_backup')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                // Create Local Backup button (only when not signed in)
                if (!_isSignedIn) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _createLocalBackup,
                    icon: const Icon(Icons.save),
                    label: Text(t(context, 'create_local_backup')),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Clear all data button
        const Divider(),
        const SizedBox(height: 16),
        
        ElevatedButton(
          onPressed: _confirmClearAll,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(t(context, 'clear_all')),
        ),
      ],
    );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t(context, 'confirm_clear'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'clear_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(context, 'clear')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'all_cleared'))),
      );
    }
  }

  Future<void> _clearAllData() async {
    // Create safety backup before destructive clear operation
    await BackupRestoreService.createPreRestoreSafetyBackup();
    
    await Hive.box<InventoryEntry>('entries').clear();
    await Hive.box<IAmDefinition>('i_am_definitions').clear();
    await Hive.box<Person>('people_box').clear();
    await Hive.box<ReflectionEntry>('reflections_box').clear();
    await Hive.box<GratitudeEntry>('gratitude_box').clear();
    await Hive.box<BarrierPowerPair>('agnosticism_pairs').clear();
    await Hive.box<RitualItem>('morning_ritual_items').clear();
    await Hive.box<MorningRitualEntry>('morning_ritual_entries').clear();
  }
}
