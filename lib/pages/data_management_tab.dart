import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:csv/csv.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/inventory_entry.dart';
import '../localizations.dart';
import '../google_drive_client.dart';
import '../services/drive_service.dart';
import 'package:flutter/foundation.dart';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  GoogleSignInAccount? _currentUser;
  GoogleDriveClient? _driveClient;

  bool _syncEnabled = false;
  bool _interactiveSignIn = false;
  bool _interactiveSignInRequested = false;
  String? _lastPromptedAccountId;
  bool _promptScheduled = false;

  @override
  void initState() {
    super.initState();
    _initSettings();

    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
        if (_currentUser == null) {
          _syncEnabled = false;
          Hive.box('settings').put('syncEnabled', false);
          _driveClient = null;
        }
      });
      if (account != null) {
        _initializeDriveClient(account);
        // Schedule the prompt rather than showing immediately. Scheduling
        // ensures the widget tree is ready to present a dialog and avoids
        // timing issues where onCurrentUserChanged fires before the UI is
        // prepared to show a modal.
        _schedulePromptForAccount(account);
      }
    });

    _googleSignIn.signInSilently().catchError((e) {
      print('Silent sign-in failed: $e');
      return null;
    });
  }

  Future<void> _initSettings() async {
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    final settingsBox = Hive.box('settings');
    setState(() {
      _syncEnabled = settingsBox.get('syncEnabled', defaultValue: false);
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
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
            const SnackBar(content: Text('Google sign-in succeeded but no access token was returned.')));
        print('No access token returned from GoogleSignInAccount.authentication');
        return;
      }

  _driveClient = await GoogleDriveClient.create(account, accessToken);
      // Wire the created client into the shared DriveService so other parts
      // of the app (e.g. InventoryHome._syncDrive) will use the same client.
      DriveService.instance.setClient(_driveClient!);

      // Ensure DriveService has the current sync state (in case toggle
      // happened while client wasn't set).
      await DriveService.instance.setSyncEnabled(_syncEnabled);

      if (_syncEnabled) await _uploadToDrive();
    } catch (e) {
      print('Drive initialization failed: $e');
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('Drive initialization failed: $e')));
    }
  }

  Future<void> _handleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Mark that an interactive sign-in was requested. We keep both the
      // 'requested' and 'interactive' flags to be resilient to timing where
      // `onCurrentUserChanged` may fire before/after this method resumes.
      _interactiveSignInRequested = true;
      _interactiveSignIn = true;
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _initializeDriveClient(account);
        // Schedule the prompt; this is resilient to the ordering of
        // onCurrentUserChanged vs this handler resuming.
        _schedulePromptForAccount(account);
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
      messenger.showSnackBar(SnackBar(content: Text('Sign In failed: ${e.toString().split(',').first}')));
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
        builder: (_) => AlertDialog(
          title: Text(t(context, 'googlefetch')),
          content: Text(t(context, 'confirm_google_fetch')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t(context, 'cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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
        await _fetchFromGoogle();
        final settingsBox = Hive.box('settings');
        settingsBox.put('syncEnabled', true);
        if (mounted) setState(() => _syncEnabled = true);
        await DriveService.instance.setSyncEnabled(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, 'drive_upload_success').replaceFirst('%s', widget.box.length.toString()))));
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
      } catch (_) {
        // Swallow scheduling errors silently.
      }
    });
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
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
    if (_driveClient == null) return;
    try {
      final content = await _driveClient!.downloadFile();
      if (content == null) return;

      final entriesBox = Hive.box<InventoryEntry>('entries');

      // Try JSON first (new format)
      try {
        final decoded = json.decode(content) as Map<String, dynamic>;
        final entries = decoded['entries'] as List<dynamic>?;
        if (entries == null) return;

        await entriesBox.clear();
        for (final item in entries) {
          if (item is Map<String, dynamic>) {
            final entry = InventoryEntry(
              item['resentment']?.toString() ?? '',
              item['reason']?.toString() ?? '',
              item['affect']?.toString() ?? '',
              item['part']?.toString() ?? '',
              item['defect']?.toString() ?? '',
            );
            entriesBox.add(entry);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetched ${entries.length} entries from Google (JSON)')),
        );
        return;
      } catch (_) {
        // Not JSON — fall through to CSV fallback
      }

      // CSV fallback for older uploads
      try {
        final rows = const CsvToListConverter().convert(content, eol: '\n');
        if (rows.length <= 1) return;

        await entriesBox.clear();
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 5) continue;
          final entry = InventoryEntry(
            row[0].toString(),
            row[1].toString(),
            row[2].toString(),
            row[3].toString(),
            row[4].toString(),
          );
          entriesBox.add(entry);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetched ${rows.length - 1} entries from Google (CSV fallback)')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetch failed (unrecognized format): $e')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetch failed: $e')),
      );
    }
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    if (widget.box.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'entries_title')}: 0')));
      return;
    }

    final rows = [
      [t(context, 'resentment'), t(context, 'reason'), t(context, 'affect'), t(context, 'part'), t(context, 'defect')],
      ...widget.box.values.map((e) => [e.resentment, e.reason, e.affect, e.part, e.defect])
    ];

    final csvString = const ListToCsvConverter(eol: '\r\n').convert(rows);
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)]);

    try {
      final params = SaveFileDialogParams(data: bytes, fileName: 'inventory_export.csv');
      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath != null) {
        messenger.showSnackBar(SnackBar(content: Text('CSV saved to: $savedPath')));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'cancel'))));
      }

      if (_syncEnabled && _driveClient != null) _uploadToDrive();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (result == null || result.files.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'cancel'))));
        return;
      }

      final path = result.files.single.path!;
      final file = File(path);
      final csvString = await file.readAsString();

      final rows = const CsvToListConverter().convert(csvString, eol: '\n');
      if (rows.length <= 1) {
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'cancel'))));
        return;
      }

      final entriesBox = Hive.box<InventoryEntry>('entries');
      await entriesBox.clear();
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 5) continue;
        final entry = InventoryEntry(
          row[0].toString(),
          row[1].toString(),
          row[2].toString(),
          row[3].toString(),
          row[4].toString(),
        );
        entriesBox.add(entry);
      }

      messenger.showSnackBar(SnackBar(content: Text('Imported ${rows.length - 1} entries.')));

      if (_syncEnabled && _driveClient != null) _uploadToDrive();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _clearAllEntries() async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text(t(context, 'clear_all'))));
      if (_syncEnabled && _driveClient != null) _uploadToDrive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSignedIn = _currentUser != null;
    final String buttonText = isSignedIn ? 'Sign Out Google (${_currentUser!.displayName ?? 'User'})' : 'Sign In with Google';
    final VoidCallback onPressed = isSignedIn ? _handleSignOut : _handleSignIn;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: isSignedIn ? const Icon(Icons.logout) : const Icon(Icons.login),
            label: Text(buttonText),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _exportCsv, child: Text(t(context, 'export_csv'))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _importCsv, child: Text(t(context, 'import_csv'))),
          const SizedBox(height: 16),
          if (isSignedIn)
            ElevatedButton(
              onPressed: _fetchFromGoogle,
              child: Text(t(context, 'googlefetch')),
            ),
          const SizedBox(height: 16),
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
