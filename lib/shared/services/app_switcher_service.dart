import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/app_entry.dart';

/// Service for managing app selection and switching.
/// 
/// Provides both synchronous access ([getSelectedAppId]) and reactive updates
/// via [selectedAppNotifier] for UI components that need to rebuild on changes.
class AppSwitcherService {
  static const String _selectedAppKey = 'selected_app_id';
  static const String _settingsBoxName = 'settings';

  // ---------------------------------------------------------------------------
  // Reactive State Management
  // ---------------------------------------------------------------------------
  
  /// Singleton ValueNotifier for reactive app selection changes.
  /// Use this with ValueListenableBuilder for automatic UI rebuilds.
  static final ValueNotifier<String> _selectedAppNotifier = ValueNotifier<String>(
    _loadInitialAppId(),
  );

  /// Reactive notifier for selected app ID changes.
  /// 
  /// Example usage:
  /// ```dart
  /// ValueListenableBuilder<String>(
  ///   valueListenable: AppSwitcherService.selectedAppNotifier,
  ///   builder: (context, appId, _) => buildAppForId(appId),
  /// )
  /// ```
  static ValueNotifier<String> get selectedAppNotifier => _selectedAppNotifier;

  /// Load initial app ID from Hive (called once at static initialization)
  static String _loadInitialAppId() {
    try {
      if (Hive.isBoxOpen(_settingsBoxName)) {
        final settingsBox = Hive.box(_settingsBoxName);
        final selectedId = settingsBox.get(_selectedAppKey) as String?;
        return selectedId ?? AvailableApps.fourthStepInventory;
      }
    } catch (e) {
      if (kDebugMode) print('AppSwitcherService: Error loading initial app - $e');
    }
    return AvailableApps.fourthStepInventory;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Get the currently selected app ID (synchronous read).
  /// 
  /// For reactive updates, use [selectedAppNotifier] instead.
  static String getSelectedAppId() {
    return _selectedAppNotifier.value;
  }

  /// Set the currently selected app ID.
  /// 
  /// This updates both the persistent Hive storage and the reactive notifier,
  /// triggering rebuilds in any UI listening to [selectedAppNotifier].
  static Future<void> setSelectedAppId(String appId) async {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      await settingsBox.put(_selectedAppKey, appId);
      
      // Update notifier AFTER successful persistence
      _selectedAppNotifier.value = appId;
      
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
