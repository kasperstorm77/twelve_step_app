# Twelve Step App - AI Agent Instructions

## Project Overview

Multi-app Flutter system for AA recovery tools (**6 apps**: 4th Step Inventory, 8th Step Amends, Morning Ritual, Evening Ritual, Gratitude, Agnosticism) with shared infrastructure. Uses Hive for local storage, Google Drive for cloud sync, and Flutter Modular for DI/routing.

## Core Development Principle

**ALWAYS choose the best solution over the easy solution.** When implementing features:
- ✅ Choose the most robust, maintainable, and native approach
- ✅ Consider long-term maintenance and scalability
- ✅ Implement industry-standard patterns even if they require more setup
- ❌ Don't take shortcuts just because they're faster to implement
- ❌ Don't use "quick and dirty" solutions that compromise quality

Examples:
- Use loopback HTTP server for desktop OAuth (Google-required method)
- Use proper platform-specific implementations (not shared hacks)
- Implement complete error handling (not minimal try-catch)
- Write maintainable code (not clever one-liners)

## Architecture Pattern

**Modular Structure**: Each app lives in its own folder (`lib/fourth_step/`, `lib/eighth_step/`, `lib/morning_ritual/`, `lib/evening_ritual/`, `lib/gratitude/`, `lib/agnosticism/`) with app-specific models, services, and pages. Shared code in `lib/shared/`.

**App Switching**: `AppSwitcherService` stores selected app ID in Hive `settings` box. `AppRouter` (in `lib/shared/pages/app_router.dart`) switches between apps based on selected ID. Each app has grid icon in AppBar to show app switcher dialog.

**Data Isolation**: Each app has separate Hive boxes:
- 4th Step: `entries` (Box<InventoryEntry>), `i_am_definitions` (Box<IAmDefinition>)
- 8th Step: `people_box` (Box<Person>)
- Morning Ritual: `morning_ritual_items` (Box<RitualItem>), `morning_ritual_entries` (Box<MorningRitualEntry>)
- Evening Ritual: `reflections_box` (Box<ReflectionEntry>)
- Gratitude: `gratitude_box` (Box<GratitudeEntry>)
- Agnosticism: `agnosticism_pairs` (Box<BarrierPowerPair>)

**Hive Type IDs** (NEVER reuse - 0-13 assigned):
| typeId | Model | App |
|--------|-------|-----|
| 0 | InventoryEntry | 4th Step |
| 1 | IAmDefinition | 4th Step |
| 2 | AppEntry | Shared |
| 3 | Person | 8th Step |
| 4 | ColumnType | 8th Step |
| 5 | ReflectionEntry | Evening Ritual |
| 6 | ReflectionType | Evening Ritual |
| 7 | GratitudeEntry | Gratitude |
| 8 | BarrierPowerPair | Agnosticism |
| 9 | RitualItemType | Morning Ritual |
| 10 | RitualItem | Morning Ritual |
| 11 | RitualItemStatus | Morning Ritual |
| 12 | RitualItemRecord | Morning Ritual |
| 13 | MorningRitualEntry | Morning Ritual |

## Critical Developer Workflows

### Build & Version Management
```bash
# Auto-increment version (1.0.1+36 → 1.0.1+37)
dart scripts/increment_version.dart

# VS Code Tasks (Ctrl+Shift+P → "Tasks: Run Task"):
# - "increment-version" - Just increment version
# - "flutter-debug-with-version-increment" - Debug build with version bump
# - "build-windows-release-zip" - Build Windows release + create ZIP distribution
```

### Platform Builds
```bash
# Android APK (release)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Windows Release + ZIP (recommended - PowerShell)
.\scripts\build_windows_release.ps1
# Output: build/releases/twelvestepsapp-windows-{version}.zip

# Windows Debug
flutter run -d windows
```

### Code Generation (After Model Changes)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Debugging
- VS Code launch configs in `.vscode/launch.json` support mobile/desktop
- See `docs/VS_CODE_DEBUG.md` for platform-specific setup

## Data Safety Rules

1. **I Am Deletion Protection**: Check usage in entries before deleting (see `lib/fourth_step/pages/settings_tab.dart`). Show count of affected entries if in use.

2. **Import Order**: ALWAYS import I Am definitions BEFORE entries to prevent orphaned references. Export follows same order.

3. **Drive Sync Timestamps**: Use `lastModified` field for conflict detection. Compare remote vs local timestamp before syncing.

