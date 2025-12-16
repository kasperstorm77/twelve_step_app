# Modular Architecture - Twelve Step App

## Overview

This document describes the modular architecture supporting **six recovery apps** with shared common components:
1. 4th Step Inventory
2. 8th Step Amends
3. Morning Ritual
4. Evening Ritual
5. Gratitude
6. Agnosticism (Surrender & Correction)

## Directory Structure

```
lib/
├── main.dart                        # App entry point
├── app/                            # App-level configuration (Flutter Modular)
│   ├── app_module.dart             # Dependency injection
│   └── app_widget.dart             # Root widget
│
├── shared/                         # SHARED COMPONENTS (Common to all apps)
│   ├── models/
│   │   ├── app_entry.dart          # Multi-app system definition (6 apps)
│   │   └── app_entry.g.dart
│   │
│   ├── services/
│   │   ├── all_apps_drive_service_impl.dart  # Syncs ALL 6 apps to Drive
│   │   ├── app_switcher_service.dart         # App switching logic
│   │   ├── app_help_service.dart             # Context-sensitive help
│   │   ├── locale_provider.dart              # Language management
│   │   ├── app_version_service.dart          # Version tracking
│   │   └── google_drive/                     # Drive sync infrastructure
│   │       ├── desktop_drive_auth.dart
│   │       ├── desktop_drive_client.dart
│   │       ├── desktop_oauth_config.dart
│   │       ├── drive_config.dart
│   │       ├── drive_crud_client.dart
│   │       ├── enhanced_google_drive_service.dart
│   │       ├── mobile_drive_service.dart
│   │       ├── mobile_google_auth_service.dart
│   │       └── windows_drive_service_wrapper.dart
│   │
│   ├── pages/
│   │   ├── app_router.dart              # Global routing (switches between apps)
│   │   ├── data_management_tab.dart     # Platform selector
│   │   ├── data_management_tab_mobile.dart  # Android/iOS implementation
│   │   └── data_management_tab_windows.dart # Windows implementation
│   │
│   ├── utils/
│   │   ├── platform_helper.dart         # Platform detection
│   │   └── sync_utils.dart
│   │
│   └── localizations.dart               # All localization strings (EN/DA)
│
├── fourth_step/                    # 4TH STEP INVENTORY APP
│   ├── models/
│   │   ├── inventory_entry.dart         # Resentment/inventory data
│   │   ├── inventory_entry.g.dart
│   │   ├── i_am_definition.dart         # Identity definitions
│   │   └── i_am_definition.g.dart
│   ├── services/
│   │   ├── inventory_service.dart       # CRUD for inventory
│   │   └── i_am_service.dart            # CRUD for I Am definitions
│   └── pages/
│       ├── fourth_step_home.dart        # Main container
│       ├── form_tab.dart                # Entry form
│       ├── list_tab.dart                # Inventory list
│       └── settings_tab.dart            # I Am definitions management
│
├── eighth_step/                    # 8TH STEP AMENDS APP
│   ├── models/
│   │   ├── person.dart                  # Person/amends data
│   │   └── person.g.dart
│   ├── services/
│   │   └── person_service.dart          # CRUD for people
│   └── pages/
│       ├── eighth_step_home.dart        # Main container (single view with 3 columns)
│       └── eighth_step_settings_tab.dart    # Person edit dialog
│
├── morning_ritual/                 # MORNING RITUAL APP
│   ├── models/
│   │   ├── ritual_item.dart             # Ritual item definitions
│   │   ├── ritual_item.g.dart
│   │   ├── morning_ritual_entry.dart    # Daily ritual completions
│   │   └── morning_ritual_entry.g.dart
│   ├── services/
│   │   └── morning_ritual_service.dart  # CRUD for ritual data
│   └── pages/
│       ├── morning_ritual_home.dart     # Main container
│       ├── morning_ritual_today_tab.dart    # Today's ritual execution
│       ├── morning_ritual_history_tab.dart  # History list
│       └── morning_ritual_settings_tab.dart # Ritual item definitions
│
├── evening_ritual/                 # EVENING RITUAL APP
│   ├── models/
│   │   ├── reflection_entry.dart        # Daily reflection data
│   │   └── reflection_entry.g.dart
│   ├── services/
│   │   └── reflection_service.dart      # CRUD for reflections
│   └── pages/
│       ├── evening_ritual_home.dart     # Main container
│       ├── evening_ritual_form_tab.dart # Reflection form
│       └── evening_ritual_list_tab.dart # Reflections list
│
├── gratitude/                      # GRATITUDE APP
│   ├── models/
│   │   ├── gratitude_entry.dart         # Gratitude data
│   │   └── gratitude_entry.g.dart
│   ├── services/
│   │   └── gratitude_service.dart       # CRUD for gratitude
│   └── pages/
│       ├── gratitude_home.dart          # Main container
│       ├── gratitude_form_tab.dart      # Gratitude form
│       └── gratitude_list_tab.dart      # Gratitude list
│
└── agnosticism/                    # AGNOSTICISM (SURRENDER & CORRECTION) APP
    ├── models/
    │   ├── barrier_power_pair.dart      # Barrier/Power pairs
    │   └── barrier_power_pair.g.dart
    ├── services/
    │   └── agnosticism_service.dart     # CRUD for pairs
    └── pages/
        ├── agnosticism_home.dart        # Main container
        ├── agnosticism_paper_tab.dart   # Current paper with flip
        └── agnosticism_archive_tab.dart # Archived pairs
```

