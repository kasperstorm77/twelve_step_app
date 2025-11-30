import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../localizations.dart';
import 'legacy_drive_service.dart';
import '../../fourth_step/models/inventory_entry.dart';

class AppVersionService {
  static const String _versionKey = 'app_version';
  static const String _installDateKey = 'install_date';
  
  static Future<bool> isNewInstallOrUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    
    final settingsBox = Hive.box('settings');
    final storedVersion = settingsBox.get(_versionKey);
    
    if (kDebugMode) {
      print('AppVersionService: Current version: $currentVersion, Stored version: $storedVersion');
    }
    
    if (storedVersion == null) {
      // First time opening the app - new installation
      await _recordCurrentVersion(currentVersion);
      if (kDebugMode) {
        print('AppVersionService: Detected new installation');
      }
      return true;
    }
    
    if (storedVersion != currentVersion) {
      // Version changed - app was updated
      await _recordCurrentVersion(currentVersion);
      if (kDebugMode) {
        print('AppVersionService: Detected app update from $storedVersion to $currentVersion');
      }
      return true;
    }
    
    return false;
  }
  
  static Future<void> _recordCurrentVersion(String version) async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put(_versionKey, version);
    
    // Also record install/update date if not exists
    if (!settingsBox.containsKey(_installDateKey)) {
      await settingsBox.put(_installDateKey, DateTime.now().toIso8601String());
    }
  }
  
  static Future<bool> shouldPromptGoogleFetch() async {
    // Check if it's a new install/update
    final isNewInstallOrUpdate = await AppVersionService.isNewInstallOrUpdate();
    if (!isNewInstallOrUpdate) {
      if (kDebugMode) {
        print('AppVersionService: Not a new install/update, skipping Google fetch prompt');
      }
      return false;
    }
    
    // Check if user is signed in to Google
    final driveService = DriveService.instance;
    if (driveService.client == null) {
      if (kDebugMode) {
        print('AppVersionService: No Google Drive client available, skipping fetch prompt');
      }
      return false; // Not signed in, can't fetch
    }
    
    // NEW LOGIC: If it's a new install/update, always prompt the user
    // This gives them control over fetching, regardless of sync state
    if (kDebugMode) {
      if (driveService.syncEnabled) {
        print('AppVersionService: Should prompt for Google fetch - new install/update with sync enabled');
      } else {
        print('AppVersionService: Should prompt for Google fetch - new install/update with Google account but sync disabled');
      }
    }
    return true;
  }
  
  static Future<void> showGoogleFetchDialog(BuildContext context) async {
    final driveService = DriveService.instance;
    final isUpdate = await _isUpdate();
    
    // Always prompt the user, regardless of sync state
    // This gives them control over fetching on new installs/updates
    String dialogMessage;
    if (driveService.syncEnabled) {
      dialogMessage = isUpdate 
        ? 'App update detected. Would you like to refresh your data from Google Drive?'
        : 'New installation detected. Would you like to fetch your existing data from Google Drive?';
    } else {
      dialogMessage = 'This appears to be a new installation or update. Would you like to sync your data from Google Drive?';
    }
    
    if (!context.mounted) return;
    final shouldFetch = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Make it modal for new installs
      builder: (dialogContext) => AlertDialog(
        title: Text(t(context, 'googlefetch')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUpdate ? Icons.system_update : Icons.cloud_download,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(t(context, 'confirm_google_fetch')),
            const SizedBox(height: 8),
            Text(
              dialogMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(t(context, 'fetch')),
          ),
        ],
      ),
    );

    if (shouldFetch == true && context.mounted) {
      await _performGoogleFetch(context);
    }
  }
  
  static Future<bool> _isUpdate() async {
    final settingsBox = Hive.box('settings');
    final storedVersion = settingsBox.get(_versionKey);
    return storedVersion != null; // If there was a stored version, it's an update
  }
  
  static Future<void> _performGoogleFetch(BuildContext context) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text(t(context, 'fetching_data')),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final driveService = DriveService.instance;
      if (driveService.client == null) {
        throw Exception('Google Drive client not available');    
      }

      // Use the existing DriveService downloadFile method
      final content = await driveService.downloadFile();
      if (content == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(context, 'no_data_found')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final entriesBox = Hive.box<InventoryEntry>('entries');
      final settingsBox = Hive.box('settings');

      // Parse the data using the same logic as SettingsTab
      int entriesCount = 0;
      String fetchType = 'unknown';

      // Try JSON first (new format)
      try {
        final decoded = json.decode(content) as Map<String, dynamic>;
        final entries = decoded['entries'] as List<dynamic>?;
        if (entries != null) {
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
          entriesCount = entries.length;
          fetchType = 'JSON';
        }
      } catch (_) {
        // Not JSON — fall through to CSV fallback
        try {
          final rows = const CsvToListConverter().convert(content, eol: '\n');
          if (rows.length > 1) {
            await entriesBox.clear();
            for (var i = 1; i < rows.length; i++) {
              final row = rows[i];
              if (row.length >= 5) {
                final entry = InventoryEntry(
                  row[0].toString(),
                  row[1].toString(),
                  row[2].toString(),
                  row[3].toString(),
                  row[4].toString(),
                );
                entriesBox.add(entry);
              }
            }
            entriesCount = rows.length - 1;
            fetchType = 'CSV';
          }
        } catch (e) {
          throw Exception('Failed to parse data as JSON or CSV: $e');
        }
      }

      if (entriesCount > 0) {
        // Enable sync
        await settingsBox.put('syncEnabled', true);
        await driveService.setSyncEnabled(true);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t(context, 'fetch_success')} ($entriesCount $fetchType)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        if (kDebugMode) {
          print('AppVersionService: Successfully fetched $entriesCount entries from Google Drive ($fetchType)');
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(context, 'no_entries_found')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('AppVersionService: Google fetch failed: $e');
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'fetch_failed')}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}