4. **Null Safety**: All I Am references are nullable. Show `-` in UI when I Am not found (never crash).

5. **Data Replacement Warning**: Show warning dialog before JSON import or Drive fetch (ALL local data will be replaced).

## Google Drive Sync Architecture

**Centralized Design**:
- **All Apps Service**: `AllAppsDriveService` (in `lib/shared/services/all_apps_drive_service_impl.dart`) syncs ALL 6 apps to single Google Drive JSON file
- **Platform Selection**: Automatically uses `MobileDriveService` or `WindowsDriveServiceWrapper` based on platform
- **Auth Layer**: 
  - Mobile: `MobileGoogleAuthService` via `google_sign_in` package
  - Desktop: `WindowsGoogleAuthService` via loopback HTTP server OAuth
- **CRUD Layer**: `GoogleDriveCrudClient` (pure Drive API operations)

**Platform-Specific Data Management Tab**:
- `data_management_tab.dart` - Platform selector wrapper
- `data_management_tab_mobile.dart` - Android/iOS implementation
- `data_management_tab_windows.dart` - Windows implementation

**JSON Format v7.0**: Single file contains all app data:
```json
{
  "version": "7.0",
  "exportDate": "2025-12-02T...",
  "lastModified": "2025-12-02T...",
  "iAmDefinitions": [...],       // 4th step I Am (imported FIRST)
  "entries": [...],              // 4th step inventory
  "people": [...],               // 8th step
  "morningRitualItems": [...],   // Morning ritual definitions
  "morningRitualEntries": [...], // Morning ritual daily completions
  "reflections": [...],          // Evening ritual
  "gratitude": [...],            // Gratitude (also accepts 'gratitudeEntries')
  "agnosticism": [...]           // Agnosticism (also accepts 'agnosticismPapers')
}
```

**Auto-Sync on App Start** (in `main.dart`):
1. Initialize `AllAppsDriveService`
2. Attempt silent sign-in (cached credentials)
3. If authenticated, check if remote data is newer
4. Auto-sync if remote is newer

**Debounced Upload**: Schedule uploads with 700ms debounce to coalesce rapid changes. See `scheduleUploadFromBox()` in `AllAppsDriveService`.

## Localization System

**Translation Function**: `t(context, 'key')` defined in `lib/shared/localizations.dart`. Returns translated string for current locale (en/da).

**Adding New Translations**: Add to BOTH `'en'` and `'da'` maps in `localizations.dart`. Keys must match exactly.

**Locale Management**: `LocaleProvider` (ChangeNotifier) injected via Flutter Modular. Change locale with `localeProvider.changeLocale(Locale('da'))`.

**Language Selector**: PopupMenuButton in AppBar actions.

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

**Routing**: Single route (`/`) points to `AppHomePage` which renders `AppRouter`. `AppRouter` switches between the 6 app home pages based on `AppSwitcherService.getSelectedAppId()`.

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
Use app-specific service classes (`InventoryService`, `PersonService`, `MorningRitualService`, `ReflectionService`, `GratitudeService`, `AgnosticismService`). These automatically trigger Drive sync when enabled:
```dart
await inventoryService.addEntry(box, entry); // Auto-syncs via AllAppsDriveService
await inventoryService.updateEntry(box, index, entry); // Auto-syncs
await inventoryService.deleteEntry(box, index); // Auto-syncs
```

### ValueListenableBuilder for Reactive UI
When UI needs to react to multiple Hive boxes, use nested ValueListenableBuilders:
```dart
ValueListenableBuilder(
  valueListenable: entriesBox.listenable(),
  builder: (context, entriesBox, _) {
    return ValueListenableBuilder(
      valueListenable: iAmBox.listenable(),
      builder: (context, iAmBox, _) {
        // UI rebuilds when either box changes
      },
    );
  },
);
```

### App Switching
```dart
// Get current app ID
final currentAppId = AppSwitcherService.getSelectedAppId();

// Switch to different app
await AppSwitcherService.setSelectedAppId(AvailableApps.gratitude);
widget.onAppSwitched?.call(); // Trigger AppRouter rebuild
```

## Platform-Specific Code

**Platform Support**: Android, iOS, Windows. (macOS/Linux possible but not tested. Web NOT supported.)