## Component Responsibilities

### Shared Components (`lib/shared/`)
**Purpose**: Common functionality used by all apps

- **Models**: App switching system (6 apps)
- **Services**: 
  - `AllAppsDriveService`: Syncs all 6 apps to single Drive JSON
  - `AppSwitcherService`: App selection persistence
  - `AppHelpService`: Context-sensitive help for each app
  - `LocaleProvider`: EN/DA language switching
  - Authentication & Drive infrastructure
- **Pages**: 
  - `AppRouter`: Global routing (switches between apps)
  - Data import/export UI (JSON v7.0 format)
- **Utils**: Platform detection, sync utilities
- **Localizations**: All UI strings for all apps (EN/DA)

### App-Specific Components
Each app has its own isolated folder with:
- **Models**: Hive-annotated data classes with unique typeIds
- **Services**: CRUD operations, calls `AllAppsDriveService` for sync
- **Pages**: UI screens (home, tabs, forms, lists)

## Data Isolation

### Hive Type IDs (NEVER reuse!)
```dart
// Shared
AppEntry: typeId 2

// Fourth Step
InventoryEntry: typeId 0
IAmDefinition: typeId 1

// Eighth Step
Person: typeId 3
ColumnType: typeId 4

// Evening Ritual
ReflectionEntry: typeId 5
ReflectionType: typeId 6

// Gratitude
GratitudeEntry: typeId 7

// Agnosticism
BarrierPowerPair: typeId 8

// Morning Ritual
RitualItemType: typeId 9
RitualItem: typeId 10
RitualItemStatus: typeId 11
RitualItemRecord: typeId 12
MorningRitualEntry: typeId 13
```

### Hive Boxes
```dart
// App-specific boxes
Box<InventoryEntry> entries           // 4th step
Box<IAmDefinition> i_am_definitions   // 4th step
Box<Person> people_box                // 8th step
Box<RitualItem> morning_ritual_items  // Morning ritual definitions
Box<MorningRitualEntry> morning_ritual_entries // Morning ritual daily completions
Box<ReflectionEntry> reflections_box  // Evening ritual
Box<GratitudeEntry> gratitude_box     // Gratitude
Box<BarrierPowerPair> agnosticism_pairs // Agnosticism

// Shared box
Box settings  // App preferences, sync settings, selected app
```

## Localization Strategy

### Current Structure (Centralized)
All strings for all 6 apps in `lib/shared/localizations.dart`

**Languages**: English (EN) and Danish (DA)

**Access Function**: `t(context, 'key')` - Returns translated string for current locale

**Locale Management**: `LocaleProvider` (ChangeNotifier) injected via Flutter Modular

**Language Selector**: PopupMenuButton in each app's AppBar

### Key Prefixes by App
- `morning_ritual_*` - Morning Ritual strings
- `evening_ritual_*`, `reflection_*` - Evening Ritual strings
- `gratitude_*` - Gratitude app strings
- `agnosticism_*` - Agnosticism app strings
- `eighth_step_*` - 8th Step Amends strings
- Common strings: `cancel`, `delete`, `save`, `yes`, `no`, etc.

## App Switching Architecture

### How It Works

**`AppSwitcherService`** (`lib/shared/services/app_switcher_service.dart`)
- Stores selected app ID in Hive `settings` box
- Static methods for getting/setting current app
- Persists selection across app restarts

**`AppRouter`** (`lib/shared/pages/app_router.dart`)
- Global routing widget at the root level
- Switches between app home pages based on selected ID
- Uses `ValueKey` to force rebuild when app changes
- Passes `onAppSwitched` callback to child apps

**App Home Pages**
- Each app's home page has a grid icon button in AppBar
- Shows dialog with all 6 apps listed
- Highlights currently selected app
- Calls `AppSwitcherService.setSelectedAppId()` on selection
- Triggers `onAppSwitched()` callback to rebuild `AppRouter`

### App Order in Switcher
1. Agnosticism (Surrender & Correction)
2. 4th Step Inventory
3. 8th Step Amends
4. Morning Ritual
5. Evening Ritual
6. Gratitude

