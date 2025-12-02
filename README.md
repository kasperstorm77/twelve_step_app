# Twelve Steps App - AA Recovery Tools

A comprehensive Flutter application for AA recovery work with six integrated apps: 4th Step Inventory, 8th Step Amends, Morning Ritual, Evening Ritual, Gratitude Journal, and Agnosticism Papers.

**Repository**: [https://github.com/kasperstorm77/twelve_step_app](https://github.com/kasperstorm77/twelve_step_app)

![Main Screen](img/mainScreen.png)
![Settings](img/settings.png)
![Feature](img/feature.png)

## Overview

This app provides integrated recovery tools for AA members with seamless switching between six specialized apps:

### 1. **4th Step Inventory**
Manage resentments and character defects following the AA 4th step process.

**Features:**
- **Resentment**: Who or what you're resentful towards
- **I Am**: Your role/perspective (e.g., "the son", "the banker") - contextualizes resentments
- **Reason (Cause)**: Why you're resentful from that role's perspective
- **Affects my**: Which part of self was affected
- **My Take**: Your part in the situation (self-analysis)
- **Shortcomings**: Character defects revealed

**Key Concept: "I Am" Definitions** - View the same resentment from different perspectives:
- Example 1: "Mom" as **the son** → affects self-reliance
- Example 2: "Mom" as **the banker** → affects economic safety

### 2. **8th Step Amends**
List and manage people to whom amends need to be made.

**Features:**
- Three-column Kanban board: To Do → In Progress → Done
- Track amends status and progress
- Notes and details for each person
- Drag-and-drop organization

### 3. **Morning Ritual**
Daily morning practice for structured recovery routine.

**Features:**
- Customizable ritual items (prayers, readings, meditations)
- Daily completion tracking with timestamps
- Three item types: Prayer, Reading, Meditation
- History view to track consistency
- Visual progress indicators

### 4. **Evening Ritual**
Daily evening reflection for ongoing recovery work.

**Features:**
- Structured nightly review questions
- Character defect identification
- Gratitude logging
- Track patterns over time

### 5. **Gratitude Journal**
Daily gratitude practice and tracking.

**Features:**
- Quick gratitude entries
- Daily prompts
- Historical review
- Positive mindset reinforcement

### 6. **Agnosticism Papers**
Work through barriers to belief and develop new conception (Step 2).

**Features:**
- List barriers to belief paired with new powers/conceptions
- Track spiritual growth through barrier/power pairs
- Archive completed work
- Build personal spiritual understanding

## App Switching

**Seamless Navigation** between all 6 apps:
- Grid icon in AppBar opens app switcher
- Single click to switch between tools
- All apps share common infrastructure
- One Google Drive sync for all data

## Architecture

### Modular Multi-App System

The app uses **Flutter Modular** architecture with six independent apps sharing common infrastructure:

```
AppRouter (Global Switching)
├── 4th Step Inventory App
├── 8th Step Amends App
├── Morning Ritual App
├── Evening Ritual App
├── Gratitude App
└── Agnosticism App
```

**Each App Has:**
- Independent data models (Hive typeIds 0-13)
- Separate local storage boxes
- Own UI screens and navigation
- Dedicated CRUD services

**Shared Infrastructure:**
- `AllAppsDriveService`: Syncs ALL 6 apps to single Google Drive JSON
- `AppRouter`: Global app switching
- `LocaleProvider`: English/Danish localization
- `AppSwitcherService`: Remembers selected app
- Common UI patterns (help, settings, language toggle)

### UI Structure

```
Each App's Home Page
├── AppBar
│   ├── App Title
│   ├── Grid Icon → App Switcher Dialog (6 apps)
│   ├── Help Icon → Context-sensitive help
│   ├── Settings Icon → Data Management
│   └── Language Selector → English/Danish
│
└── TabBarView (app-specific tabs)
    ├── Form/Entry Tab
    ├── List/View Tab
    └── Settings/Management Tab
```

**Unified Data Management** (accessed via gear icon in any app):
- Google Sign In/Out (mobile and desktop)
- Sync toggle (enable/disable Google Drive sync)
- Export to JSON (ALL 6 apps in one file)
- Import from JSON (with data loss warning)
- Fetch from Google Drive
- Upload to Google Drive (manual)
- Clear all entries

### Data Models

**Core Models (with Hive typeIds):**

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

All models include:
- Hive annotations for local storage
- JSON serialization (toJson/fromJson)
- Field accessors and convenience methods

### CRUD Operations

All CRUD operations are handled by app-specific services:
- `InventoryService` - 4th step entries and I Am definitions
- `PersonService` - 8th step people
- `MorningRitualService` - Morning ritual items and entries
- `ReflectionService` - Evening ritual reflections
- `GratitudeService` - Gratitude entries
- `AgnosticismService` - Agnosticism barrier/power pairs

**Example (4th Step):**
```dart
// Create
await _inventoryService.addEntry(box, entry);

// Read
final entries = box.values.toList();

// Update
await _inventoryService.updateEntry(box, index, updatedEntry);

// Delete
await _inventoryService.deleteEntry(box, index);
```

**All CRUD operations automatically trigger Google Drive sync if enabled.**

### Google Drive Sync

**Centralized Architecture:**
- `AllAppsDriveService`: Syncs ALL 6 apps to single Google Drive JSON file
- Platform-specific auth:
  - Mobile (Android/iOS): `MobileGoogleAuthService` with `google_sign_in`
  - Desktop (Windows): `WindowsGoogleAuthService` with loopback HTTP server OAuth
- `GoogleDriveCrudClient`: Pure Drive API operations

**Sync Flow:**
1. User signs in via Google (OAuth - platform-specific)
2. App creates platform-appropriate Drive client
3. Sync toggle enables/disables automatic uploads
4. CRUD operations in ANY app trigger debounced uploads (700ms)
5. Data stored in Drive AppData folder as `aa4step_inventory_data.json`
6. Single JSON file contains all 6 apps' data

**JSON Format v7.0:**
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
  "gratitude": [...],            // Gratitude
  "agnosticism": [...]           // Agnosticism
}
```

**Key Features:**
- Silent sign-in at app startup (all platforms)
- Debounced uploads to coalesce rapid changes
- Background serialization using `compute()` isolates
- Conflict resolution via `lastModified` timestamps
- Auto-sync on app start if remote data is newer
- **Data Safety**: All 6 apps sync atomically in one transaction
- **Platform Support**: Android, iOS, Windows (full sync)

### JSON Import/Export

**Export:**
```dart
await _exportJson();
// Creates JSON v7.0 with ALL 6 apps:
// - Version number (7.0)
// - Export timestamp + lastModified
// - All data from all 6 apps in one file
// Filename: twelve_steps_export_<timestamp>.json
```

**Import:**
```dart
await _importJson();
// Shows WARNING dialog (all app data will be replaced)
// Imports all 6 apps' data from single JSON file
// Preserves relationships (e.g., iAmId links)
// Backward compatible with older format versions
```

**Data Safety Features:**
- ✅ Cannot delete I Am if used by entries (4th step)
- ✅ Warning dialog before import (data replacement)
- ✅ All definitions imported before entries (preserves relationships)
- ✅ Backward compatible with old JSON formats
- ✅ NULL safety for missing references
- ✅ Atomic import - all apps or none

See `docs/MODULAR_ARCHITECTURE.md` for complete multi-app system details.

### Localization

Supports **English (en)** and **Danish (da)** across all 6 apps:

```dart
t(context, 'key') // Translation helper function
```

**Centralized Translations** in `lib/shared/localizations.dart`:
- All 6 apps share common localization infrastructure
- App-specific keys prefixed by app name
- Common UI strings shared across apps

**Key translation categories:**
- Common: `cancel`, `delete`, `save`, `yes`, `no`, `settings`, `help`
- App titles and navigation
- Form field labels and validation messages
- Data management operations
- Help content for each app

**Language toggle:** Globe icon in AppBar switches locale, persisted across sessions.

## Development

### Setup
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Run
```bash
flutter run -d <device>
```

### Build
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle
flutter build appbundle --release

# Windows Release + ZIP (PowerShell)
.\scripts\build_windows_release.ps1
```

