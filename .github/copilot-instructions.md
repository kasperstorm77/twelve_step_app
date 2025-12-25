# Twelve Step App - AI Agent Instructions

## Project Overview

Multi-app Flutter system for AA recovery tools (**7 apps**: 4th Step Inventory, 8th Step Amends, Morning Ritual, Evening Ritual, Gratitude, Agnosticism, Notifications) with shared infrastructure. Uses Hive for local storage, Google Drive for cloud sync, and Flutter Modular for DI/routing.

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
- Notifications: `notifications_box` (Box<AppNotification>)

**Hive Type IDs** (NEVER reuse - 0-16 assigned):
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
| 14 | InventoryCategory | 4th Step |
| 15 | NotificationScheduleType | Notifications |
| 16 | AppNotification | Notifications |

## Critical Developer Workflows

### Build & Version Management
```bash
# Manually increment version when needed (1.0.1+36 → 1.0.1+37)
dart scripts/increment_version.dart

# VS Code Tasks (Ctrl+Shift+P → "Tasks: Run Task"):
# - "increment-version" - Just increment version
# - "build-windows-release-zip" - Build Windows release + create ZIP distribution
```

### Platform Builds
```bash
# Android App Bundle for Play Store (release)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# Android APK (release) - for direct installation
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Windows Release + ZIP (recommended - PowerShell)
.\scripts\build_windows_release.ps1
# Output: build/releases/twelvestepsapp-windows-{version}.zip

# Windows Debug
flutter run -d windows

# Android Debug (on connected device)
flutter run -d <device_id>
```

### Code Generation (After Model Changes)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Debugging
- VS Code launch configs in `.vscode/launch.json` support mobile/desktop
- See `docs/VS_CODE_DEBUG.md` for platform-specific setup

**Note:** Do NOT auto-increment version on every build. Only increment version manually before release builds.

## Data Safety Rules

1. **I Am Deletion Protection**: Check usage in entries before deleting (see `lib/fourth_step/pages/settings_tab.dart`). Show count of affected entries if in use.

2. **Import Order**: ALWAYS import I Am definitions BEFORE entries to prevent orphaned references. Export follows same order.

3. **Drive Sync Timestamps**: Use `lastModified` field for conflict detection. Compare remote vs local timestamp before syncing.

4. **Null Safety**: All I Am references are nullable. Show `-` in UI when I Am not found (never crash).

5. **Data Replacement Warning**: Show warning dialog before JSON import or Drive fetch (ALL local data will be replaced).

## Google Drive Sync Architecture

**Centralized Design**:
- **All Apps Service**: `AllAppsDriveService` (in `lib/shared/services/all_apps_drive_service_impl.dart`) syncs ALL 7 apps to single Google Drive JSON file
- **Platform Selection**: Automatically uses `MobileDriveService` or `WindowsDriveServiceWrapper` based on platform
- **Auth Layer**: 
  - Mobile: `MobileGoogleAuthService` via `google_sign_in` package
  - Desktop: `WindowsGoogleAuthService` via loopback HTTP server OAuth
- **CRUD Layer**: `GoogleDriveCrudClient` (pure Drive API operations)

**Platform-Specific Data Management Tab**:
- `data_management_tab.dart` - Platform selector wrapper
- `data_management_tab_mobile.dart` - Android/iOS implementation
- `data_management_tab_windows.dart` - Windows implementation

**JSON Format v8.0**: Single file contains all app data:
```json
{
  "version": "8.0",
  "exportDate": "2025-12-02T...",
  "lastModified": "2025-12-02T...",
  "iAmDefinitions": [...],       // 4th step I Am (imported FIRST)
  "entries": [...],              // 4th step inventory
  "people": [...],               // 8th step
  "morningRitualItems": [...],   // Morning ritual definitions
  "morningRitualEntries": [...], // Morning ritual daily completions
  "reflections": [...],          // Evening ritual
  "gratitude": [...],            // Gratitude (also accepts 'gratitudeEntries')
  "agnosticism": [...],          // Agnosticism (also accepts 'agnosticismPapers')
  "notifications": [...],        // Notifications (with vibrateEnabled/soundEnabled)
  "appSettings": {               // App settings (v8.0+)
    "morningRitualAutoLoadEnabled": false,
    "morningRitualStartTime": "05:00:00",
    "morningRitualEndTime": "09:00:00"
  }
}
```