### Adding New Apps
1. Add app ID constant to `AvailableApps` in `app_entry.dart`
2. Add `AppEntry` to `AvailableApps.getAll()` list
3. Add case to `AppRouter.build()` switch statement
4. Create app folder with models, services, pages
5. Register new Hive type IDs (must be unique, 14+ available)
6. Update `AllAppsDriveService` to sync new app data

## Google Drive Sync Strategy

### Current Architecture (Centralized - All Apps)

**`AllAppsDriveService`** (`lib/shared/services/all_apps_drive_service_impl.dart`)
- Syncs **all 6 apps** to a single Google Drive JSON file
- JSON format version 7.0
- Uses `MobileDriveService` or `WindowsDriveServiceWrapper` based on platform
- Debounced uploads (700ms) to coalesce rapid changes
- Conflict detection via `lastModified` timestamps
- Auto-syncs on app start if remote data is newer

**JSON Structure (v7.0):**
```json
{
  "version": "7.0",
  "exportDate": "2025-12-02T...",
  "lastModified": "2025-12-02T...",
  "entries": [...],              // 4th step inventory
  "iAmDefinitions": [...],       // 4th step I Am
  "people": [...],               // 8th step
  "morningRitualItems": [...],   // Morning ritual definitions
  "morningRitualEntries": [...], // Morning ritual daily completions
  "reflections": [...],          // Evening ritual
  "gratitude": [...],            // Gratitude
  "agnosticism": [...]           // Agnosticism barrier/power pairs
}
```

**First-Time Sign-In Flow (Fresh Install):**
1. User signs into Google Drive from Data Management
2. Prompt appears: "Fetch data from Google Drive?"
3. User can choose to fetch (restore backup) or skip (start fresh)
4. Sync is automatically enabled after the prompt
5. This prompt only appears once per installation (controlled by `syncPromptedMobile`/`syncPromptedWindows` flags)

**Backward Compatibility:**
- `gratitude` field also accepts `gratitudeEntries` from older exports
- `agnosticism` field also accepts `agnosticismPapers` from older exports
- Existing users with `syncEnabled=true` won't see the fetch prompt (already configured)

**Shared Drive Infrastructure** (`lib/shared/services/google_drive/`):
- **Mobile**: `MobileGoogleAuthService` + `MobileDriveService` (Android/iOS)
- **Desktop**: `WindowsGoogleAuthService` + `WindowsDriveServiceWrapper` (Windows/macOS/Linux)
- **CRUD**: `GoogleDriveCrudClient` (pure Drive API operations)
- **Enhanced**: `EnhancedGoogleDriveService` (debouncing, events)

**Platform-Specific Implementations:**
- Mobile uses `google_sign_in` with platform-specific OAuth clients
- Desktop uses loopback OAuth flow (`http://127.0.0.1:PORT`) with browser auth

## Benefits of Modular Architecture

1. **Clear Separation**: Easy to identify which code belongs to which app
2. **Independent Development**: Apps can evolve independently while sharing infrastructure
3. **Reusable Components**: Shared Drive sync, localization, auth in one place
4. **Easy Testing**: Test apps in isolation
5. **Scalability**: Easy to add new apps (just 6 steps - see App Switching section)
6. **Maintainability**: Changes to one app don't affect others
7. **Code Organization**: Logical grouping by functionality
8. **Single Source of Truth**: One Drive file syncs all apps, no conflicts

## Current Status

✅ **Fully Modular** - 6 apps with clear separation:
- Fourth Step Inventory
- Eighth Step Amends
- Morning Ritual
- Evening Ritual
- Gratitude
- Agnosticism (Surrender & Correction)

✅ **Centralized Infrastructure**:
- Single `AllAppsDriveService` syncs all apps
- Shared `AppRouter` for global routing
- Unified localization in `shared/localizations.dart`
- Common UI patterns (app switcher, help icons, language selector)

✅ **Data Safety**:
- Unique Hive type IDs (0-13 assigned)
- Separate Hive boxes per app
- JSON v7.0 format with backward compatibility
- Conflict detection via timestamps

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│           main.dart                     │
│  (Hive init, silent sign-in)            │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         AppWidget                       │
│  (Material app, locale management)      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         AppModule                       │
│  (Flutter Modular DI, routes)           │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│          AppRouter                      │
│  (Switches between apps)                │
└───┬────┬────┬────┬────┬────┬────────────┘
    │    │    │    │    │    │
    ▼    ▼    ▼    ▼    ▼    ▼
   Agn  4th  8th  Morn Eve  Gra
   ost  Step Step Rit  Rit  tit
   Home Home Home Home Home Home
    │    │    │    │    │    │
    └────┴────┴────┴────┴────┘
              │
    ┌─────────▼────────────┐
    │ AllAppsDriveService  │
    │  (Single JSON sync)  │
    └──────────────────────┘
```
