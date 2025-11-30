# Twelve Step App - AI Agent Instructions

## Project Overview

Multi-app Flutter system for AA recovery tools (5 apps: 4th Step Inventory, 8th Step Amends, Evening Ritual, Gratitude, Agnosticism) with shared infrastructure. Uses Hive for local storage, Google Drive for cloud sync, and Flutter Modular for DI/routing.

## Core Development Principle

**ALWAYS choose the best solution over the easy solution.** When implementing features:
- ✅ Choose the most robust, maintainable, and native approach
- ✅ Consider long-term maintenance and scalability
- ✅ Implement industry-standard patterns even if they require more setup
- ❌ Don't take shortcuts just because they're faster to implement
- ❌ Don't use "quick and dirty" solutions that compromise quality

Examples:
- Use deep links for OAuth (not local HTTP servers)
- Use proper platform-specific implementations (not shared hacks)
- Implement complete error handling (not minimal try-catch)
- Write maintainable code (not clever one-liners)

## Architecture Pattern

**Modular Structure**: Each app lives in its own folder (`lib/fourth_step/`, `lib/eighth_step/`, `lib/evening_ritual/`, `lib/gratitude/`, `lib/agnosticism/`) with app-specific models, services, and pages. Shared code in `lib/shared/`.

**App Switching**: `AppSwitcherService` stores selected app ID in Hive `settings` box. `AppRouter` (in `lib/shared/pages/app_router.dart`) switches between apps based on selected ID. Each app has grid icon in AppBar to show app switcher dialog.

**Data Isolation**: Each app has separate Hive boxes:
- 4th Step: `entries` (Box<InventoryEntry>), `i_am_definitions` (Box<IAmDefinition>)
- 8th Step: `people_box` (Box<Person>)  
- Evening Ritual: `reflections_box` (Box<ReflectionEntry>)
- Gratitude: `gratitude_box` (Box<GratitudeEntry>)
- Agnosticism: `agnosticism_box` (Box<AgnosticismPaper>)

**Hive Type IDs** (NEVER reuse):
- `typeId: 0` - InventoryEntry
- `typeId: 1` - IAmDefinition  
- `typeId: 2` - AppEntry
- `typeId: 3` - Person
- `typeId: 4` - ColumnType
- `typeId: 5` - ReflectionEntry
- `typeId: 6` - ReflectionType
- `typeId: 7` - GratitudeEntry
- `typeId: 8` - AgnosticismPaper
- `typeId: 9` - PaperStatus

## Critical Developer Workflows

### Build & Version Management
```bash
# Auto-increment version (1.0.1+36 → 1.0.1+37)
dart scripts/increment_version.dart

# Build with version increment (VS Code tasks)
# Run task: "flutter-debug-with-version-increment"
# Or manually: dart scripts/increment_version.dart && flutter build apk --debug
```

### Code Generation (After Model Changes)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Debugging
- VS Code launch configs in `.vscode/launch.json` support mobile/desktop
- See `docs/VS_CODE_DEBUG.md` for platform-specific setup

## Data Safety Rules

1. **I Am Deletion Protection**: Check usage in entries before deleting (see `lib/fourth_step/pages/settings_tab.dart`). Show count of affected entries if in use.

2. **Import Order**: ALWAYS import I Am definitions BEFORE entries to prevent orphaned references. Export follows same order.

3. **Drive Sync Timestamps**: Use `lastModified` field for conflict detection. Compare remote vs local timestamp before syncing. See `lib/shared/services/google_drive/enhanced_google_drive_service.dart`.

4. **Null Safety**: All I Am references are nullable. Show `-` in UI when I Am not found (never crash).

5. **Data Replacement Warning**: Show warning dialog before JSON import or Drive fetch (ALL local data will be replaced).

## Google Drive Sync Architecture

**Centralized Design**:
- **All Apps Service**: `AllAppsDriveService` (in `lib/shared/services/all_apps_drive_service.dart`) syncs ALL 5 apps to single Google Drive JSON file
- **Legacy Wrapper**: `LegacyDriveService` provides backward compatibility
- **Auth Layer**: `MobileGoogleAuthService` (mobile), `DesktopDriveAuth` (desktop)
- **CRUD Layer**: `GoogleDriveCrudClient` (pure Drive API operations)

**JSON Format v6.0**: Single file contains all app data:
```json
{
  "version": "6.0",
  "exportDate": "2025-11-22T...",
  "lastModified": "2025-11-22T...",
  "entries": [...],              // 4th step inventory
  "iAmDefinitions": [...],       // 4th step I Am
  "people": [...],               // 8th step
  "reflections": [...],          // Evening ritual
  "gratitudeEntries": [...],     // Gratitude
  "agnosticismPapers": [...]     // Agnosticism
}
```

**Conflict Detection Pattern**:
```dart
// On app start: compare timestamps
final remoteTimestamp = await fetchRemoteTimestamp();
final localTimestamp = await loadLocalTimestamp();
if (remoteTimestamp.isAfter(localTimestamp)) {
  await syncDownFromDrive(); // Remote is newer
}
```

**Debounced Upload**: Schedule uploads with 700ms debounce to coalesce rapid changes. See `scheduleUploadFromBox()` in `AllAppsDriveService`.

**App Services**: Each app's CRUD service calls `AllAppsDriveService.instance.scheduleUploadFromBox()` after data changes.

## Localization System

**Translation Function**: `t(context, 'key')` defined in `lib/shared/localizations.dart`. Returns translated string for current locale (en/da).

**Locale Management**: `LocaleProvider` (ChangeNotifier) injected via Flutter Modular. Change locale with `localeProvider.changeLocale(Locale('da'))`.

**Language Selector**: PopupMenuButton in AppBar actions. Use `LanguageSelectorButton` pattern from `docs/REUSABLE_COMPONENTS.md`.