### Version Increment
```bash
dart scripts/increment_version.dart
```

### Code Quality
```bash
flutter analyze
```

## Key Files

### Multi-App System
- `lib/main.dart`: App initialization, Hive setup, silent sign-in, auto-sync
- `lib/app/app_module.dart`: Flutter Modular DI and routing
- `lib/shared/pages/app_router.dart`: Global app switching logic
- `lib/shared/services/app_switcher_service.dart`: App selection persistence
- `lib/shared/services/app_help_service.dart`: Context-sensitive help system

### 4th Step Inventory
- `lib/fourth_step/pages/fourth_step_home.dart`: Main container with tabs
- `lib/fourth_step/pages/form_tab.dart`: Entry form with I Am selector
- `lib/fourth_step/pages/list_tab.dart`: Table/card view with I Am display
- `lib/fourth_step/pages/settings_tab.dart`: I Am definitions management
- `lib/fourth_step/models/inventory_entry.dart`: Entry data model
- `lib/fourth_step/models/i_am_definition.dart`: I Am data model
- `lib/fourth_step/services/inventory_service.dart`: Entry CRUD
- `lib/fourth_step/services/i_am_service.dart`: I Am CRUD

### 8th Step Amends
- `lib/eighth_step/pages/eighth_step_home.dart`: Kanban board UI
- `lib/eighth_step/models/person.dart`: Person data model
- `lib/eighth_step/services/person_service.dart`: Person CRUD

