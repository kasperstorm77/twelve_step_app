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
// - Backup restore points
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
import '../../agnosticism/models/agnosticism_paper.dart';
import '../localizations.dart';
import '../services/all_apps_drive_service_impl.dart';

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
  
  // Backup selection state (for future backup restore UI)
  List<Map<String, dynamic>> _availableBackups = [];
  String? _selectedBackupFileName;
  // ignore: unused_field - reserved for future backup restore UI like mobile
  bool _loadingBackups = false;

  @override
  void initState() {
    super.initState();
    _initWindowsAuth();
    _initSettings();
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

  /// Load available backup restore points from Drive
  Future<void> _loadAvailableBackups() async {
    if (!_isSignedIn) return;
    
    setState(() {
      _loadingBackups = true;
    });

    try {
      final backups = await AllAppsDriveService.instance.listAvailableBackups();
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
          
          // Load available backups after sign-in
          _loadAvailableBackups();
          
          // Ask if user wants to enable sync
          _showSyncEnableDialog();
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

  void _showSyncEnableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'enable_sync')),
        content: Text(t(context, 'enable_sync_prompt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'not_now')),
          ),
          ElevatedButton(
            onPressed: () {
              _toggleSync(true);
              Navigator.pop(context);
            },
            child: Text(t(context, 'enable')),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSync(bool? value) async {
    if (value == null) return;
    
    setState(() {
      _syncEnabled = value;
    });
    
    await Hive.box('settings').put('syncEnabled', value);
    
    if (value && _isSignedIn) {
      // Trigger initial sync
      await _performSync();
    }
  }

  Future<void> _performSync() async {
    if (!_isSignedIn) return;
    
    try {
      // Use AllAppsDriveService for syncing all apps
      final allAppsService = AllAppsDriveService.instance;
      final entriesBox = Hive.box<InventoryEntry>('entries');
      
      // This will upload current data to Drive
      await allAppsService.uploadFromBoxWithNotification(entriesBox);
      
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

  Map<String, dynamic> _prepareExportData() {
    final entriesBox = Hive.box<InventoryEntry>('entries');
    final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    final peopleBox = Hive.box<Person>('people_box');
    final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
    final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
    final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');

    final now = DateTime.now().toUtc();
    
    // Field order matches Mobile and Drive upload for consistency
    return {
      'version': '6.0',
      'exportDate': now.toIso8601String(),
      'lastModified': now.toIso8601String(),
      'iAmDefinitions': iAmBox.values.map((def) {
        final map = <String, dynamic>{
          'id': def.id,
          'name': def.name,
        };
        // Only include reasonToExist if it's not null/empty
        if (def.reasonToExist != null && def.reasonToExist!.isNotEmpty) {
          map['reasonToExist'] = def.reasonToExist;
        }
        return map;
      }).toList(),
      'entries': entriesBox.values.map((e) => e.toJson()).toList(),
      'people': peopleBox.values.map((p) => p.toJson()).toList(),
      'reflections': reflectionsBox.values.map((r) => r.toJson()).toList(),
      'gratitude': gratitudeBox.values.map((g) => g.toJson()).toList(),
      'agnosticism': agnosticismBox.values.map((a) => a.toJson()).toList(),
    };
  }

  Future<void> _importJson() async {
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      final path = result.files.single.path!;
      final file = File(path);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      await _importData(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'import_success'))),
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

  Future<void> _importData(Map<String, dynamic> data) async {
    final entriesBox = Hive.box<InventoryEntry>('entries');
    final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    final peopleBox = Hive.box<Person>('people_box');
    final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
    final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
    final agnosticismBox = Hive.box<AgnosticismPaper>('agnosticism_papers');

    // Import I Am definitions first (matches format from export)
    if (data.containsKey('iAmDefinitions')) {
      final iAmDefs = data['iAmDefinitions'] as List;
      if (kDebugMode) print('Windows import: Found ${iAmDefs.length} I Am definitions');
      await iAmBox.clear();
      for (final def in iAmDefs) {
        final id = def['id'] as String;
        final name = def['name'] as String;
        final reasonToExist = def['reasonToExist'] as String?;
        await iAmBox.add(IAmDefinition(id: id, name: name, reasonToExist: reasonToExist));
        if (kDebugMode) print('Windows import: Added I Am: $name ($id)');
      }
      if (kDebugMode) print('Windows import: I Am box now has ${iAmBox.length} definitions');
    }

    // Import all other data
    if (data.containsKey('entries')) {
      final entries = data['entries'] as List;
      if (kDebugMode) print('Windows import: Found ${entries.length} entries');
      await entriesBox.clear();
      for (final entryJson in entries) {
        final entry = InventoryEntry.fromJson(entryJson as Map<String, dynamic>);
        await entriesBox.add(entry);
        if (kDebugMode && entry.iAmId != null) {
          print('Windows import: Added entry with iAmId: ${entry.iAmId}');
        }
      }
      if (kDebugMode) print('Windows import: Entries box now has ${entriesBox.length} entries');
    }

    if (data.containsKey('people')) {
      await peopleBox.clear();
      for (final personJson in data['people'] as List) {
        final person = Person.fromJson(personJson as Map<String, dynamic>);
        await peopleBox.put(person.internalId, person);
      }
    }

    if (data.containsKey('reflections')) {
      await reflectionsBox.clear();
      for (final reflectionJson in data['reflections'] as List) {
        final reflection = ReflectionEntry.fromJson(reflectionJson as Map<String, dynamic>);
        await reflectionsBox.put(reflection.internalId, reflection);
      }
    }

    // Support both 'gratitude' (v6.0) and 'gratitudeEntries' (older) keys
    final gratitudeKey = data.containsKey('gratitude') ? 'gratitude' : 'gratitudeEntries';
    if (data.containsKey(gratitudeKey)) {
      await gratitudeBox.clear();
      for (final gratitudeJson in data[gratitudeKey] as List) {
        final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
        await gratitudeBox.add(gratitude);
      }
    }

    // Support both 'agnosticism' (v6.0) and 'agnosticismPapers' (older) keys
    final agnosticismKey = data.containsKey('agnosticism') ? 'agnosticism' : 'agnosticismPapers';
    if (data.containsKey(agnosticismKey)) {
      await agnosticismBox.clear();
      for (final paperJson in data[agnosticismKey] as List) {
        final paper = AgnosticismPaper.fromJson(paperJson as Map<String, dynamic>);
        await agnosticismBox.put(paper.id, paper);
      }
    }
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
      padding: const EdgeInsets.all(16),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Tooltip(
              message: _isSignedIn ? '' : 'Sign in with Google to enable sync',
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
          style: Theme.of(context).textTheme.titleMedium,
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
        
        // Clear all data button
        const Divider(),
        const SizedBox(height: 16),
        
        ElevatedButton(
          onPressed: () => _confirmClearAll(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(t(context, 'clear_all')),
        ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'confirm_clear')),
        content: Text(t(context, 'clear_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(context, 'clear')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'all_cleared'))),
      );
    }
  }

  Future<void> _clearAllData() async {
    await Hive.box<InventoryEntry>('entries').clear();
    await Hive.box<IAmDefinition>('i_am_definitions').clear();
    await Hive.box<Person>('people_box').clear();
    await Hive.box<ReflectionEntry>('reflections_box').clear();
    await Hive.box<GratitudeEntry>('gratitude_box').clear();
    await Hive.box<AgnosticismPaper>('agnosticism_box').clear();
  }
}
