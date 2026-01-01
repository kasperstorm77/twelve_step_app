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
import '../utils/platform_helper.dart';

// Platform-specific imports
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
    
// Services
import '../services/google_sign_in_wrapper.dart';
import '../services/all_apps_drive_service.dart';
import '../services/backup_restore_service.dart';
import '../services/local_backup_service.dart';
import '../services/sync_payload_builder.dart';

// Google Drive scopes
const String driveAppdataScope =
    'https://www.googleapis.com/auth/drive.appdata';
const List<String> _scopes = <String>[
  'email',
  driveAppdataScope,
];

class DataManagementTab extends StatefulWidget {
  final Box<InventoryEntry> box;

  const DataManagementTab({super.key, required this.box});

  @override
  State<DataManagementTab> createState() => _DataManagementTabState();
}

class _DataManagementTabState extends State<DataManagementTab> {
  // Platform-specific: GoogleSignIn only available on mobile (Android/iOS)
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;

  bool _syncEnabled = false;
  bool _signingInProgress = false;
  bool _promptScheduled = false;
  
  // Loading state for sign-in and Drive operations
  bool _isLoading = false;
  String _loadingMessage = '';

  // Backup selection state
  List<Map<String, dynamic>> _availableBackups = [];
  String? _selectedBackupFileName;
  bool _loadingBackups = false;
  
  // Track if we've already prompted for this account this session
  // This is persisted in Hive settings so it survives page navigation
  String? get _lastPromptedAccountId {
    final value = Hive.box('settings').get('lastPromptedAccountId') as String?;
    if (kDebugMode) print('_lastPromptedAccountId getter: returning "$value"');
    return value;
  }
  set _lastPromptedAccountId(String? value) {
    if (value == null) {
      Hive.box('settings').delete('lastPromptedAccountId');
    } else {
      Hive.box('settings').put('lastPromptedAccountId', value);
    }
  }

  @override
  void initState() {
    super.initState();
    _initSettings();

    // Initialize GoogleSignIn on mobile and web platforms
    if (PlatformHelper.isMobile || PlatformHelper.isWeb) {
      _googleSignIn = PlatformHelper.isWeb
          ? GoogleSignIn(
              clientId: '628217349107-5d4fmt92g4pomceuedgsva1263ms9lir.apps.googleusercontent.com',
              scopes: _scopes,
            ) // Web requires explicit clientId
          : (Platform.isIOS
              ? GoogleSignIn(
                  scopes: _scopes,
                  // iOS requires iOS OAuth client for Drive API access
                  serverClientId: '628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k.apps.googleusercontent.com',
                )
              : GoogleSignIn(scopes: _scopes)); // Android uses default (no serverClientId)
      
      _googleSignIn!.onCurrentUserChanged.listen((account) {
        if (kDebugMode) print('onCurrentUserChanged: account=${account?.displayName}, mounted=$mounted, signingInProgress=$_signingInProgress');
        // Don't update state during an active sign-in to avoid
        // interrupting the sign-in dialog/WebView
        if (!mounted || _signingInProgress) return;
        
        setState(() {
          _currentUser = account;
          if (_currentUser == null) {
            _syncEnabled = false;
            Hive.box('settings').put('syncEnabled', false);
            AllAppsDriveService.instance.clearClient();
            // Clear backups when signed out
            _availableBackups = [];
            _selectedBackupFileName = null;
          }
        });
        if (account != null) {
          if (kDebugMode) print('onCurrentUserChanged: initializing drive client');
          _initializeDriveClient(account);
          // Load backups when signed in
          _loadAvailableBackups();
          // Note: Don't call _checkAndPromptIfRemoteNewer here - it's called from sign-in flow
          // to avoid duplicate prompts
        }
      });

      _googleSignIn!.signInSilently().catchError((e) {
        if (kDebugMode) print('Silent sign-in failed: $e');
        return null;
      });
    } else {
      // On desktop platforms, disable sync by default
      setState(() {
        _syncEnabled = false;
      });
      if (kDebugMode) {
        print('Google Drive sync not available on ${PlatformHelper.platformName}');
      }
    }
    
    // Load available backups (Drive if signed in, local otherwise)
    _loadAvailableBackups();
  }