**Platform Detection**: Use `PlatformHelper` (in `lib/shared/utils/platform_helper.dart`):
- `PlatformHelper.isMobile` - Android or iOS
- `PlatformHelper.isDesktop` - Windows, macOS, or Linux
- `PlatformHelper.isWindows` - Windows specifically
- `PlatformHelper.isAndroid`, `isIOS`, `isMacOS`, `isLinux` - Specific platforms

**Google Drive Sync by Platform**:
- **Mobile (Android/iOS)**: `google_sign_in` package with native account picker UI
- **Windows**: Loopback HTTP server OAuth (`http://127.0.0.1:PORT`) - browser opens, user signs in, redirects back to local server
- **Desktop OAuth Note**: Google deprecated custom URI schemes for desktop apps. MUST use loopback IP method.

**Platform-Specific Imports**:
```dart
import 'dart:io' show Platform;
import 'package:google_sign_in/google_sign_in.dart'; // Mobile only
```

## Key Files Reference

- **App Entry**: `lib/main.dart` (Hive init, silent sign-in, auto-sync for all platforms)
- **Routing**: `lib/app/app_module.dart`, `lib/app/app_widget.dart`, `lib/shared/pages/app_router.dart`
- **Drive Sync**: `lib/shared/services/all_apps_drive_service_impl.dart` (syncs all 6 apps)
- **Windows OAuth**: `lib/shared/services/google_drive/windows_google_auth_service.dart` (loopback method)
- **Mobile OAuth**: `lib/shared/services/google_drive/mobile_google_auth_service.dart`
- **Data Management**: 
  - `lib/shared/pages/data_management_tab.dart` (platform selector)
  - `lib/shared/pages/data_management_tab_mobile.dart` (Android/iOS)
  - `lib/shared/pages/data_management_tab_windows.dart` (Windows)
- **App Switching**: `lib/shared/services/app_switcher_service.dart`
- **App Definitions**: `lib/shared/models/app_entry.dart` (AvailableApps class)
- **Translations**: `lib/shared/localizations.dart` (all apps, EN/DA)
- **Build Scripts**: `scripts/increment_version.dart`, `scripts/build_windows_release.ps1`

**App Home Pages**:
- 4th Step: `lib/fourth_step/pages/fourth_step_home.dart`
- 8th Step: `lib/eighth_step/pages/eighth_step_home.dart`
- Morning Ritual: `lib/morning_ritual/pages/morning_ritual_home.dart`
- Evening Ritual: `lib/evening_ritual/pages/evening_ritual_home.dart`
- Gratitude: `lib/gratitude/pages/gratitude_home.dart`
- Agnosticism: `lib/agnosticism/pages/agnosticism_home.dart`

## Documentation

Essential docs in `docs/`:
- `MODULAR_ARCHITECTURE.md` - Complete 6-app architecture and data flow
- `BUILD_SCRIPTS.md` - Version management and build automation
- `GOOGLE_OAUTH_SETUP.md` - OAuth setup for mobile and desktop (loopback method)
- `VS_CODE_DEBUG.md` - VS Code debugging configuration
- `PLAY_STORE_DESCRIPTIONS.md` - App store listings
- `IOS_RELEASE.md` - iOS build and release process
- `LOCAL_SETUP.md` - Git clone setup instructions (not tracked)
- `BACKUP_RESTORE_POINTS.md` - Google Drive backup/restore system

## Testing Considerations

Before making changes that affect data:
1. Export current data to JSON (backup)
2. Test on new installation first
3. Verify I Am references preserved
4. Check Drive sync conflict detection
5. Confirm backward compatibility with old JSON format

## Common Pitfalls

❌ **Don't**: Reuse Hive type IDs (0-13 are assigned)
❌ **Don't**: Delete I Am without checking usage  
❌ **Don't**: Import entries before I Am definitions  
❌ **Don't**: Skip timestamp comparison in Drive sync  
❌ **Don't**: Use custom URI schemes for desktop OAuth (Google deprecated them)
❌ **Don't**: Forget to add translations to BOTH en and da maps
❌ **Don't**: Forget `mounted` checks before using context after async operations
✅ **Do**: Use loopback HTTP server for desktop OAuth (`http://127.0.0.1:PORT`)
✅ **Do**: Use debounced uploads for performance (700ms)
✅ **Do**: Show warnings before data replacement  
✅ **Do**: Handle null I Am references gracefully  
✅ **Do**: Include lastModified in all sync JSON (v7.0 format)
✅ **Do**: Use nested ValueListenableBuilder when UI depends on multiple boxes
✅ **Do**: Pass `onAppSwitched` callback to all app home pages
