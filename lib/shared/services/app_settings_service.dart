import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for managing app-wide settings like morning ritual auto-load
class AppSettingsService {
  static const String _settingsBoxName = 'settings';
  
  // Morning ritual settings keys
  static const String _morningRitualEnabledKey = 'morning_ritual_auto_load_enabled';
  static const String _morningStartHourKey = 'morning_ritual_start_hour';
  static const String _morningStartMinuteKey = 'morning_ritual_start_minute';
  static const String _morningEndHourKey = 'morning_ritual_end_hour';
  static const String _morningEndMinuteKey = 'morning_ritual_end_minute';
  static const String _morningRitualLastForcedDateKey = 'morning_ritual_last_forced_date';

  // 4th step settings keys
  static const String _fourthStepCompactViewEnabledKey = 'fourth_step_compact_view_enabled';

  static bool getFourthStepCompactViewEnabled() {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      return settingsBox.get(
            _fourthStepCompactViewEnabledKey,
            defaultValue: false,
          ) as bool;
    } catch (e) {
      if (kDebugMode) {
        print('AppSettingsService: Error getting 4th step compact view setting - $e');
      }
      return false;
    }
  }

  static Future<void> setFourthStepCompactViewEnabled(bool enabled) async {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      await settingsBox.put(_fourthStepCompactViewEnabledKey, enabled);
    } catch (e) {
      if (kDebugMode) {
        print('AppSettingsService: Error saving 4th step compact view setting - $e');
      }
    }
  }

  /// Get morning ritual settings
  static Map<String, dynamic> getMorningRitualSettings() {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      
      final enabled = settingsBox.get(_morningRitualEnabledKey, defaultValue: false) as bool;
      final startHour = settingsBox.get(_morningStartHourKey, defaultValue: 6) as int;
      final startMinute = settingsBox.get(_morningStartMinuteKey, defaultValue: 0) as int;
      final endHour = settingsBox.get(_morningEndHourKey, defaultValue: 9) as int;
      final endMinute = settingsBox.get(_morningEndMinuteKey, defaultValue: 0) as int;
      
      return {
        'enabled': enabled,
        'startTime': TimeOfDay(hour: startHour, minute: startMinute),
        'endTime': TimeOfDay(hour: endHour, minute: endMinute),
      };
    } catch (e) {
      if (kDebugMode) print('AppSettingsService: Error getting morning ritual settings - $e');
      return {
        'enabled': false,
        'startTime': const TimeOfDay(hour: 5, minute: 0),
        'endTime': const TimeOfDay(hour: 9, minute: 0),
      };
    }
  }

  /// Save morning ritual settings
  static Future<void> saveMorningRitualSettings({
    required bool enabled,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      
      await settingsBox.put(_morningRitualEnabledKey, enabled);
      await settingsBox.put(_morningStartHourKey, startTime.hour);
      await settingsBox.put(_morningStartMinuteKey, startTime.minute);
      await settingsBox.put(_morningEndHourKey, endTime.hour);
      await settingsBox.put(_morningEndMinuteKey, endTime.minute);
      
      if (kDebugMode) {
        print('AppSettingsService: Saved morning ritual settings - enabled: $enabled, '
            'start: ${startTime.hour}:${startTime.minute}, end: ${endTime.hour}:${endTime.minute}');
      }
    } catch (e) {
      if (kDebugMode) print('AppSettingsService: Error saving morning ritual settings - $e');
    }
  }

  /// Check if current time is within the morning ritual time window
  static bool isWithinMorningRitualWindow() {
    final settings = getMorningRitualSettings();
    final enabled = settings['enabled'] as bool;
    
    if (!enabled) return false;
    
    final now = TimeOfDay.now();
    final startTime = settings['startTime'] as TimeOfDay;
    final endTime = settings['endTime'] as TimeOfDay;
    
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  /// Check if we should force morning ritual (only once per day)
  /// Returns true if within window AND haven't forced today yet
  static bool shouldForceMorningRitual() {
    if (!isWithinMorningRitualWindow()) return false;
    
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      final lastForcedDate = settingsBox.get(_morningRitualLastForcedDateKey) as String?;
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      
      // Already forced today
      if (lastForcedDate == today) {
        if (kDebugMode) print('AppSettingsService: Already forced morning ritual today');
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) print('AppSettingsService: Error checking last forced date - $e');
      return false;
    }
  }

  /// Mark that we've forced morning ritual today
  static Future<void> markMorningRitualForced() async {
    try {
      final settingsBox = Hive.box(_settingsBoxName);
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      await settingsBox.put(_morningRitualLastForcedDateKey, today);
      if (kDebugMode) print('AppSettingsService: Marked morning ritual as forced for $today');
    } catch (e) {
      if (kDebugMode) print('AppSettingsService: Error marking morning ritual forced - $e');
    }
  }

  /// Export settings for Drive sync
  static Map<String, dynamic> exportForSync() {
    final settings = getMorningRitualSettings();
    final startTime = settings['startTime'] as TimeOfDay;
    final endTime = settings['endTime'] as TimeOfDay;
    
    return {
      'morningRitualAutoLoadEnabled': settings['enabled'] as bool,
      'morningRitualStartTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
      'morningRitualEndTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
      'fourthStepCompactViewEnabled': getFourthStepCompactViewEnabled(),
    };
  }

  /// Import settings from Drive sync
  static Future<void> importFromSync(Map<String, dynamic> data) async {
    try {
      final enabled = data['morningRitualAutoLoadEnabled'] as bool? ?? false;

      final compactViewEnabled =
          data['fourthStepCompactViewEnabled'] as bool? ?? false;
      
      TimeOfDay startTime = const TimeOfDay(hour: 5, minute: 0);
      TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);
      
      // Parse start time (format: "HH:MM:SS")
      final startTimeStr = data['morningRitualStartTime'] as String?;
      if (startTimeStr != null) {
        final parts = startTimeStr.split(':');
        if (parts.length >= 2) {
          startTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 5,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      
      // Parse end time (format: "HH:MM:SS")
      final endTimeStr = data['morningRitualEndTime'] as String?;
      if (endTimeStr != null) {
        final parts = endTimeStr.split(':');
        if (parts.length >= 2) {
          endTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      
      await saveMorningRitualSettings(
        enabled: enabled,
        startTime: startTime,
        endTime: endTime,
      );

      await setFourthStepCompactViewEnabled(compactViewEnabled);
      
      if (kDebugMode) print('AppSettingsService: Imported morning ritual settings from sync');
    } catch (e) {
      if (kDebugMode) print('AppSettingsService: Error importing settings from sync - $e');
    }
  }
}