**Auto-Sync on App Start** (in `main.dart`):
1. Initialize `AllAppsDriveService`
2. Attempt silent sign-in (cached credentials)
3. If authenticated, check if remote data is newer
4. Auto-sync if remote is newer
5. Check morning ritual auto-load (after sync so restored settings are used)

**First-Time Sign-In (Fresh Install)**:
1. User signs in to Google Drive from Data Management
2. Prompt appears asking to fetch data from Drive (if Drive has data)
3. User can Fetch (restore) or Cancel (start fresh)
4. Sync is enabled after prompt regardless of choice
5. Prompt controlled by `syncPromptedMobile`/`syncPromptedWindows` flags in Hive `settings` box
6. `syncEnabled` defaults to `false` so prompt shows for new installs

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

**Routing**: Single route (`/`) points to `AppHomePage` which renders `AppRouter`. `AppRouter` switches between the 7 app home pages based on `AppSwitcherService.getSelectedAppId()`.

## UI Styling Patterns

### Text Styles
- **Body text / Values**: Use `theme.textTheme.bodyMedium` for all content text
- **Headings in cards**: Use `theme.colorScheme.primary` with `fontWeight: FontWeight.w600` (no text theme size - uses default)
- **Section titles / Page headers**: Use `theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)` - NOT `titleLarge`
- **Empty state text**: Use `theme.textTheme.bodyLarge`

### Card Content Styling
All cards displaying data should follow this pattern for headings and values:

```dart
Widget _buildHeadingValue(BuildContext context, String headingKey, String value, {Color? headingColor}) {
  final theme = Theme.of(context);
  return Padding(
    padding: EdgeInsets.only(top: value.isNotEmpty ? 4 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, headingKey),
          style: TextStyle(
            color: headingColor ?? theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (value.isNotEmpty)
          Text(value, style: theme.textTheme.bodyMedium),
      ],
    ),
  );
}
```

**Heading colors:**
- Default/primary headings: `theme.colorScheme.primary` (blue)
- Error/warning headings: `theme.colorScheme.error` (red) - e.g., barriers in agnosticism
- Always use `fontWeight: FontWeight.w600` for headings
- Always use `theme.textTheme.bodyMedium` for values

### Card Layout
- Use `Card` with `margin: const EdgeInsets.symmetric(vertical: 6)`
- Use `Padding(padding: const EdgeInsets.all(12))` inside cards (not `ListTile`)
- Apply horizontal padding on the parent `ListView`: `padding: const EdgeInsets.symmetric(horizontal: 12)`

### TextField Styling
For filter/search fields and inline text fields:
```dart
TextField(
  controller: controller,
  style: theme.textTheme.bodyMedium,  // Match card content text size
  decoration: InputDecoration(
    hintText: t(context, 'hint_key'),
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.outline,
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    // For compact fields:
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  ),
)
```

For form fields (full-size):
```dart
TextField(
  controller: controller,
  decoration: InputDecoration(
    labelText: t(context, 'label_key'),
    border: const OutlineInputBorder(),
  ),
)
```

### Filter/Toggle Chips
For category or toggle filters (icon-only boxes in a row):
```dart
SizedBox(
  height: 40,
  child: Row(
    children: items.map((item) {
      final isSelected = selectedItems.contains(item);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => toggleSelection(item),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Icon(
                  getIcon(item),
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  ),
)
```

### Button Styling
- Full-width buttons: Wrap in `SizedBox(width: double.infinity, child: ...)`
- Primary actions: `ElevatedButton.icon`
- Secondary actions: `OutlinedButton.icon`
- Cancel/destructive: `TextButton` or `TextButton.icon`

