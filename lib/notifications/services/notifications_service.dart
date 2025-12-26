import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../fourth_step/models/inventory_entry.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../../shared/utils/platform_helper.dart';
import '../models/app_notification.dart';

class NotificationsService {
  static const String notificationsBoxName = 'notifications_box';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    
    // Get the device's actual timezone
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
      if (kDebugMode) {
        print('NotificationsService: Using timezone $timezoneName');
      }
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
      if (kDebugMode) {
        print('NotificationsService: Failed to get timezone, using UTC: $e');
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  static Future<void> requestPermissionsIfNeeded() async {
    if (!PlatformHelper.isMobile) return;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      
      // Android 12+ requires explicit "Alarms & reminders" permission
      final canSchedule = await android.canScheduleExactNotifications() ?? false;
      debugPrint('NotificationsService: canScheduleExactNotifications = $canSchedule');
      if (!canSchedule) {
        debugPrint('NotificationsService: Requesting exact alarm permission...');
        await android.requestExactAlarmsPermission();
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true, 
        badge: true, 
        sound: true,
        critical: true,  // Request critical alerts for time-sensitive notifications
      );
      if (kDebugMode) {
        print('NotificationsService: iOS permissions granted = $granted');
      }
    }
  }

  /// Check and print iOS notification permission status (for debugging)
  static Future<void> checkPermissionStatus() async {
    if (!PlatformHelper.isMobile) return;
    
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      if (kDebugMode) {
        print('NotificationsService: iOS permission status:');
        print('  - isEnabled: ${settings?.isEnabled}');
        print('  - isAlertEnabled: ${settings?.isAlertEnabled}');
        print('  - isBadgeEnabled: ${settings?.isBadgeEnabled}');
        print('  - isSoundEnabled: ${settings?.isSoundEnabled}');
        print('  - isProvisionalEnabled: ${settings?.isProvisionalEnabled}');
      }
    }
    
