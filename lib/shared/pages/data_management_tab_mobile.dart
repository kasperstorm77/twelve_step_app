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
import '../../agnosticism/models/agnosticism_paper.dart';
import '../localizations.dart';
import '../utils/platform_helper.dart';

// Platform-specific imports
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
    
// Services
import '../services/google_sign_in_wrapper.dart';
import '../services/google_drive_client.dart';
import '../services/legacy_drive_service.dart';

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
  GoogleDriveClient? _driveClient;

  bool _syncEnabled = false;
  bool _interactiveSignIn = false;
  bool _interactiveSignInRequested = false;
  bool _signingInProgress = false;
  String? _lastPromptedAccountId;
  bool _promptScheduled = false;

  // Backup selection state
  List<Map<String, dynamic>> _availableBackups = [];
  String? _selectedBackupFileName;
  bool _loadingBackups = false;

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
        // Don't update state during an active sign-in to avoid
        // interrupting the sign-in dialog/WebView
        if (!mounted || _signingInProgress) return;
        
        setState(() {
          _currentUser = account;
          if (_currentUser == null) {
            _syncEnabled = false;
            Hive.box('settings').put('syncEnabled', false);
            _driveClient = null;
            // Clear backups when signed out
            _availableBackups = [];
            _selectedBackupFileName = null;
          }
        });
        if (account != null) {
          _initializeDriveClient(account);
          // Load backups when signed in
          _loadAvailableBackups();
          // Only schedule the prompt for automatic/silent sign-ins.
          // Interactive sign-ins handle the prompt themselves in _handleSignIn.
          if (!_interactiveSignIn && !_interactiveSignInRequested) {
            _schedulePromptForAccount(account);
          }
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
    
    // Load available backups if signed in
    _loadAvailableBackups();
  }

  /// Load available backup restore points from Drive
  Future<void> _loadAvailableBackups() async {
    if (kDebugMode) print('_loadAvailableBackups: called - isMobile=${PlatformHelper.isMobile}, currentUser=${_currentUser?.displayName}');
    
    if (!PlatformHelper.isMobile || _currentUser == null) {
      if (kDebugMode) print('_loadAvailableBackups: skipped - not mobile or no user');
      return;
    }
    
    setState(() {
      _loadingBackups = true;
    });

    try {
      final backups = await DriveService.instance.listAvailableBackups();
      
      if (mounted) {
        setState(() {
          _availableBackups = backups;
          _loadingBackups = false;
          // Select the most recent backup by default
          if (_availableBackups.isNotEmpty && _selectedBackupFileName == null) {
            _selectedBackupFileName = _availableBackups.first['fileName'] as String?;
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
      _syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    });
  }

  Future<void> _toggleSync(bool value) async {
    if (_currentUser == null) return;
    final settingsBox = Hive.box('settings');
    settingsBox.put('syncEnabled', value);
    setState(() => _syncEnabled = value);
    // Update the shared DriveService flag so other parts of the app (like
    // InventoryHome) will respect the new state immediately. Await to
    // avoid races between toggling and immediate uploads.
    await DriveService.instance.setSyncEnabled(value);
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

  _driveClient = await GoogleDriveClient.create(account, accessToken);
      // Wire the created client into the shared DriveService so other parts
      // of the app (e.g. InventoryHome._syncDrive) will use the same client.
      DriveService.instance.setClient(_driveClient!);

      // Ensure DriveService has the current sync state (in case toggle
      // happened while client wasn't set).
      await DriveService.instance.setSyncEnabled(_syncEnabled);

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
      // Mark that an interactive sign-in was requested. We keep both the
      // 'requested' and 'interactive' flags to be resilient to timing where
      // `onCurrentUserChanged` may fire before/after this method resumes.
      _interactiveSignInRequested = true;
      _interactiveSignIn = true;
      _signingInProgress = true; // Prevent state updates during sign-in
      
      final account = await _googleSignIn!.signIn();
      
      _signingInProgress = false; // Sign-in complete, allow state updates
      
      if (account != null) {
        // Manually update the current user since we blocked the listener
        setState(() {
          _currentUser = account;
          // Auto-enable sync on successful sign-in
          _syncEnabled = true;
        });
        Hive.box('settings').put('syncEnabled', true);
        
        await _initializeDriveClient(account);
        // Schedule the prompt; this is resilient to the ordering of
        // onCurrentUserChanged vs this handler resuming.
        _schedulePromptForAccount(account);
        
        // Load available backups after sign-in
        _loadAvailableBackups();
      }
      // Do NOT clear the interactive/requested flags here — they are
      // cleared by `_maybePromptFetchAfterInteractiveSignIn` after the
      // prompt completes. If account is null (user cancelled), clear them
      // now so future sign-ins work normally.
      if (account == null) {
        _interactiveSignIn = false;
        _interactiveSignInRequested = false;
      }
    } catch (e) {
      _signingInProgress = false; // Clear flag on error
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'sign_in_failed')}: ${e.toString().split(',').first}')));
      _interactiveSignIn = false;
      _interactiveSignInRequested = false;
    }
  }

  Future<void> _maybePromptFetchAfterInteractiveSignIn(GoogleSignInAccount account) async {
  // Only prompt when this sign-in was interactive/requested and we haven't
  // already prompted for this account id.
  if (!(_interactiveSignIn || _interactiveSignInRequested)) return;
  if (_lastPromptedAccountId == account.id) return;

    // Attempt to show the dialog. Only mark this account as 'prompted' after
    // the dialog successfully completes so that failures (for example if the
    // dialog couldn't be shown) don't prevent future prompts.
    try {
      final shouldFetch = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(t(context, 'googlefetch')),
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
          final settingsBox = Hive.box('settings');
          settingsBox.put('syncEnabled', true);
          if (mounted) setState(() => _syncEnabled = true);
          await DriveService.instance.setSyncEnabled(true);
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

      // Clear the interactive/requested flags now we've completed the flow.
      _interactiveSignIn = false;
      _interactiveSignInRequested = false;
    } catch (e) {
      // Don't let dialog/display errors prevent future prompts. Continue.
      _lastPromptedAccountId = null;
      _interactiveSignIn = false;
      _interactiveSignInRequested = false;
    }
  }

  void _schedulePromptForAccount(GoogleSignInAccount account) {
    if (_promptScheduled) return;
    // If we've already prompted this account, no-op.
    if (_lastPromptedAccountId == account.id) return;

    _promptScheduled = true;
    // Use a post-frame callback to ensure dialog can be shown safely.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _promptScheduled = false;
      if (!mounted) return;
      try {
        await _maybePromptFetchAfterInteractiveSignIn(account);
      } catch (e) {
        // Swallow scheduling errors silently.
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
      _driveClient = null;
      // Clear the shared client so DriveService stops attempting to use it.
      DriveService.instance.clearClient();
      DriveService.instance.setSyncEnabled(false);
      // Reset interactive sign-in tracking so a subsequent sign-in will
      // re-prompt the user even if it's the same account in this session.
      _interactiveSignIn = false;
      _interactiveSignInRequested = false;
      _lastPromptedAccountId = null;
    });
  }

  Future<void> _uploadToDrive() async {
    if (_driveClient == null || !_syncEnabled) return;

    try {
      // Use the new method that shows UI notification for user-initiated uploads
      await DriveService.instance.uploadFromBoxWithNotification(widget.box);
    } catch (e) {
      // Upload failed silently
    }
  }

  Future<void> _fetchFromGoogle() async {
    if (kDebugMode) print('_fetchFromGoogle: Starting restore...');
    if (_driveClient == null) {
      if (kDebugMode) print('_fetchFromGoogle: Drive client is null, returning');
      return;
    }
    
    String? content;
    
    try {
      // Download from selected backup or current file
      if (_selectedBackupFileName != null && _selectedBackupFileName!.isNotEmpty) {
        content = await DriveService.instance.downloadBackupContent(_selectedBackupFileName!);
      } else {
        content = await _driveClient!.downloadFile();
      }
      
      if (content == null) {
        return;
      }
      
      final entriesBox = Hive.box<InventoryEntry>('entries');
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final peopleBox = Hive.box<Person>('people_box');
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');

      try {
        final decoded = json.decode(content) as Map<String, dynamic>;

        // Import I Am definitions first
        if (decoded.containsKey('iAmDefinitions')) {
          final iAmDefs = decoded['iAmDefinitions'] as List<dynamic>?;
          if (kDebugMode) print('Drive restore: Found ${iAmDefs?.length ?? 0} I Am definitions');
          if (iAmDefs != null) {
            // Clear existing I Am definitions
            await iAmBox.clear();
            
            // Add imported I Am definitions
            for (final defJson in iAmDefs) {
              final def = IAmDefinition(
                id: defJson['id'] as String,
                name: defJson['name'] as String,
                reasonToExist: defJson['reasonToExist'] as String?,
              );
              await iAmBox.add(def);
              if (kDebugMode) print('Drive restore: Added I Am: ${def.name} (${def.id})');
            }
            if (kDebugMode) print('Drive restore: I Am box now has ${iAmBox.length} definitions');
          }
        }

        // Import entries
        final entries = decoded['entries'] as List<dynamic>?;
        if (entries == null) {
          return;
        }

        if (kDebugMode) print('Drive restore: Found ${entries.length} entries');
        await entriesBox.clear();
        for (final item in entries) {
          if (item is Map<String, dynamic>) {
            final entry = InventoryEntry.fromJson(item);
            await entriesBox.add(entry);
            if (kDebugMode && entry.iAmId != null) {
              print('Drive restore: Added entry with iAmId: ${entry.iAmId}');
            }
          }
        }
        if (kDebugMode) print('Drive restore: Entries box now has ${entriesBox.length} entries');

        // Import people (8th step) if present
        if (decoded.containsKey('people')) {
          final peopleList = decoded['people'] as List;
          await peopleBox.clear();
          for (final personJson in peopleList) {
            final person = Person.fromJson(personJson as Map<String, dynamic>);
            await peopleBox.put(person.internalId, person);
          }
        }

        // Import reflections (evening ritual) if present
        if (decoded.containsKey('reflections')) {
          final reflectionsList = decoded['reflections'] as List;
          await reflectionsBox.clear();
          for (final reflectionJson in reflectionsList) {
            final reflection = ReflectionEntry.fromJson(reflectionJson as Map<String, dynamic>);
            await reflectionsBox.put(reflection.internalId, reflection);
          }
        }

        // Import gratitude entries if present (v6.0+)
        if (decoded.containsKey('gratitude') || decoded.containsKey('gratitudeEntries')) {
          final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
          final gratitudeList = (decoded['gratitude'] ?? decoded['gratitudeEntries']) as List;
          await gratitudeBox.clear();
          for (final gratitudeJson in gratitudeList) {
            final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
            await gratitudeBox.add(gratitude);
          }
        }

        // Import agnosticism papers if present (v6.0+)
        if (decoded.containsKey('agnosticism') || decoded.containsKey('agnosticismPapers')) {
          final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');
          final papersList = (decoded['agnosticism'] ?? decoded['agnosticismPapers']) as List;
          await agnosticismBox.clear();
          for (final paperJson in papersList) {
            final paper = AgnosticismPaper.fromJson(paperJson as Map<String, dynamic>);
            await agnosticismBox.put(paper.id, paper);
          }
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'fetch_success_count')
                .replaceFirst('%entries%', entries.length.toString())
                .replaceFirst('%iams%', (decoded.containsKey('iAmDefinitions') ? (decoded['iAmDefinitions'] as List).length : 0).toString())),
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        if (kDebugMode) print('_fetchFromGoogle: Parse error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'fetch_failed')}: $e')),
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
      // Export entries, I Am definitions, people, and reflections
      final entries = widget.box.values.map((e) => e.toJson()).toList();
      
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefinitions = iAmBox.values.map((def) {
        final map = <String, dynamic>{
          'id': def.id,
          'name': def.name,
        };
        // Only include reasonToExist if it's not null/empty
        if (def.reasonToExist != null && def.reasonToExist!.isNotEmpty) {
          map['reasonToExist'] = def.reasonToExist;
        }
        return map;
      }).toList();

      final peopleBox = Hive.box<Person>('people_box');
      final people = peopleBox.values.map((p) => p.toJson()).toList();

      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
      final reflections = reflectionsBox.values.map((r) => r.toJson()).toList();

      final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
      final gratitudeEntries = gratitudeBox.values.map((g) => g.toJson()).toList();

      final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');
      final agnosticismPapers = agnosticismBox.values.map((p) => p.toJson()).toList();

      final now = DateTime.now().toUtc();
      final exportData = {
        'version': '6.0', // Updated version to include gratitude and agnosticism
        'exportDate': now.toIso8601String(),
        'lastModified': now.toIso8601String(), // For sync conflict detection
        'iAmDefinitions': iAmDefinitions,
        'entries': entries,
        'people': people, // 8th step people
        'reflections': reflections, // Evening reflections
        'gratitude': gratitudeEntries, // Gratitude entries
        'agnosticism': agnosticismPapers, // Agnosticism papers
      };

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
        messenger.showSnackBar(SnackBar(content: Text('${t(context, 'json_saved')}: $savedPath')));
      } else {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'cancel'))));
      }

      // NOTE: Do NOT auto-upload after JSON export - no data changed, just exported
    } catch (e) {
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
          title: Text(t(context, 'import_json')),
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
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final entriesBox = Hive.box<InventoryEntry>('entries');
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final peopleBox = Hive.box<Person>('people_box');
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');

      // Import I Am definitions first
      if (data.containsKey('iAmDefinitions')) {
        final iAmDefs = data['iAmDefinitions'] as List;
        if (kDebugMode) print('Import: Found ${iAmDefs.length} I Am definitions');
        // Clear existing I Am definitions
        await iAmBox.clear();
        
        // Add imported I Am definitions
        for (final defJson in iAmDefs) {
          final def = IAmDefinition(
            id: defJson['id'] as String,
            name: defJson['name'] as String,
            reasonToExist: defJson['reasonToExist'] as String?,
          );
          await iAmBox.add(def);
          if (kDebugMode) print('Import: Added I Am: ${def.name} (${def.id})');
        }
        if (kDebugMode) print('Import: I Am box now has ${iAmBox.length} definitions');
      }

      // Import entries
      final entries = data['entries'] as List;
      if (kDebugMode) print('Import: Found ${entries.length} entries');
      await entriesBox.clear();
      for (final entryJson in entries) {
        final entry = InventoryEntry.fromJson(entryJson as Map<String, dynamic>);
        await entriesBox.add(entry);
        if (kDebugMode && entry.iAmId != null) {
          print('Import: Added entry with iAmId: ${entry.iAmId}');
        }
      }
      if (kDebugMode) print('Import: Entries box now has ${entriesBox.length} entries');

      // Import people (8th step) if present - maintains backward compatibility
      if (data.containsKey('people')) {
        final peopleList = data['people'] as List;
        await peopleBox.clear();
        for (final personJson in peopleList) {
          final person = Person.fromJson(personJson as Map<String, dynamic>);
          await peopleBox.put(person.internalId, person);
        }
      }

      // Import reflections (evening ritual) if present - maintains backward compatibility
      if (data.containsKey('reflections')) {
        final reflectionsList = data['reflections'] as List;
        await reflectionsBox.clear();
        for (final reflectionJson in reflectionsList) {
          final reflection = ReflectionEntry.fromJson(reflectionJson as Map<String, dynamic>);
          await reflectionsBox.put(reflection.internalId, reflection);
        }
      }

      // Import gratitude entries if present (v6.0+)
      if (data.containsKey('gratitude') || data.containsKey('gratitudeEntries')) {
        final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
        final gratitudeList = (data['gratitude'] ?? data['gratitudeEntries']) as List;
        await gratitudeBox.clear();
        for (final gratitudeJson in gratitudeList) {
          final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
          await gratitudeBox.add(gratitude);
        }
      }

      // Import agnosticism papers if present (v6.0+)
      if (data.containsKey('agnosticism') || data.containsKey('agnosticismPapers')) {
        final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');
        final papersList = (data['agnosticism'] ?? data['agnosticismPapers']) as List;
        await agnosticismBox.clear();
        for (final paperJson in papersList) {
          final paper = AgnosticismPaper.fromJson(paperJson as Map<String, dynamic>);
          await agnosticismBox.put(paper.id, paper);
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(t(context, 'import_success_count')
              .replaceFirst('%entries%', entries.length.toString())
              .replaceFirst('%iams%', (data.containsKey('iAmDefinitions') ? (data['iAmDefinitions'] as List).length : 0).toString())
              .replaceFirst('%people%', (data.containsKey('people') ? (data['people'] as List).length : 0).toString())
              .replaceFirst('%reflections%', (data.containsKey('reflections') ? (data['reflections'] as List).length : 0).toString())),
          duration: const Duration(seconds: 4),
        ),
      );

      if (_syncEnabled && _driveClient != null) _uploadToDrive();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'import_failed')}: $e')));
    }
  }

  Future<void> _clearAllEntries() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'confirm_clear')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t(context, 'cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context, 'clear_all'))),
        ],
      ),
    );

    if (confirm == true) {
      await widget.box.clear();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t(context, 'clear_all'))));
      if (_syncEnabled && _driveClient != null) _uploadToDrive();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                  message: isSignedIn ? '' : 'Sign in with Google to enable sync',
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
          
          // Backup selection dropdown and fetch button (only show when signed in on mobile)
          if (isSignedIn && driveAvailable) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restore, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          t(context, 'select_restore_point'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
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
                            tooltip: 'Refresh backups',
                          ),
                      ],
                    ),
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
                        initialValue: _selectedBackupFileName,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          labelText: t(context, 'restore_point_latest'),
                        ),
                        items: [
                          // Add "Latest" option (uses current file, not dated backup)
                          DropdownMenuItem<String>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.cloud, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(t(context, 'restore_point_latest')),
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
                                  Text(displayDate),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
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
