//main.dart - Flutter Modular Integration
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Import existing files for initialization
import 'fourth_step/models/inventory_entry.dart';
import 'fourth_step/models/i_am_definition.dart';
import 'shared/models/app_entry.dart';
import 'eighth_step/models/person.dart';
import 'evening_ritual/models/reflection_entry.dart';
import 'gratitude/models/gratitude_entry.dart';
import 'agnosticism/models/agnosticism_paper.dart';
import 'shared/services/legacy_drive_service.dart';
import 'shared/services/all_apps_drive_service_impl.dart';
import 'fourth_step/services/i_am_service.dart';
import 'shared/utils/platform_helper.dart';

// Platform-specific imports (only available on mobile - conditional for web)
import 'shared/services/google_sign_in_wrapper.dart';
import 'shared/services/google_drive_client.dart';

// Import modular app
import 'app/app_module.dart';
import 'app/app_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(InventoryEntryAdapter());
  Hive.registerAdapter(IAmDefinitionAdapter());
  Hive.registerAdapter(AppEntryAdapter());
  Hive.registerAdapter(PersonAdapter());
  Hive.registerAdapter(ColumnTypeAdapter());
  Hive.registerAdapter(ReflectionEntryAdapter());
  Hive.registerAdapter(ReflectionTypeAdapter());
  Hive.registerAdapter(GratitudeEntryAdapter());
  Hive.registerAdapter(PaperStatusAdapter());
  Hive.registerAdapter(AgnosticismPaperAdapter());

  try {
    await Hive.openBox<InventoryEntry>('entries');
  } catch (e) {
    if (kDebugMode) print('Error opening entries box: $e');
    // If there's corrupted data, clear the box and start fresh
    await Hive.deleteBoxFromDisk('entries');
    await Hive.openBox<InventoryEntry>('entries');
    if (kDebugMode) print('Cleared corrupted entries box and created new one');
  }

  // Open I Am definitions box
  try {
    await Hive.openBox<IAmDefinition>('i_am_definitions');
  } catch (e) {
    if (kDebugMode) print('Error opening i_am_definitions box: $e');
    await Hive.deleteBoxFromDisk('i_am_definitions');
    await Hive.openBox<IAmDefinition>('i_am_definitions');
    if (kDebugMode) print('Cleared corrupted i_am_definitions box and created new one');
  }

  // Open people box for 8th step amends
  try {
    await Hive.openBox<Person>('people_box');
  } catch (e) {
    if (kDebugMode) print('Error opening people_box: $e');
    await Hive.deleteBoxFromDisk('people_box');
    await Hive.openBox<Person>('people_box');
    if (kDebugMode) print('Cleared corrupted people_box and created new one');
  }

  // Open reflections box for evening ritual
  try {
    await Hive.openBox<ReflectionEntry>('reflections_box');
  } catch (e) {
    if (kDebugMode) print('Error opening reflections_box: $e');
    // The data model changed significantly - clear and recreate
    try {
      await Hive.deleteBoxFromDisk('reflections_box');
    } catch (deleteError) {
      if (kDebugMode) print('Error deleting reflections_box: $deleteError (this is okay)');
      // If we can't delete, try closing and reopening
      try {
        await Hive.close();
      } catch (_) {}
    }
    await Hive.openBox<ReflectionEntry>('reflections_box');
    if (kDebugMode) print('Cleared corrupted reflections_box and created new one');
  }

  // Open gratitude box
  try {
    await Hive.openBox<GratitudeEntry>('gratitude_box');
  } catch (e) {
    if (kDebugMode) print('Error opening gratitude_box: $e');
    await Hive.deleteBoxFromDisk('gratitude_box');
    await Hive.openBox<GratitudeEntry>('gratitude_box');
    if (kDebugMode) print('Cleared corrupted gratitude_box and created new one');
  }

  // Open agnosticism papers box
  try {
    await Hive.openBox<AgnosticismPaper>('agnosticism_papers');
  } catch (e) {
    if (kDebugMode) print('Error opening agnosticism_papers: $e');
    await Hive.deleteBoxFromDisk('agnosticism_papers');
    await Hive.openBox<AgnosticismPaper>('agnosticism_papers');
    if (kDebugMode) print('Cleared corrupted agnosticism_papers and created new one');
  }

  // Open a separate settings box for sync preferences
  await Hive.openBox('settings');

  // Initialize I Am definitions with default value
  await IAmService().initializeDefaults();

  // Initialize AllAppsDriveService (on web this will be a no-op stub)
  try {
    await AllAppsDriveService.instance.initialize();
  } catch (e) {
    if (kDebugMode) print('AllAppsDriveService initialization: $e');
  }

  // Attempt silent sign-in and initialize Drive client early so CRUD
  // operations can sync without the user opening Settings.
  // PLATFORM: This only works on Android/iOS where google_sign_in is available
  if (PlatformHelper.isMobile || PlatformHelper.isWeb) {
    try {
      // Initialize AllAppsDriveService (handles platform-specific auth internally)
      await AllAppsDriveService.instance.initialize();
      
      if (PlatformHelper.isMobile) {
        // Mobile-specific: Use GoogleSignIn for backward compatibility with legacy DriveService
        final scopes = <String>['email', 'https://www.googleapis.com/auth/drive.appdata'];
        final googleSignIn = Platform.isIOS
            ? GoogleSignIn(
                scopes: scopes,
                // iOS requires iOS OAuth client for Drive API access
                serverClientId: '628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k.apps.googleusercontent.com',
              )
            : GoogleSignIn(scopes: scopes); // Android uses default (no serverClientId)
        final account = await googleSignIn.signInSilently();
        if (account != null) {
          final auth = await account.authentication;
          final accessToken = auth.accessToken;
          if (accessToken != null) {
            final client = await GoogleDriveClient.create(account, accessToken);
            DriveService.instance.setClient(client);
            
            // set sync flag from settings box
            final settingsBox = Hive.box('settings');
            // Enable sync by default when Google account is available
            final enabled = settingsBox.get('syncEnabled', defaultValue: true) ?? true;
            await settingsBox.put('syncEnabled', enabled); // Save the default
            await DriveService.instance.setSyncEnabled(enabled);
            
            // Enable sync for AllAppsDriveService too
            await AllAppsDriveService.instance.setSyncEnabled(enabled);
            
            // Check if remote data is newer and auto-sync if needed
            if (enabled) {
              try {
                if (kDebugMode) print('Checking for remote updates...');
                final synced = await AllAppsDriveService.instance.checkAndSyncIfNeeded();
                if (synced) {
                  if (kDebugMode) print('✓ Auto-synced newer data from Google Drive');
                } else {
                  if (kDebugMode) print('✓ Local data is up to date');
                }
              } catch (e) {
                if (kDebugMode) print('Auto-sync check failed: $e');
              }
            }
          }
        }
      } else if (PlatformHelper.isWeb) {
        // Web-specific: AllAppsDriveService handles everything
        // Silent sign-in will be attempted by the service's initialize()
        if (kDebugMode) print('Web: Checking authentication status...');
        if (AllAppsDriveService.instance.isAuthenticated) {
          if (kDebugMode) print('Web: User is authenticated');
          final settingsBox = Hive.box('settings');
          final enabled = settingsBox.get('syncEnabled', defaultValue: true) ?? true;
          await settingsBox.put('syncEnabled', enabled);
          await AllAppsDriveService.instance.setSyncEnabled(enabled);
          
          if (enabled) {
            try {
              if (kDebugMode) print('Checking for remote updates...');
              final synced = await AllAppsDriveService.instance.checkAndSyncIfNeeded();
              if (synced) {
                if (kDebugMode) print('✓ Auto-synced newer data from Google Drive');
              } else {
                if (kDebugMode) print('✓ Local data is up to date');
              }
            } catch (e) {
              if (kDebugMode) print('Auto-sync check failed: $e');
            }
          }
        } else {
          if (kDebugMode) print('Web: User not authenticated - sign in required in Data Management');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Silent drive init failed: $e');
    }
  } else {
    if (kDebugMode) print('Google Drive sync not available on ${PlatformHelper.platformName}');
  }

  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}
