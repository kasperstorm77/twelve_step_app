//main.dart - Flutter Modular Integration
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Import existing files for initialization
import 'models/inventory_entry.dart';
import 'models/i_am_definition.dart';
import 'models/app_entry.dart';
import 'services/drive_service.dart';
import 'services/inventory_drive_service.dart';
import 'services/i_am_service.dart';
import 'utils/platform_helper.dart';

// Platform-specific imports (only available on mobile)
import 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.html) 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.io) 'package:google_sign_in/google_sign_in.dart';
import 'google_drive_client.dart';

// Import modular app
import 'app/app_module.dart';
import 'app/app_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(InventoryEntryAdapter());
  Hive.registerAdapter(IAmDefinitionAdapter());
  Hive.registerAdapter(AppEntryAdapter());

  try {
    await Hive.openBox<InventoryEntry>('entries');
  } catch (e) {
    print('Error opening entries box: $e');
    // If there's corrupted data, clear the box and start fresh
    await Hive.deleteBoxFromDisk('entries');
    await Hive.openBox<InventoryEntry>('entries');
    print('Cleared corrupted entries box and created new one');
  }

  // Open I Am definitions box
  try {
    await Hive.openBox<IAmDefinition>('i_am_definitions');
  } catch (e) {
    print('Error opening i_am_definitions box: $e');
    await Hive.deleteBoxFromDisk('i_am_definitions');
    await Hive.openBox<IAmDefinition>('i_am_definitions');
    print('Cleared corrupted i_am_definitions box and created new one');
  }

  // Open a separate settings box for sync preferences
  await Hive.openBox('settings');

  // Initialize I Am definitions with default value
  await IAmService().initializeDefaults();

  // Attempt silent sign-in and initialize Drive client early so CRUD
  // operations can sync without the user opening Settings.
  // PLATFORM: This only works on Android/iOS where google_sign_in is available
  if (PlatformHelper.isMobile) {
    try {
      // Initialize the InventoryDriveService
      await InventoryDriveService.instance.initialize();
      
      final scopes = <String>['email', 'https://www.googleapis.com/auth/drive.appdata'];
      final googleSignIn = GoogleSignIn(scopes: scopes);
      final account = await googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        final accessToken = auth.accessToken;
        if (accessToken != null) {
          final client = await GoogleDriveClient.create(account, accessToken);
          DriveService.instance.setClient(client);
          
          // set sync flag from settings box
          final settingsBox = Hive.box('settings');
          final enabled = settingsBox.get('syncEnabled', defaultValue: false) ?? false;
          await DriveService.instance.setSyncEnabled(enabled);
          
          // Enable sync for InventoryDriveService too
          await InventoryDriveService.instance.setSyncEnabled(enabled);
          
          // Check if remote data is newer and auto-sync if needed
          if (enabled) {
            try {
              print('Checking for remote updates...');
              final synced = await InventoryDriveService.instance.checkAndSyncIfNeeded();
              if (synced) {
                print('✓ Auto-synced newer data from Google Drive');
              } else {
                print('✓ Local data is up to date');
              }
            } catch (e) {
              print('Auto-sync check failed: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Silent drive init failed: $e');
    }
  } else {
    print('Google Drive sync not available on ${PlatformHelper.platformName}');
  }

  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}
