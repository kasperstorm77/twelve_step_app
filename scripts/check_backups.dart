// Script to check available Google Drive backups
// Run with: dart scripts/check_backups.dart
//
// NOTE: This script cannot directly access Google Drive because it requires
// OAuth authentication which is handled by the Flutter app.
//
// To check your available backups:
// 1. Open the app on Windows or mobile
// 2. Go to Settings (gear icon) -> Data Management tab
// 3. Sign in to Google if not already signed in
// 4. Look for "Select Restore Point" dropdown - this lists all available backups
// 5. Select the backup from Dec 15 or 16 if available
// 6. Click "Restore from Backup" to restore that data
//
// Alternative: Check Google Drive directly
// 1. Go to https://drive.google.com
// 2. The app stores data in "Application Data" (hidden folder)
// 3. Unfortunately, app-specific data in appDataFolder is not visible in Drive UI
//
// The app keeps backups with this retention policy:
// - Today: All backups with timestamps
// - Previous 7 days: One backup per day
// - Previous 12 months: One backup per month

import 'dart:io';

void main() {
  print('');
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           GOOGLE DRIVE BACKUP CHECK INSTRUCTIONS                ║');
  print('╠══════════════════════════════════════════════════════════════════╣');
  print('║                                                                  ║');
  print('║  To check and restore backups from Dec 15-16:                   ║');
  print('║                                                                  ║');
  print('║  1. Open the Twelve Steps app (Windows or mobile)               ║');
  print('║                                                                  ║');
  print('║  2. Tap the GEAR icon (⚙️) in the top right                      ║');
  print('║                                                                  ║');
  print('║  3. Go to "Data Management" tab                                 ║');
  print('║                                                                  ║');
  print('║  4. Sign in to Google if not already connected                  ║');
  print('║                                                                  ║');
  print('║  5. Look for "Select Restore Point" dropdown                    ║');
  print('║     This will show available backups:                           ║');
  print('║     - 2025-12-17 (today)                                        ║');
  print('║     - 2025-12-16 (yesterday) ← YOUR DATA MIGHT BE HERE         ║');
  print('║     - 2025-12-15 ← OR HERE                                     ║');
  print('║     - 2025-12-14                                                ║');
  print('║     - etc.                                                      ║');
  print('║                                                                  ║');
  print('║  6. Select the backup date you want to restore                  ║');
  print('║                                                                  ║');
  print('║  7. Click "Restore from Backup"                                 ║');
  print('║                                                                  ║');
  print('║  ⚠️  WARNING: Restoring will replace your current data!         ║');
  print('║                                                                  ║');
  print('╠══════════════════════════════════════════════════════════════════╣');
  print('║  BACKUP RETENTION POLICY:                                       ║');
  print('║  • Today: All backups with timestamps                           ║');
  print('║  • Past 7 days: One backup per day                              ║');
  print('║  • Past 12 months: One backup per month                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  
  // Check if we're on Windows and can check local Hive data
  if (Platform.isWindows) {
    final appDataPath = Platform.environment['APPDATA'];
    if (appDataPath != null) {
      final hivePath = '$appDataPath\\..\\Local\\twelve_step_app';
      print('Local Hive data location: $hivePath');
      
      final dir = Directory(hivePath);
      if (dir.existsSync()) {
        print('✓ Local data directory exists');
        final files = dir.listSync().whereType<File>().toList();
        print('  Files found: ${files.length}');
        for (final file in files) {
          final stat = file.statSync();
          print('  - ${file.path.split('\\').last} (modified: ${stat.modified})');
        }
      } else {
        print('✗ Local data directory not found');
      }
    }
  }
}
