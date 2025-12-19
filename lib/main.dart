//main.dart - Flutter Modular Integration
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

// Import existing files for initiy alization
import 'fourth_step/models/inventory_entry.dart';
import 'fourth_step/models/i_am_definition.dart';
import 'fourth_step/services/inventory_service.dart';
import 'shared/models/app_entry.dart';
import 'eighth_step/models/person.dart';
import 'evening_ritual/models/reflection_entry.dart';
import 'morning_ritual/models/ritual_item.dart';
import 'morning_ritual/models/morning_ritual_entry.dart';
import 'gratitude/models/gratitude_entry.dart';
import 'agnosticism/models/barrier_power_pair.dart';
import 'shared/services/all_apps_drive_service.dart';
import 'fourth_step/services/i_am_service.dart';
import 'shared/utils/platform_helper.dart';
import 'shared/services/app_settings_service.dart';
import 'shared/services/app_switcher_service.dart';

// Import modular app
import 'app/app_module.dart';
import 'app/app_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startupTotal = Stopwatch()..start();
  Future<T> timed<T>(String label, Future<T> Function() action) async {
    final sw = Stopwatch()..start();
    final result = await action();
    sw.stop();
    if (kDebugMode) {
      print('startup: $label ${sw.elapsedMilliseconds}ms (total ${startupTotal.elapsedMilliseconds}ms)');
    }
    return result;
  }

  // Initialize window manager for desktop platforms
  if (PlatformHelper.isDesktop) {
    await timed('windowManager.ensureInitialized', () => windowManager.ensureInitialized());
    
    // Get localized window title based on system locale
    final locale = ui.PlatformDispatcher.instance.locale;
    final windowTitle = locale.languageCode == 'da' ? 'Tolv Trins app' : 'Twelve Steps app';
    
    final windowOptions = WindowOptions(
      size: const Size(800, 800),
      minimumSize: const Size(400, 400),
      center: true,
      title: windowTitle,
    );
    await timed(
      'windowManager.waitUntilReadyToShow',
      () => windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  await timed('Hive.initFlutter', () => Hive.initFlutter());

  Hive.registerAdapter(InventoryEntryAdapter());
  Hive.registerAdapter(InventoryCategoryAdapter());
  Hive.registerAdapter(IAmDefinitionAdapter());
  Hive.registerAdapter(AppEntryAdapter());
  Hive.registerAdapter(PersonAdapter());
  Hive.registerAdapter(ColumnTypeAdapter());
  Hive.registerAdapter(ReflectionEntryAdapter());
  Hive.registerAdapter(ReflectionTypeAdapter());
  Hive.registerAdapter(GratitudeEntryAdapter());
  Hive.registerAdapter(BarrierPowerPairAdapter());
  Hive.registerAdapter(RitualItemTypeAdapter());
  Hive.registerAdapter(RitualItemAdapter());
  Hive.registerAdapter(RitualItemStatusAdapter());
  Hive.registerAdapter(RitualItemRecordAdapter());
  Hive.registerAdapter(MorningRitualEntryAdapter());

  try {
    await timed("Hive.openBox('entries')", () => Hive.openBox<InventoryEntry>('entries'));
  } catch (e) {
    if (kDebugMode) print('Error opening entries box: $e');
    // If there's corrupted data, clear the box and start fresh
    await timed("Hive.deleteBoxFromDisk('entries')", () => Hive.deleteBoxFromDisk('entries'));
    await timed("Hive.openBox('entries') [recreate]", () => Hive.openBox<InventoryEntry>('entries'));
    if (kDebugMode) print('Cleared corrupted entries box and created new one');
  }

  // Open I Am definitions box
  try {
    await timed("Hive.openBox('i_am_definitions')", () => Hive.openBox<IAmDefinition>('i_am_definitions'));
  } catch (e) {
    if (kDebugMode) print('Error opening i_am_definitions box: $e');
    await timed("Hive.deleteBoxFromDisk('i_am_definitions')", () => Hive.deleteBoxFromDisk('i_am_definitions'));
    await timed("Hive.openBox('i_am_definitions') [recreate]", () => Hive.openBox<IAmDefinition>('i_am_definitions'));
    if (kDebugMode) print('Cleared corrupted i_am_definitions box and created new one');
  }

  // Open people box for 8th step amends
  try {
    await timed("Hive.openBox('people_box')", () => Hive.openBox<Person>('people_box'));
  } catch (e) {
    if (kDebugMode) print('Error opening people_box: $e');
    await timed("Hive.deleteBoxFromDisk('people_box')", () => Hive.deleteBoxFromDisk('people_box'));
    await timed("Hive.openBox('people_box') [recreate]", () => Hive.openBox<Person>('people_box'));
    if (kDebugMode) print('Cleared corrupted people_box and created new one');
  }

  // Open reflections box for evening ritual
  try {
    await timed("Hive.openBox('reflections_box')", () => Hive.openBox<ReflectionEntry>('reflections_box'));
  } catch (e) {
    if (kDebugMode) print('Error opening reflections_box: $e');
    // The data model changed significantly - clear and recreate
    try {
      await timed("Hive.deleteBoxFromDisk('reflections_box')", () => Hive.deleteBoxFromDisk('reflections_box'));
    } catch (deleteError) {
      if (kDebugMode) print('Error deleting reflections_box: $deleteError (this is okay)');
      // If we can't delete, try closing and reopening
      try {
        await timed('Hive.close', () => Hive.close());
      } catch (_) {}
    }
    await timed("Hive.openBox('reflections_box') [recreate]", () => Hive.openBox<ReflectionEntry>('reflections_box'));
    if (kDebugMode) print('Cleared corrupted reflections_box and created new one');
  }

  // Open gratitude box
  try {
    await timed("Hive.openBox('gratitude_box')", () => Hive.openBox<GratitudeEntry>('gratitude_box'));
  } catch (e) {
    if (kDebugMode) print('Error opening gratitude_box: $e');
    await timed("Hive.deleteBoxFromDisk('gratitude_box')", () => Hive.deleteBoxFromDisk('gratitude_box'));
    await timed("Hive.openBox('gratitude_box') [recreate]", () => Hive.openBox<GratitudeEntry>('gratitude_box'));
    if (kDebugMode) print('Cleared corrupted gratitude_box and created new one');
  }

  // Open agnosticism pairs box
  try {
    await timed("Hive.openBox('agnosticism_pairs')", () => Hive.openBox<BarrierPowerPair>('agnosticism_pairs'));
  } catch (e) {
    if (kDebugMode) print('Error opening agnosticism_pairs: $e');
    await timed("Hive.deleteBoxFromDisk('agnosticism_pairs')", () => Hive.deleteBoxFromDisk('agnosticism_pairs'));
    await timed("Hive.openBox('agnosticism_pairs') [recreate]", () => Hive.openBox<BarrierPowerPair>('agnosticism_pairs'));
    if (kDebugMode) print('Cleared corrupted agnosticism_pairs and created new one');
  }

  // Open morning ritual items box (definitions)
  try {
    await timed("Hive.openBox('morning_ritual_items')", () => Hive.openBox<RitualItem>('morning_ritual_items'));
  } catch (e) {
    if (kDebugMode) print('Error opening morning_ritual_items: $e');
    await timed("Hive.deleteBoxFromDisk('morning_ritual_items')", () => Hive.deleteBoxFromDisk('morning_ritual_items'));
    await timed("Hive.openBox('morning_ritual_items') [recreate]", () => Hive.openBox<RitualItem>('morning_ritual_items'));
    if (kDebugMode) print('Cleared corrupted morning_ritual_items and created new one');
  }

  // Open morning ritual entries box (daily completions)
  try {
    await timed("Hive.openBox('morning_ritual_entries')", () => Hive.openBox<MorningRitualEntry>('morning_ritual_entries'));
  } catch (e) {
    if (kDebugMode) print('Error opening morning_ritual_entries: $e');
    await timed("Hive.deleteBoxFromDisk('morning_ritual_entries')", () => Hive.deleteBoxFromDisk('morning_ritual_entries'));
    await timed("Hive.openBox('morning_ritual_entries') [recreate]", () => Hive.openBox<MorningRitualEntry>('morning_ritual_entries'));
    if (kDebugMode) print('Cleared corrupted morning_ritual_entries and created new one');
  }

  // Open a separate settings box for sync preferences
  await timed("Hive.openBox('settings')", () => Hive.openBox('settings'));

  // Migration: Assign order values to existing entries (runs once, also called after restore)
  await timed('InventoryService.migrateOrderValues', () => InventoryService.migrateOrderValues());

  // Initialize I Am definitions with default value
  await timed('IAmService.initializeDefaults', () => IAmService().initializeDefaults());

  // NOTE: Morning ritual check is done AFTER Drive sync to ensure restored settings are used

  // Attempt silent sign-in and initialize Drive client early so CRUD operations can sync
  // without the user opening Settings.
  if (PlatformHelper.isMobile || PlatformHelper.isWeb || PlatformHelper.isDesktop) {
    try {
      await timed('AllAppsDriveService.initialize', () => AllAppsDriveService.instance.initialize());

      if (AllAppsDriveService.instance.isAuthenticated) {
        final settingsBox = Hive.box('settings');

        // Preserve existing behavior: default syncEnabled=true once an account is available.
        final enabled = settingsBox.get('syncEnabled', defaultValue: true) ?? true;
        await timed("settings.put('syncEnabled')", () => settingsBox.put('syncEnabled', enabled));
        await timed('AllAppsDriveService.setSyncEnabled', () => AllAppsDriveService.instance.setSyncEnabled(enabled));

        if (enabled) {
          final remoteNewer = await timed('AllAppsDriveService.isRemoteNewer', () => AllAppsDriveService.instance.isRemoteNewer());
          if (remoteNewer) {
            if (kDebugMode) print('startup: ⚠️ Remote has newer data - blocking uploads until user fetches or dismisses');
            AllAppsDriveService.instance.blockUploads();
          } else {
            if (kDebugMode) print('startup: ✓ Local data is up to date');
          }
        }
      } else {
        if (kDebugMode) print('startup: Drive not authenticated - sign in required in Data Management');
      }
    } catch (e) {
      if (kDebugMode) print('startup: Silent drive init failed: $e');
    }
  } else {
    if (kDebugMode) print('startup: Google Drive sync not available on ${PlatformHelper.platformName}');
  }

  // Check if we should auto-load morning ritual at app startup (only once per day)
  // This is done AFTER Drive sync so restored settings from backup are used
  if (AppSettingsService.shouldForceMorningRitual()) {
    if (kDebugMode) print('main: Within morning ritual window (first time today), setting morning ritual as selected app');
    await timed('AppSwitcherService.setSelectedAppId(morningRitual)', () => AppSwitcherService.setSelectedAppId(AvailableApps.morningRitual));
    await timed('AppSettingsService.markMorningRitualForced', () => AppSettingsService.markMorningRitualForced());
  }

  startupTotal.stop();
  if (kDebugMode) print('startup: runApp (total ${startupTotal.elapsedMilliseconds}ms)');
  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}
