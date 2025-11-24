import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/app_entry.dart';

/// Service for managing app selection and switching
class AppSwitcherService {
  static const String _selectedAppKey = 'selected_app_id';
  static const String _settingsBoxName = 'settings';

  /// Get the currently selected app ID
  static String getSelectedAppId() {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      final selectedId = settingsBox.get(_selectedAppKey) as String?;
      return selectedId ?? AvailableApps.fourthStepInventory;
    } catch (e) {
      if (kDebugMode) print('AppSwitcherService: Error getting selected app - $e');
      return AvailableApps.fourthStepInventory;
    }
  }

  /// Set the currently selected app ID
  static Future<void> setSelectedAppId(String appId) async {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      await settingsBox.put(_selectedAppKey, appId);
      if (kDebugMode) print('AppSwitcherService: Selected app changed to $appId');
    } catch (e) {
      if (kDebugMode) print('AppSwitcherService: Error setting selected app - $e');
    }
  }

  /// Get the currently selected app (requires context for localization)
  static AppEntry? getSelectedApp(BuildContext? context) {
    final selectedId = getSelectedAppId();
    if (context == null) return null;
    final apps = AvailableApps.getAll(context);
    return apps.firstWhere(
      (app) => app.id == selectedId,
      orElse: () => AvailableApps.getDefault(context)!,
    );
  }

  /// Check if a specific app is currently selected
  static bool isAppSelected(String appId) {
    return getSelectedAppId() == appId;
  }

  /// Check if the 4th Step Inventory app is selected
  static bool is4thStepInventorySelected() {
    return isAppSelected(AvailableApps.fourthStepInventory);
  }
}
