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
import '../../agnosticism/models/barrier_power_pair.dart';
import '../../morning_ritual/models/ritual_item.dart';
import '../../morning_ritual/models/morning_ritual_entry.dart';
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
  
  // Backup selection state
  List<Map<String, dynamic>> _availableBackups = [];
  String? _selectedBackupFileName;
  bool _loadingBackups = false;

  @override
  void initState() {
    super.initState();
    _initWindowsAuth();
    _initSettings();
    // Note: _loadAvailableBackups is called from _initWindowsAuth after auth is confirmed
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
        
        // Load backups after auth is confirmed
        if (signedIn) {
          _loadAvailableBackups();
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

  /// Restore data from selected backup
  Future<void> _restoreFromBackup() async {
    if (!_isSignedIn) return;

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
      
      if (_selectedBackupFileName == null) {
        // Download latest (most recent backup)
        content = await AllAppsDriveService.instance.downloadBackupContent(
          _availableBackups.isNotEmpty 
            ? _availableBackups.first['fileName'] as String
            : '',
        );
      } else {
        // Download selected backup
        content = await AllAppsDriveService.instance.downloadBackupContent(_selectedBackupFileName!);
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
      await _importData(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'import_success'))),
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

  Map<String, dynamic> _prepareExportData() {
    final entriesBox = Hive.box<InventoryEntry>('entries');
    final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    final peopleBox = Hive.box<Person>('people_box');
    final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
    final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
    final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
    final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
    final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');

    final now = DateTime.now().toUtc();
    
    // Field order matches Mobile and Drive upload for consistency
    return {
      'version': '7.0',
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
      'morningRitualItems': morningRitualItemsBox.values.map((i) => i.toJson()).toList(),
      'morningRitualEntries': morningRitualEntriesBox.values.map((e) => e.toJson()).toList(),
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
    final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
    final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
    final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');

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
          debugPrint('Windows import: Added entry with iAmId: ${entry.iAmId}');
        }
      }
      if (kDebugMode) debugPrint('Windows import: Entries box now has ${entriesBox.length} entries');
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

    // Support both 'gratitude' (v6.0+) and 'gratitudeEntries' (older) keys
    final gratitudeKey = data.containsKey('gratitude') ? 'gratitude' : 'gratitudeEntries';
    if (data.containsKey(gratitudeKey)) {
      await gratitudeBox.clear();
      for (final gratitudeJson in data[gratitudeKey] as List) {
        final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
        await gratitudeBox.add(gratitude);
      }
    }

    // Support both 'agnosticism' (v6.0+) and 'agnosticismPapers' (older) keys
    final agnosticismKey = data.containsKey('agnosticism') ? 'agnosticism' : 'agnosticismPapers';
    if (data.containsKey(agnosticismKey)) {
      await agnosticismBox.clear();
      for (final pairJson in data[agnosticismKey] as List) {
        final pair = BarrierPowerPair.fromJson(pairJson as Map<String, dynamic>);
        await agnosticismBox.put(pair.id, pair);
      }
    }

    // Import morning ritual items (v7.0+)
    if (data.containsKey('morningRitualItems')) {
      await morningRitualItemsBox.clear();
      for (final itemJson in data['morningRitualItems'] as List) {
        final item = RitualItem.fromJson(itemJson as Map<String, dynamic>);
        await morningRitualItemsBox.put(item.id, item);
      }
      if (kDebugMode) print('Windows import: Imported ${morningRitualItemsBox.length} morning ritual items');
    }

    // Import morning ritual entries (v7.0+)
    if (data.containsKey('morningRitualEntries')) {
      await morningRitualEntriesBox.clear();
      for (final entryJson in data['morningRitualEntries'] as List) {
        final entry = MorningRitualEntry.fromJson(entryJson as Map<String, dynamic>);
        await morningRitualEntriesBox.put(entry.id, entry);
      }
      if (kDebugMode) print('Windows import: Imported ${morningRitualEntriesBox.length} morning ritual entries');
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
              style: Theme.of(context).textTheme.titleMedium,
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
        
        // Backup selection dropdown and restore button (only show when signed in)
        if (_isSignedIn) ...[
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
                          tooltip: t(context, 'refresh_backups'),
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
                    onPressed: _restoreFromBackup,
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
        title: Text(t(context, 'confirm_clear')),
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
