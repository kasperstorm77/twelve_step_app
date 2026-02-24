import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service for tracking app version changes.
/// 
/// Note: Google Drive sync is now handled automatically via timestamp comparison
/// in main.dart using AllAppsDriveService.checkAndSyncIfNeeded(). This service
/// only tracks version for informational purposes.
class AppVersionService {
  static const String _versionKey = 'app_version';
  static const String _installDateKey = 'install_date';
  
  /// Checks if this is a new installation or an app update.
  /// Records the current version for future comparisons.
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
  
  /// Returns true if the app was updated (vs fresh install).
  static Future<bool> isUpdate() async {
    final settingsBox = Hive.box('settings');
    final storedVersion = settingsBox.get(_versionKey);
    return storedVersion != null; // If there was a stored version, it's an update
  }
  
  /// Gets the current app version string.
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