    // Also show pending notifications
    final pending = await _plugin.pendingNotificationRequests();
    if (kDebugMode) {
      print('NotificationsService: ${pending.length} pending notifications:');
      for (final p in pending) {
        print('  - ID: ${p.id}, Title: ${p.title}, Body: ${p.body}');
      }
    }
  }

  static Box<AppNotification> get box => Hive.box<AppNotification>(notificationsBoxName);

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(notificationsBoxName)) {
      await Hive.openBox<AppNotification>(notificationsBoxName);
    }
  }

  static int generateNotificationId() {
    final rng = Random();
    int id;
    do {
      id = rng.nextInt(1 << 31);
    } while (box.values.any((n) => n.notificationId == id));
    return id;
  }

  static tz.TZDateTime _nextInstanceOfTime(int timeMinutes) {
    final now = tz.TZDateTime.now(tz.local);
    final target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeMinutes ~/ 60,
      timeMinutes % 60,
    );
    if (target.isAfter(now)) return target;
    return target.add(const Duration(days: 1));
  }

  static tz.TZDateTime _nextInstanceOfWeekday(int weekday, int timeMinutes) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeMinutes ~/ 60,
      timeMinutes % 60,
    );

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  static NotificationDetails _details(AppNotification notification) {
    final androidDetails = AndroidNotificationDetails(
      'daily_notifications',
      'Daily notifications',
      channelDescription: 'Reminders scheduled by the Notifications app',
      importance: Importance.max,
      priority: Priority.high,
      playSound: notification.soundEnabled,
      enableVibration: notification.vibrateEnabled,
      fullScreenIntent: true,  // This helps wake the device
      category: AndroidNotificationCategory.alarm,  // Mark as alarm category
    );

    // For iOS: use default sound when sound is enabled
    // Setting sound to null uses the default iOS notification sound
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: notification.soundEnabled,
      sound: notification.soundEnabled ? 'default' : null,
      // Ensure notifications show even when app is in foreground
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  static Future<void> schedule(AppNotification notification) async {
    await initialize();

    await cancel(notification);

    if (!notification.enabled) {
      if (kDebugMode) {
        print('NotificationsService.schedule: notification disabled, skipping');
      }
      return;
    }

    // Disregard Windows: the plugin supports it, but repeating limitations exist.
    if (!PlatformHelper.isMobile && !PlatformHelper.isDesktop) {
      if (kDebugMode) {
        print('NotificationsService.schedule: unsupported platform, skipping');
      }
      return;
    }

    try {
      // Check exact alarm permission on Android
      if (PlatformHelper.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          final canSchedule = await android.canScheduleExactNotifications() ?? false;
          if (kDebugMode) {
            print('NotificationsService.schedule: canScheduleExactNotifications = $canSchedule');
          }
          if (!canSchedule) {
            debugPrint('WARNING: Cannot schedule exact notifications! User must grant "Alarms & reminders" permission.');
            await android.requestExactAlarmsPermission();
            return;
          }
        }
      }

      if (notification.scheduleType == NotificationScheduleType.daily) {
        final scheduledTime = _nextInstanceOfTime(notification.timeMinutes);
        if (kDebugMode) {
          print('NotificationsService.schedule: scheduling daily notification');
          print('  - ID: ${notification.notificationId}');
          print('  - Title: ${notification.title}');
          print('  - Scheduled for: $scheduledTime');
          print('  - Now is: ${tz.TZDateTime.now(tz.local)}');
        }
        await _plugin.zonedSchedule(
          notification.notificationId,
          notification.title,
          notification.body,
          scheduledTime,
          _details(notification),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,  // Repeat daily at same time
          payload: notification.id,
        );
        if (kDebugMode) {
          print('NotificationsService.schedule: zonedSchedule call completed (daily repeating)');
          // Verify it was scheduled
          final pending = await _plugin.pendingNotificationRequests();
          final found = pending.any((p) => p.id == notification.notificationId);
          print('NotificationsService.schedule: Verified in pending list: $found');
        }
      } else {
        // Weekly: schedule one per weekday. We allocate derived IDs.
        for (final weekday in notification.weekdays.toSet()) {
          final derivedId = _derivedNotificationId(notification.notificationId, weekday);
          final scheduledTime = _nextInstanceOfWeekday(weekday, notification.timeMinutes);
          if (kDebugMode) {
            print('NotificationsService.schedule: scheduling weekly notification for weekday $weekday');
            print('  - Derived ID: $derivedId');
            print('  - Scheduled for: $scheduledTime');
          }
          await _plugin.zonedSchedule(
            derivedId,
            notification.title,
            notification.body,
            scheduledTime,
            _details(notification),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: notification.id,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationsService.schedule: failed $e');
      }
    }
  }

  static int _derivedNotificationId(int base, int weekday) {
    // Keep IDs stable and distinct: base in high range, offset by weekday.
    // Weekday is 1..7.
    final safeBase = base & 0x7FFFFFF8;
    return safeBase + (weekday.clamp(1, 7));
  }

  static Future<void> cancel(AppNotification notification) async {
    await initialize();

    // Wrap cancel calls in try-catch to handle corrupted plugin cache
    // (can happen after app reinstall when stale data exists)
    try {
      await _plugin.cancel(notification.notificationId);
      for (var weekday = 1; weekday <= 7; weekday++) {
        await _plugin.cancel(_derivedNotificationId(notification.notificationId, weekday));
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationsService.cancel: failed (likely stale cache): $e');
      }
      // Ignore errors - the notification may not exist or cache is corrupted
    }
  }

  static Future<void> rescheduleAll() async {
    await initialize();
    await openBox();

    if (kDebugMode) {
      print('NotificationsService.rescheduleAll: Scheduling ${box.values.length} notifications');
    }

    for (final notification in box.values) {
      await schedule(notification);
    }

    // Debug: List all pending notifications
    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      print('NotificationsService.rescheduleAll: ${pending.length} pending notifications:');
      for (final p in pending) {
        print('  - ID: ${p.id}, Title: ${p.title}');
      }
    }
  }

  /// Show a test notification immediately (for debugging)
  static Future<void> showTestNotification() async {
    await initialize();
    
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test notifications',
      channelDescription: 'Test channel for debugging',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _plugin.show(
      0,
      'Test Notification',
      'If you see this, notifications are working!',
      details,
    );
    
    if (kDebugMode) {
      print('NotificationsService.showTestNotification: Showed test notification');
    }
  }

  static Future<void> upsert(AppNotification notification) async {
    await openBox();

    await box.put(notification.id, notification);
    await schedule(notification);
    _triggerSync();
  }

  static Future<void> delete(AppNotification notification) async {
    await openBox();

    await cancel(notification);
    await box.delete(notification.id);
    _triggerSync();
  }

  /// Trigger background sync after changes
  static void _triggerSync() {
    try {
      // Trigger sync using the centralized AllAppsDriveService
      // Note: Uses entries box as trigger, but syncs all apps
      final entriesBox = Hive.box<InventoryEntry>('entries');
      AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
    } catch (e) {
      if (kDebugMode) {
        print('Sync not available or failed: $e');
      }
      // Sync not available or failed, silently continue
    }
  }
}