## Flutter Modular Patterns

**Dependency Injection** (`lib/app/app_module.dart`):
```dart
binds.add(Bind.singleton((i) => LocaleProvider()));
binds.add(Bind.lazySingleton((i) => Box<InventoryEntry>()));
```

**Accessing Services**:
```dart
final provider = Modular.get<LocaleProvider>();
final box = Modular.get<Box<InventoryEntry>>();
```

**Routing**: Single route (`/`) points to `AppHomePage` which renders `AppRouter`. `AppRouter` switches between the 5 app home pages based on `AppSwitcherService.getSelectedAppId()`.

## Common Patterns

### Hive Box Opening (main.dart)
Always wrap in try-catch. On corruption, delete and recreate:
```dart
try {
  await Hive.openBox<InventoryEntry>('entries');
} catch (e) {
  await Hive.deleteBoxFromDisk('entries');
  await Hive.openBox<InventoryEntry>('entries');
}
```

### CRUD Operations
Use app-specific service classes (`InventoryService`, `PersonService`, `ReflectionService`, `GratitudeService`, `AgnosticismService`). These automatically trigger Drive sync when enabled:
```dart
await inventoryService.addEntry(box, entry); // Auto-syncs via AllAppsDriveService
await inventoryService.updateEntry(box, index, entry); // Auto-syncs
await inventoryService.deleteEntry(box, index); // Auto-syncs
```

### App Switching
```dart
// Get current app ID
final currentAppId = AppSwitcherService.getSelectedAppId();

// Switch to different app
await AppSwitcherService.setSelectedAppId(AvailableApps.gratitude);
widget.onAppSwitched?.call(); // Trigger AppRouter rebuild
```

### App Switcher Dialog
See `_showAppSwitcher()` in any home page. Lists all 5 apps from `AvailableApps.getAll()`, highlights current selection.

## Platform-Specific Code

**Platform Support**: The app targets Android, iOS, Windows, macOS, and Linux. Web is NOT supported.

**Platform Detection**: Use `PlatformHelper` (in `lib/shared/utils/platform_helper.dart`):
- `PlatformHelper.isMobile` - Android or iOS
- `PlatformHelper.isDesktop` - Windows, macOS, or Linux
- `PlatformHelper.isAndroid`, `isIOS`, `isWindows`, `isMacOS`, `isLinux` - Specific platforms
- `PlatformHelper.isWeb` - Always false (web not supported)

**Google Drive Sync Platform Support**:
- **Mobile (Android/iOS)**: Full Google Drive sync via `google_sign_in` package
- **Desktop (Windows/macOS/Linux)**: Full sync using desktop OAuth (see `docs/GOOGLE_OAUTH_SETUP.md`)
- **Web**: NOT SUPPORTED - web platform has been removed from the project

**Platform-Specific Imports**:
No conditional imports needed anymore. All imports are straightforward:
```dart
import 'dart:io' show Platform;
import 'package:google_sign_in/google_sign_in.dart';
```

## Key Files Reference

- **App Entry**: `lib/main.dart` (Hive init, silent sign-in, auto-sync)
- **Routing**: `lib/app/app_module.dart`, `lib/app/app_widget.dart`, `lib/shared/pages/app_router.dart`
- **Drive Sync**: `lib/shared/services/all_apps_drive_service.dart` (syncs all 5 apps)
- **App Switching**: `lib/shared/services/app_switcher_service.dart`
- **App Definitions**: `lib/shared/models/app_entry.dart` (AvailableApps class)
- **Help System**: `lib/shared/services/app_help_service.dart`
- **Translations**: `lib/shared/localizations.dart` (all apps, EN/DA)
- **Version Script**: `scripts/increment_version.dart`

**App Home Pages**:
- 4th Step: `lib/fourth_step/pages/fourth_step_home.dart` (ModularInventoryHome)
- 8th Step: `lib/eighth_step/pages/eighth_step_home.dart`
- Evening Ritual: `lib/evening_ritual/pages/evening_ritual_home.dart`
- Gratitude: `lib/gratitude/pages/gratitude_home.dart`
- Agnosticism: `lib/agnosticism/pages/agnosticism_home.dart`

## Documentation

Essential docs in `docs/`:
- `MODULAR_ARCHITECTURE.md` - Complete 5-app architecture and data flow
- `BUILD_SCRIPTS.md` - Version management and build automation
- `GOOGLE_OAUTH_SETUP.md` - OAuth setup for mobile and desktop
- `VS_CODE_DEBUG.md` - VS Code debugging configuration
- `PLAY_STORE_DESCRIPTIONS.md` - App store listings
- `IOS_RELEASE.md` - iOS build and release process
- `LOCAL_SETUP.md` - Git clone setup instructions (not tracked)

## Testing Considerations

Before making changes that affect data:
1. Export current data to JSON (backup)
2. Test on new installation first
3. Verify I Am references preserved
4. Check Drive sync conflict detection
5. Confirm backward compatibility with old JSON format

## Common Pitfalls

❌ **Don't**: Reuse Hive type IDs (0-9 are assigned)
❌ **Don't**: Delete I Am without checking usage  
❌ **Don't**: Import entries before I Am definitions  
❌ **Don't**: Skip timestamp comparison in Drive sync  
❌ **Don't**: Use `flutter test` (no tests yet)
❌ **Don't**: Forget to call `onAppSwitched` callback after app switch
✅ **Do**: Use debounced uploads for performance (700ms)
✅ **Do**: Show warnings before data replacement  
✅ **Do**: Handle null I Am references gracefully  
✅ **Do**: Include lastModified in all sync JSON (v6.0 format)
✅ **Do**: Pass `onAppSwitched` callback to all app home pages