  /// Load available backup restore points (Drive if signed in, local otherwise)
  Future<void> _loadAvailableBackups() async {
    final isSignedIn = _currentUser != null;
    if (kDebugMode) print('_loadAvailableBackups: called - isMobile=${PlatformHelper.isMobile}, isSignedIn=$isSignedIn');
    
    if (!PlatformHelper.isMobile) {
      if (kDebugMode) print('_loadAvailableBackups: skipped - not mobile');
      return;
    }
    
    setState(() {
      _loadingBackups = true;
    });

    try {
      List<Map<String, dynamic>> backups;
      
      if (isSignedIn) {
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
      if (kDebugMode) print('_loadAvailableBackups: error - $e');
      if (mounted) {
        setState(() {
          _loadingBackups = false;
        });
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'failed_load_backups')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initSettings() async {
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    final settingsBox = Hive.box('settings');
    setState(() {
      // Default to false so fresh installs show the fetch prompt on first sign-in
      _syncEnabled = settingsBox.get('syncEnabled', defaultValue: false);
    });
  }

  Future<void> _toggleSync(bool value) async {
    if (_currentUser == null) return;
    final settingsBox = Hive.box('settings');
    settingsBox.put('syncEnabled', value);
    setState(() => _syncEnabled = value);
    // Update the sync state so other parts of the app will respect it.
    await AllAppsDriveService.instance.setSyncEnabled(value);
    if (value) await _uploadToDrive();
  }

  Future<void> _initializeDriveClient(GoogleSignInAccount account) async {
    try {
      // Prefer using the Authentication API to get an access token. This is
      // more robust across platforms than parsing authHeaders.
      final auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null) {
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
              SnackBar(content: Text(t(context, 'sign_in_no_token'))));
        }
        if (kDebugMode) print('No access token returned from GoogleSignInAccount.authentication');
        return;
      }

      // Set up AllAppsDriveService with the access token
      await AllAppsDriveService.instance.setClientFromToken(accessToken);
      await AllAppsDriveService.instance.setSyncEnabled(_syncEnabled);

      // NOTE: Do NOT auto-upload here. Uploads should only happen:
      // 1. When user explicitly turns sync toggle ON
      // 2. After actual data changes (create/update/delete)
      // 3. After JSON import
      // 4. When user explicitly presses "Backup to Drive" button
    } catch (e) {
      if (kDebugMode) print('Drive initialization failed: $e');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(content: Text('${t(context, 'drive_init_failed')}: $e')));
      }
    }
  }

  Future<void> _handleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    
    // Google Sign-In only available on mobile platforms
    if (_googleSignIn == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(t(context, 'drive_not_available')))
      );
      return;
    }
    
    try {
      _signingInProgress = true; // Prevent state updates during sign-in
      setState(() {
        _isLoading = true;
        _loadingMessage = t(context, 'signing_in');
      });
      
      final account = await _googleSignIn!.signIn();
      
      _signingInProgress = false; // Sign-in complete, allow state updates
      
      if (account != null) {
        // Manually update the current user since we blocked the listener
        // Don't auto-enable sync yet - let the prompt handler decide
        setState(() {
          _currentUser = account;
          _loadingMessage = t(context, 'connecting_to_drive');
        });
        
        await _initializeDriveClient(account);
        
        // Update loading message before checking backups
        if (mounted) {
          setState(() {
            _loadingMessage = t(context, 'checking_backups');
          });
        }
        
        // Schedule the prompt; this is resilient to the ordering of
        // onCurrentUserChanged vs this handler resuming.
        // The prompt handler will also load backups for the UI.
        // NOTE: Loading will be hidden by _schedulePromptForAccount when done
        _schedulePromptForAccount(account);
      } else {
        // No account - hide loading
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingMessage = '';
          });
        }
      }
    } catch (e) {
      _signingInProgress = false; // Clear flag on error
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'sign_in_failed')}: ${e.toString().split(',').first}')));
    }
  }

  Future<void> _maybePromptFetchAfterInteractiveSignIn(GoogleSignInAccount account) async {
  // Prompt can happen either from interactive sign-in OR from silent sign-in
  // (when the user navigates to Settings tab and we detect an existing account).
  // Only prompt once ever (permanent flag) - user can manually fetch from settings anytime.
  // Also skip if sync is already enabled (backward compat for existing users).
  final settingsBox = Hive.box('settings');
  final alreadyPrompted = settingsBox.get('syncPromptedMobile', defaultValue: false);
  if (alreadyPrompted) {
    // Still load backups for UI even if we skip the prompt
    _loadAvailableBackups();
    // IMPORTANT: Enable sync even if already prompted (user signed in again)
    if (!_syncEnabled) {
      settingsBox.put('syncEnabled', true);
      if (mounted) setState(() => _syncEnabled = true);
      await AllAppsDriveService.instance.setSyncEnabled(true);
      if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: Already prompted, enabling sync automatically');
    }
    return;
  }
  if (_syncEnabled) {
    // Still load backups for UI even if we skip the prompt
    _loadAvailableBackups();
    return;  // Backward compatibility: don't prompt if sync already configured
  }
  if (_lastPromptedAccountId == account.id) {
    // Still load backups for UI even if we skip the prompt
    _loadAvailableBackups();
    // Enable sync for this account
    settingsBox.put('syncEnabled', true);
    if (mounted) setState(() => _syncEnabled = true);
    await AllAppsDriveService.instance.setSyncEnabled(true);
    return;
  }
  if (!mounted) return;

    // Check if there's data on Google Drive before prompting
    // This also loads backups for the UI
    if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: Checking if Drive has data...');
    List<Map<String, dynamic>> backups = [];
    try {
      backups = await AllAppsDriveService.instance.listAvailableBackups();
      if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: Drive has ${backups.length} backup(s)');
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
      
      if (backups.isEmpty) {
        if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: No data on Drive, skipping fetch prompt');
        // Mark as prompted and enable sync anyway so new data will be backed up
        _lastPromptedAccountId = account.id;
        Hive.box('settings').put('syncPromptedMobile', true);
        Hive.box('settings').put('syncEnabled', true);
        if (mounted) setState(() => _syncEnabled = true);
        await AllAppsDriveService.instance.setSyncEnabled(true);
        return;
      }
      if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: Found ${backups.length} backup(s) on Drive');
    } catch (e) {
      if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: Error checking Drive backups: $e');
      if (mounted) setState(() => _loadingBackups = false);
      // If we can't check, skip the prompt but don't mark as prompted
      return;
    }

    if (!mounted) return;

    // Attempt to show the dialog. Only mark this account as 'prompted' after
    // the dialog successfully completes so that failures (for example if the
    // dialog couldn't be shown) don't prevent future prompts.
    try {
      final shouldFetch = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            t(context, 'googlefetch'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(t(context, 'confirm_google_fetch')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(t(context, 'cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(t(context, 'fetch')),
            ),
          ],
        ),
      );

      // Mark that we've prompted this account so we don't show the dialog
      // repeatedly during the same session. We do this after the dialog so
      // that errors thrown while showing it don't block future attempts.
      _lastPromptedAccountId = account.id;
      // Also set permanent flag so we never prompt again
      Hive.box('settings').put('syncPromptedMobile', true);
      
      // Enable sync regardless of user choice (they can disable manually if needed)
      // This ensures data gets synced after they've been prompted
      final settingsBox = Hive.box('settings');
      settingsBox.put('syncEnabled', true);
      if (mounted) setState(() => _syncEnabled = true);
      await AllAppsDriveService.instance.setSyncEnabled(true);

      if (shouldFetch ?? false) {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(context, 'fetching_data')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        try {
          await _fetchFromGoogle();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t(context, 'drive_upload_success').replaceFirst('%s', widget.box.length.toString()))),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${t(context, 'fetch_failed')}: $e')),
            );
          }
        }
      }
    } catch (e) {
      // Log error but DON'T reset _lastPromptedAccountId - this was causing
      // the dialog to appear every time the user visited settings.
      if (kDebugMode) print('_maybePromptFetchAfterInteractiveSignIn: Error showing dialog: $e');
    }
  }

  void _schedulePromptForAccount(GoogleSignInAccount account) {
    if (_promptScheduled) return;
    // If we've already prompted this account, no-op.
    final lastPrompted = _lastPromptedAccountId;
    if (kDebugMode) print('_schedulePromptForAccount: account.id=${account.id}, lastPrompted=$lastPrompted');
    if (lastPrompted == account.id) {
      if (kDebugMode) print('_schedulePromptForAccount: Already prompted this account, skipping');
      // Hide loading since we're not showing a prompt
      if (mounted) setState(() { _isLoading = false; _loadingMessage = ''; });
      return;
    }

    _promptScheduled = true;
    // Use a post-frame callback to ensure dialog can be shown safely.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _promptScheduled = false;
      if (!mounted) return;
      try {
        await _maybePromptFetchAfterInteractiveSignIn(account);
      } catch (e) {
        // Swallow scheduling errors silently.
      } finally {
        // Hide loading after prompt flow completes
        if (mounted) setState(() { _isLoading = false; _loadingMessage = ''; });
      }
    });
  }

  Future<void> _handleSignOut() async {
    // Only sign out if GoogleSignIn is available (mobile platforms)
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    
    setState(() {
      _syncEnabled = false;
      Hive.box('settings').put('syncEnabled', false);
      // Clear the client and disable sync
      AllAppsDriveService.instance.clearClient();
      AllAppsDriveService.instance.setSyncEnabled(false);
      _lastPromptedAccountId = null;
    });
  }

  Future<void> _uploadToDrive() async {
    if (!_syncEnabled || !AllAppsDriveService.instance.isAuthenticated) return;

    try {
      // Use the new method that shows UI notification for user-initiated uploads
      await AllAppsDriveService.instance.uploadFromBoxWithNotification(widget.box);
    } catch (e) {
      // Upload failed silently
    }
  }

  /// Create a local backup manually
  Future<void> _createLocalBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      await LocalBackupService.instance.createBackupNow();
      
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(t(context, 'backup_created'))),
      );
      
      // Refresh the backup list
      await _loadAvailableBackups();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${t(context, 'backup_failed')}: $e')),
      );
    }
  }

  /// Delete all backup files from Drive (DEBUG ONLY)
  Future<void> _deleteAllBackups() async {
    if (!AllAppsDriveService.instance.isAuthenticated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(context, 'delete_all_backups'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'confirm_delete_all_backups')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(context, 'delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deletedCount = await AllAppsDriveService.instance.deleteAllBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $deletedCount backup files')),
        );
        _loadAvailableBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete backups: $e')),
        );
      }
    }
  }

  Future<void> _fetchFromGoogle() async {
    final isSignedIn = _currentUser != null;
    if (kDebugMode) print('_fetchFromGoogle: Starting restore... isSignedIn=$isSignedIn');
    
    // For Drive restore, must be authenticated
    if (isSignedIn && !AllAppsDriveService.instance.isAuthenticated) {
      if (kDebugMode) print('_fetchFromGoogle: Signed in but not authenticated, returning');
      return;
    }
    
    // Show warning dialog - user must confirm before data is replaced
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

    if (confirmed != true || !mounted) return;
    
    String? content;
    
    try {
      // Download from selected backup or most recent backup
      String? backupFileName = _selectedBackupFileName;
      
      if (isSignedIn) {
        // Restore from Google Drive
        // If no backup selected, find the most recent one
        if (backupFileName == null || backupFileName.isEmpty) {
          final backups = await AllAppsDriveService.instance.listAvailableBackups();
          if (backups.isEmpty) {
            if (kDebugMode) print('_fetchFromGoogle: No backups found on Drive');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(context, 'no_data_found'))),
              );
            }
            return;
          }
          // Backups are sorted newest first
          backupFileName = backups.first['fileName'] as String?;
          if (kDebugMode) print('_fetchFromGoogle: Using most recent backup: $backupFileName');
        }
        
        if (backupFileName == null || backupFileName.isEmpty) {
          if (kDebugMode) print('_fetchFromGoogle: No backup file name available');
          return;
        }
        
        content = await AllAppsDriveService.instance.downloadBackupContent(backupFileName);
      } else {
        // Restore from local backup
        // If no backup selected, find the most recent one
        if (backupFileName == null || backupFileName.isEmpty) {
          final backups = await LocalBackupService.instance.listAvailableBackups();
          if (backups.isEmpty) {
            if (kDebugMode) print('_fetchFromGoogle: No local backups found');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(context, 'no_data_found'))),
              );
            }
            return;
          }
          // Backups are sorted newest first
          backupFileName = backups.first['fileName'] as String?;
          if (kDebugMode) print('_fetchFromGoogle: Using most recent local backup: $backupFileName');
        }
        
        if (backupFileName == null || backupFileName.isEmpty) {
          if (kDebugMode) print('_fetchFromGoogle: No local backup file name available');
          return;
        }
        
        content = await LocalBackupService.instance.downloadBackupContent(backupFileName);
      }
      
      if (content == null) {
        if (kDebugMode) print('_fetchFromGoogle: Downloaded content is null');
        return;
      }
      
      // Use centralized BackupRestoreService for consistent restore behavior
      final result = await BackupRestoreService.restoreFromJsonString(
        content,
        createSafetyBackup: true, // Always create safety backup before restore
      );
      
      if (!mounted) return;
      
      if (result.success) {
        final c = result.counts;
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
          SnackBar(content: Text('${t(context, 'fetch_failed')}: ${result.error}')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('_fetchFromGoogle: Download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'fetch_failed')}: $e')),
      );
    }
  }

  Future<void> _exportJson() async {
    final messenger = ScaffoldMessenger.of(context);
    if (widget.box.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'entries_title')}: 0')));
      return;
    }

    try {
      // Use centralized SyncPayloadBuilder for consistent export format
      final exportData = SyncPayloadBuilder.buildPayload();
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      String? savedPath;
      
      // Platform-specific file save dialog
      if (PlatformHelper.isMobile) {
        // Mobile: Use flutter_file_dialog
        final params = SaveFileDialogParams(
          data: bytes,
          fileName: 'inventory_export_${DateTime.now().millisecondsSinceEpoch}.json',
        );
        savedPath = await FlutterFileDialog.saveFile(params: params);
      } else if (PlatformHelper.isDesktop || PlatformHelper.isWeb) {
        // Desktop/Web: Use file_picker
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: t(context, 'save_json_export'),
          fileName: 'inventory_export_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        
        // On desktop, file_picker returns path but doesn't write the file
        if (savedPath != null && (PlatformHelper.isDesktop || PlatformHelper.isWeb)) {
          await File(savedPath).writeAsBytes(bytes);
        }
      }

      if (savedPath != null) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('${t(context, 'json_saved')}: $savedPath')));
      } else {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'cancel'))));
      }

      // NOTE: Do NOT auto-upload after JSON export - no data changed, just exported
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'export_failed')}: $e')));
    }
  }

  Future<void> _importJson() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Warning dialog before importing
      if (!mounted) return;
      final confirmImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            t(context, 'import_json'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(t(context, 'import_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(t(context, 'import')),
            ),
          ],
        ),
      );

      if (confirmImport != true) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'cancel'))));
        return;
      }

      final path = result.files.single.path!;
      final file = File(path);
      final jsonString = await file.readAsString();

      // Use centralized BackupRestoreService for consistent restore behavior
      final restoreResult = await BackupRestoreService.restoreFromJsonString(
        jsonString,
        createSafetyBackup: true, // Always create safety backup before restore
      );

      if (!mounted) return;
      
      if (restoreResult.success) {
        final c = restoreResult.counts;
        messenger.showSnackBar(
          SnackBar(
            content: Text(t(context, 'import_success_count')
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

        if (_syncEnabled && AllAppsDriveService.instance.isAuthenticated) _uploadToDrive();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('${t(context, 'import_failed')}: ${restoreResult.error}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'import_failed')}: $e')));
    }
  }

  Future<void> _clearAllEntries() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(context, 'confirm_clear'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'clear_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t(context, 'cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(context, 'clear_all')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Create safety backup before destructive clear operation
      await BackupRestoreService.createPreRestoreSafetyBackup();
      
      // Clear all 8 boxes for all apps (LOCAL ONLY - does NOT sync to Drive)
      await widget.box.clear(); // entries (4th step inventory)
      await Hive.box<IAmDefinition>('i_am_definitions').clear();
      await Hive.box<Person>('people_box').clear();
      await Hive.box<ReflectionEntry>('reflections_box').clear();
      await Hive.box<GratitudeEntry>('gratitude_box').clear();
      await Hive.box<BarrierPowerPair>('agnosticism_pairs').clear();
      await Hive.box<RitualItem>('morning_ritual_items').clear();
      await Hive.box<MorningRitualEntry>('morning_ritual_entries').clear();
      
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t(context, 'all_cleared'))));
      // NOTE: Intentionally NOT syncing to Drive - this is a local-only clear
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSignedIn = _currentUser != null;
    final String buttonText = isSignedIn 
        ? '${t(context, 'sign_out_google')} (${_currentUser!.displayName ?? 'User'})' 
        : t(context, 'sign_in_google');
    final VoidCallback onPressed = isSignedIn ? _handleSignOut : _handleSignIn;
    
    // Platform availability check - Mobile only (Android/iOS)
    final bool driveAvailable = PlatformHelper.isMobile;

    // Show loading overlay during sign-in/Drive operations
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Sign-In button (only show on mobile)
          if (driveAvailable)
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: isSignedIn ? const Icon(Icons.logout) : const Icon(Icons.login),
              label: Text(buttonText),
            ),
          if (driveAvailable) const SizedBox(height: 16),
          
          // Sync toggle (only show on mobile)
          if (driveAvailable)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t(context, 'sync_google_drive')),
                Tooltip(
                  message: isSignedIn ? '' : t(context, 'sign_in_to_enable_sync'),
                  child: Switch(
                    value: _syncEnabled,
                    onChanged: isSignedIn ? _toggleSync : null,
                  ),
                ),
              ],
            ),
          if (driveAvailable) const SizedBox(height: 16),
          
          ElevatedButton(onPressed: _exportJson, child: Text(t(context, 'export_json'))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _importJson, child: Text(t(context, 'import_json'))),
          const SizedBox(height: 16),
          
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
                        isSignedIn ? Icons.cloud : Icons.folder,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSignedIn
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
                  if (!isSignedIn) ...[
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
                                isSignedIn ? Icons.cloud : Icons.folder,
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
                    onPressed: _fetchFromGoogle,
                    icon: const Icon(Icons.download),
                    label: Text(t(context, 'restore_from_backup')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  // Create Local Backup button (only when not signed in)
                  if (!isSignedIn) ...[
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
          
          // Manual upload button for mobile when signed in
          if (isSignedIn && driveAvailable)
            ElevatedButton.icon(
              onPressed: _uploadToDrive,
              icon: const Icon(Icons.cloud_upload),
              label: Text(t(context, 'upload_to_drive_manual')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          if (isSignedIn && driveAvailable) const SizedBox(height: 16),
          
          // Debug only: Delete all backups button
          if (kDebugMode && isSignedIn && driveAvailable) ...[
            ElevatedButton.icon(
              onPressed: _deleteAllBackups,
              icon: const Icon(Icons.delete_forever),
              label: Text(t(context, 'delete_all_backups')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _clearAllEntries,
            child: Text(t(context, 'clear_all')),
          ),
        ],
      ),
    );
  }
}