### AlertDialog Styling
Dialog titles should use the same style as section titles:
```dart
AlertDialog(
  title: Text(
    t(context, 'dialog_title'),
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    ),
  ),
  content: ...,
)
```

### Spacing Constants
- Page padding: `EdgeInsets.all(12)` or `EdgeInsets.fromLTRB(12, 8, 12, 0)`
- Between elements: 6-8px vertical
- Card internal padding: `EdgeInsets.all(12)`
- Card margin: `EdgeInsets.symmetric(vertical: 6)`
- Between form fields: `SizedBox(height: 16)`

### Icon Sizes
- In cards/chips: 16-20px
- In buttons: default (24px)
- In filter fields: 20px

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
- **Drive Sync**: `lib/shared/services/all_apps_drive_service_impl.dart` (syncs all 7 apps)
- **Notifications**: `lib/notifications/services/notifications_service.dart` (local notifications scheduling with vibrate/sound options)
- **Morning Ritual Timer**: `lib/morning_ritual/pages/morning_ritual_today_tab.dart` (uses `wakelock_plus` to keep screen on during timer)
- **Windows OAuth**: `lib/shared/services/google_drive/windows_google_auth_service.dart` (loopback method)
- **Mobile OAuth**: `lib/shared/services/google_drive/mobile_google_auth_service.dart`
- **Data Management**: 
  - `lib/shared/pages/data_management_page.dart` (Settings page with tabs: Data Management, General Settings)
  - `lib/shared/pages/data_management_tab.dart` (platform selector)
  - `lib/shared/pages/data_management_tab_mobile.dart` (Android/iOS)
  - `lib/shared/pages/data_management_tab_windows.dart` (Windows)
- **App Switching**: `lib/shared/services/app_switcher_service.dart`
- **App Settings**: `lib/shared/services/app_settings_service.dart` (morning ritual auto-load, etc.)
- **Morning Ritual Auto-Load**: Controlled by `AppSettingsService`. When enabled, forces morning ritual app on first open/resume within configured time window (once per day). Check happens AFTER Drive sync in `main.dart` and on app resume in `app_widget.dart`.
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
- Notifications: `lib/notifications/pages/notifications_home.dart`

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

⛔ **NEVER DELETE THESE FILES** (even if they seem "unused"):
- `my-release-key.jks` - Release signing key. **IF DELETED: Cannot update app on Play Store EVER**
- `debug.keystore` - Debug signing key with registered SHA-1. **IF DELETED: Google Sign-In breaks**

❌ **Don't**: Reuse Hive type IDs (0-16 are assigned)
❌ **Don't**: Delete I Am without checking usage  
❌ **Don't**: Import entries before I Am definitions  
❌ **Don't**: Skip timestamp comparison in Drive sync  
❌ **Don't**: Use custom URI schemes for desktop OAuth (Google deprecated them)
❌ **Don't**: Forget to add translations to BOTH en and da maps
❌ **Don't**: Forget `mounted` checks before using context after async operations
❌ **Don't**: Delete `.jks` or `.keystore` files when "cleaning up" the project root
❌ **Don't**: Forget BroadcastReceivers in AndroidManifest for scheduled notifications
✅ **Do**: Use loopback HTTP server for desktop OAuth (`http://127.0.0.1:PORT`)
✅ **Do**: Use debounced uploads for performance (700ms)
✅ **Do**: Show warnings before data replacement  
✅ **Do**: Handle null I Am references gracefully  
✅ **Do**: Include lastModified in all sync JSON (v7.0 format)
✅ **Do**: Use nested ValueListenableBuilder when UI depends on multiple boxes
✅ **Do**: Pass `onAppSwitched` callback to all app home pages
✅ **Do**: Register `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` in AndroidManifest
✅ **Do**: Use `wakelock_plus` to keep screen on during Morning Ritual timer
✅ **Do**: Include `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` permissions in AndroidManifest for notifications