### Morning Ritual
- `lib/morning_ritual/pages/morning_ritual_home.dart`: Main container
- `lib/morning_ritual/models/ritual_item.dart`: Ritual item definition
- `lib/morning_ritual/models/morning_ritual_entry.dart`: Daily completion
- `lib/morning_ritual/services/morning_ritual_service.dart`: CRUD operations

### Evening Ritual
- `lib/evening_ritual/pages/evening_ritual_home.dart`: Main container
- `lib/evening_ritual/models/reflection_entry.dart`: Reflection data model
- `lib/evening_ritual/services/reflection_service.dart`: Reflection CRUD

### Gratitude
- `lib/gratitude/pages/gratitude_home.dart`: Main container
- `lib/gratitude/models/gratitude_entry.dart`: Gratitude data model
- `lib/gratitude/services/gratitude_service.dart`: Gratitude CRUD

### Agnosticism
- `lib/agnosticism/pages/agnosticism_home.dart`: Main container
- `lib/agnosticism/models/barrier_power_pair.dart`: Barrier/power pair model
- `lib/agnosticism/services/agnosticism_service.dart`: Pair CRUD

### Shared Infrastructure
- `lib/shared/services/all_apps_drive_service_impl.dart`: Centralized Drive sync
- `lib/shared/services/google_drive/`: Platform-specific Drive auth
- `lib/shared/pages/data_management_tab.dart`: Platform selector
- `lib/shared/pages/data_management_tab_mobile.dart`: Android/iOS data management
- `lib/shared/pages/data_management_tab_windows.dart`: Windows data management
- `lib/shared/localizations.dart`: Translation system (EN/DA)
- `lib/shared/models/app_entry.dart`: Multi-app system definition

## Documentation

See the `docs/` folder for detailed documentation:
- `MODULAR_ARCHITECTURE.md`: Complete multi-app system architecture and data flow
- `BUILD_SCRIPTS.md`: Build automation and version management
- `GOOGLE_OAUTH_SETUP.md`: Google OAuth configuration (mobile and desktop loopback)
- `VS_CODE_DEBUG.md`: VS Code debugging setup
- `PLAY_STORE_DESCRIPTIONS.md`: App store listing content
- `IOS_RELEASE.md`: iOS build and release process
- `LOCAL_SETUP.md`: Git clone setup instructions (not tracked - contains credentials)
- `BACKUP_RESTORE_POINTS.md`: Google Drive backup/restore system

See also:
- `PRIVACY_POLICY.md`: Privacy policy for app stores (root directory)
- `.github/copilot-instructions.md`: AI agent development instructions

## Dependencies

**Core:**
- **flutter_modular**: Routing and dependency injection
- **hive/hive_flutter**: Local NoSQL database
- **flutter_localizations**: Internationalization support

**Google Drive Sync:**
- **google_sign_in**: Google authentication (Android, iOS)
- **googleapis**: Drive API v3
- **googleapis_auth**: OAuth2 authentication
- **http**: HTTP client for API calls

**UI & Utils:**
- **google_fonts**: Typography
- **uuid**: UUID generation for data models
- **file_picker**: File selection dialogs
- **flutter_file_dialog**: Save file dialogs
- **package_info_plus**: App version information
- **url_launcher**: Open URLs
- **table_calendar**: Calendar widgets (Evening Ritual)
- **phosphor_flutter**: Icon set
- **flutter_bloc**: State management
- **intl**: Internationalization support

**Development:**
- **hive_generator**: Hive adapter code generation
- **build_runner**: Code generation runner
- **flutter_lints**: Lint rules

## Platform Support

- ✅ **Android** - Full support with Google Drive sync
- ✅ **iOS** - Full support with Google Drive sync
- ✅ **Windows** - Full support with loopback OAuth Drive sync
- ⚠️ **macOS/Linux** - Possible but not tested
- ❌ **Web** - Not supported
