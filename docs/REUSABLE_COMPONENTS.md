# Reusable Components Design Principles

This document describes the modular, reusable components available in this codebase that can be copied to other Flutter projects.

---

## 📦 Core Reusable Components

### 1. Localization System

**Files:**
- `lib/localizations.dart` - Translation map and function
- `lib/services/locale_provider.dart` - State management for locale switching

**Dependencies:**
- `flutter/material.dart` (built-in)

**How It Works:**
```dart
// 1. Define translations (in localizations.dart)
final Map<String, Map<String, String>> localizedValues = {
  'en': {
    'app_title': 'My App',
    'save': 'Save',
  },
  'da': {
    'app_title': 'Min App',
    'save': 'Gem',
  },
};

// 2. Translation function
String t(BuildContext context, String key) {
  final locale = Localizations.localeOf(context);
  return localizedValues[locale.languageCode]?[key] ??
      localizedValues['en']?[key] ??
      key;
}

// 3. Use in widgets
Text(t(context, 'app_title'))
```

**State Management:**
```dart
// LocaleProvider is a ChangeNotifier
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  
  Locale get locale => _locale;
  
  void changeLocale(Locale locale) {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();
    }
  }
}
```

**Integration:**
```dart
// With flutter_modular:
Modular.bindSingleton((i) => LocaleProvider());

// Access:
final localeProvider = Modular.get<LocaleProvider>();
localeProvider.changeLocale(Locale('da'));
```

**What Makes It Modular:**
- ✅ Zero dependencies on app-specific models
- ✅ Pure Flutter foundation (Material)
- ✅ Simple key-value translation map
- ✅ Easy to extend with new languages

**How to Reuse:**
1. Copy `lib/localizations.dart` and `lib/services/locale_provider.dart`
2. Replace `localizedValues` map with your translations
3. Register `LocaleProvider` in your DI system
4. Use `t(context, 'key')` in widgets

---

### 2. App Switcher System

**Files:**
- `lib/services/app_switcher_service.dart` - Core switching logic
- `lib/models/app_entry.dart` - App metadata model (with Hive adapter)

**Dependencies:**
- `hive_flutter` for persistence
- `flutter/foundation.dart` for debug prints

**How It Works:**
```dart
// 1. Define available apps (in app_entry.dart)
class AvailableApps {
  static const String app1 = 'app_one';
  static const String app2 = 'app_two';

  static List<AppEntry> getAll() {
    return [
      AppEntry(
        id: app1,
        name: 'First App',
        description: 'Description here',
        isActive: true,
      ),
      AppEntry(
        id: app2,
        name: 'Second App',
        description: 'Another description',
        isActive: true,
      ),
    ];
  }
}

// 2. Check current app
final currentAppId = AppSwitcherService.getSelectedAppId();
final currentApp = AppSwitcherService.getSelectedApp();

// 3. Switch app
await AppSwitcherService.setSelectedAppId('app_two');

// 4. Check if specific app is active
if (AppSwitcherService.isAppSelected(AvailableApps.app1)) {
  // Show app1 UI
}
```

**Storage:**
- Uses Hive box named `'settings'`
- Stores under key `'selected_app_id'`
- Persists across app restarts

**What Makes It Modular:**
- ✅ Static service pattern (no constructor injection needed)
- ✅ Simple ID-based app identification
- ✅ Uses generic Hive storage (no custom models required)
- ✅ Extensible `AppEntry` model with Hive adapter

**How to Reuse:**
1. Copy `lib/services/app_switcher_service.dart` and `lib/models/app_entry.dart`
2. Run code generator: `flutter pub run build_runner build`
3. Register Hive adapter in `main.dart`:
   ```dart
   Hive.registerAdapter(AppEntryAdapter());
   ```
4. Update `AvailableApps.getAll()` with your apps
5. Use `AppSwitcherService` methods to switch/check apps

---

### 3. Settings Gear Icon Pattern

**Location:** `lib/pages/modular_inventory_home.dart` (AppBar actions)

**UI Pattern:**
```dart
AppBar(
  title: Text(t(context, 'app_title')),
  actions: [
    // Settings/Data Management Button
    IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DataManagementPage(),
          ),
        );
      },
    ),
    
    // Language Selector
    PopupMenuButton<String>(
      onSelected: (String langCode) {
        final localeProvider = Modular.get<LocaleProvider>();
        localeProvider.changeLocale(Locale(langCode));
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'da', child: Text('Dansk')),
      ],
      icon: const Icon(Icons.language),
    ),
  ],
)
```

**Data Management Page Structure:**
```dart
// Full-screen wrapper page
class DataManagementPage extends StatelessWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'data_management')),
      ),
      body: DataManagementTab(box: yourHiveBox),
    );
  }
}
```

**What Makes It Modular:**
- ✅ Standard Flutter navigation
- ✅ No custom dependencies
- ✅ Separates settings from main UI
- ✅ Follows Material Design patterns

**How to Reuse:**
1. Copy the AppBar actions pattern
2. Create your own `DataManagementPage` wrapper
3. Implement your own settings/management content
4. Add language options to `PopupMenuButton`

---

### 4. Language Selector PopupMenuButton

**Standalone Component:**
```dart
class LanguageSelectorButton extends StatelessWidget {
  final List<LanguageOption> languages;
  final Function(String) onLanguageChanged;

  const LanguageSelectorButton({
    super.key,
    required this.languages,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onLanguageChanged,
      itemBuilder: (context) => languages
          .map((lang) => PopupMenuItem(
                value: lang.code,
                child: Text(lang.name),
              ))
          .toList(),
      icon: const Icon(Icons.language),
    );
  }
}

class LanguageOption {
  final String code;
  final String name;

  const LanguageOption({required this.code, required this.name});
}

// Usage:
LanguageSelectorButton(
  languages: const [
    LanguageOption(code: 'en', name: 'English'),
    LanguageOption(code: 'da', name: 'Dansk'),
  ],
  onLanguageChanged: (code) {
    localeProvider.changeLocale(Locale(code));
  },
)
```

**What Makes It Modular:**
- ✅ Zero external dependencies
- ✅ Configurable language list
- ✅ Callback-based (no tight coupling)
- ✅ Pure presentational component

---

## 🎨 UI Component Library

### App Switcher Dialog

**Location:** `lib/pages/modular_inventory_home.dart` (`_showAppSwitcher` method)

**Reusable Implementation:**
```dart
Future<void> showAppSwitcherDialog(
  BuildContext context, {
  required List<AppEntry> apps,
  required String currentAppId,
  required Future<void> Function(String) onAppSelected,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Select App'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: apps.map((app) {
          final isSelected = app.id == currentAppId;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(app.name),
            subtitle: Text(app.description),
            selected: isSelected,
            onTap: () async {
              if (app.id != currentAppId) {
                await onAppSelected(app.id);
                if (!context.mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to ${app.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    ),
  );
}

// Usage:
await showAppSwitcherDialog(
  context,
  apps: AvailableApps.getAll(),
  currentAppId: AppSwitcherService.getSelectedAppId(),
  onAppSelected: (id) async {
    await AppSwitcherService.setSelectedAppId(id);
    setState(() {}); // Refresh UI
  },
);
```

**What Makes It Modular:**
- ✅ Stateless function
- ✅ All data passed as parameters
- ✅ Callback for app selection
- ✅ Material Design dialog pattern

---

## 🔧 Integration Patterns

### Pattern 1: Modular AppBar with All Features

```dart
AppBar(
  leading: IconButton(
    icon: const Icon(Icons.apps),
    onPressed: () async {
      await showAppSwitcherDialog(
        context,
        apps: AvailableApps.getAll(),
        currentAppId: AppSwitcherService.getSelectedAppId(),
        onAppSelected: (id) async {
          await AppSwitcherService.setSelectedAppId(id);
          setState(() {});
        },
      );
    },
  ),
  title: Text(t(context, 'app_title')),
  actions: [
    IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const YourSettingsPage(),
          ),
        );
      },
    ),
    LanguageSelectorButton(
      languages: const [
        LanguageOption(code: 'en', name: 'English'),
        LanguageOption(code: 'da', name: 'Dansk'),
      ],
      onLanguageChanged: (code) {
        final provider = Modular.get<LocaleProvider>();
        provider.changeLocale(Locale(code));
      },
    ),
  ],
)
```

### Pattern 2: Conditional UI Based on Selected App

```dart
Widget build(BuildContext context) {
  final currentApp = AppSwitcherService.getSelectedApp();
  final isAppOne = AppSwitcherService.isAppSelected(AvailableApps.app1);

  return Scaffold(
    appBar: AppBar(
      title: Text(currentApp.name),
    ),
    body: isAppOne
        ? AppOneContent()
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.construction, size: 64),
                const SizedBox(height: 16),
                Text(currentApp.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(currentApp.description),
                const Text('Coming Soon', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
  );
}
```

---

## 📋 Checklist for Reusing Components

### Localization System
- [ ] Copy `lib/localizations.dart`
- [ ] Copy `lib/services/locale_provider.dart`
- [ ] Replace translation map with your keys
- [ ] Register `LocaleProvider` in DI
- [ ] Wrap app with locale rebuilding logic
- [ ] Use `t(context, 'key')` in widgets

### App Switcher
- [ ] Copy `lib/services/app_switcher_service.dart`
- [ ] Copy `lib/models/app_entry.dart`
- [ ] Add `hive_flutter` dependency to `pubspec.yaml`
- [ ] Run `flutter pub run build_runner build`
- [ ] Register `AppEntryAdapter()` in `main.dart`
- [ ] Open Hive box named `'settings'`
- [ ] Update `AvailableApps.getAll()` with your apps
- [ ] Use service methods to switch/check apps

### Settings Gear Icon
- [ ] Copy AppBar actions pattern
- [ ] Create your `DataManagementPage`
- [ ] Implement settings content
- [ ] Add navigation route
- [ ] Test back navigation

### Language Selector
- [ ] Copy `LanguageSelectorButton` widget
- [ ] Define your `LanguageOption` list
- [ ] Connect to `LocaleProvider.changeLocale()`
- [ ] Test language switching

---

## 🚨 Important Notes

### Hive Adapter Type IDs

When copying `AppEntry` model to another project, **change the typeId**:

```dart
// OLD (in this project)
@HiveType(typeId: 2)
class AppEntry extends HiveObject { ... }

// NEW (in your project - use different typeId)
@HiveType(typeId: 10)  // Or any unused number
class AppEntry extends HiveObject { ... }
```

**Why?** Hive uses typeId to identify adapters. Multiple models with the same typeId in the same project will cause crashes.

### Hive Box Names

The `AppSwitcherService` uses a box named `'settings'`. If you already have a settings box:

```dart
// Option 1: Share the box (recommended)
// Just ensure it's opened in main.dart
await Hive.openBox('settings');

// Option 2: Use a different box name
// Modify AppSwitcherService to use a different box:
static const String _settingsBoxName = 'app_switcher_settings';
```

### Locale Provider Integration

For flutter_modular:
```dart
class AppModule extends Module {
  @override
  void binds(List<Bind> binds) {
    binds.add(Bind.singleton((i) => LocaleProvider()));
  }
}
```

For Provider package:
```dart
ChangeNotifierProvider(
  create: (_) => LocaleProvider(),
  child: MyApp(),
)
```

For manual singleton:
```dart
class LocaleManager {
  static final LocaleProvider instance = LocaleProvider();
}
```

---

## 🎯 Design Philosophy

These components follow these principles:

1. **Minimal Dependencies**: Only use Flutter foundation or well-established packages (Hive)
2. **Static Services**: Services use static methods for easy access without DI complexity
3. **Pure Functions**: UI helpers are stateless functions with clear inputs/outputs
4. **Standard Patterns**: Follow Material Design and Flutter conventions
5. **Easy to Copy**: Each component is self-contained and documented
6. **No Tight Coupling**: Components don't depend on each other (except Locale Provider ↔ Localizations)

---

## 📚 Example: Full Integration in New Project

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(AppEntryAdapter()); // Change typeId in app_entry.dart first!
  
  // Open boxes
  await Hive.openBox('settings');
  
  runApp(
    ModularApp(
      module: AppModule(),
      child: const MyApp(),
    ),
  );
}

// app_module.dart
class AppModule extends Module {
  @override
  void binds(List<Bind> binds) {
    binds.add(Bind.singleton((i) => LocaleProvider()));
  }
}

// app_widget.dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Modular.get<LocaleProvider>();
    
    return AnimatedBuilder(
      animation: localeProvider,
      builder: (context, child) {
        return MaterialApp(
          locale: localeProvider.locale,
          home: const HomePage(),
        );
      },
    );
  }
}

// home_page.dart
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final currentApp = AppSwitcherService.getSelectedApp();
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.apps),
          onPressed: _showAppSwitcher,
        ),
        title: Text(t(context, 'app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          LanguageSelectorButton(
            languages: const [
              LanguageOption(code: 'en', name: 'English'),
              LanguageOption(code: 'da', name: 'Dansk'),
            ],
            onLanguageChanged: (code) {
              Modular.get<LocaleProvider>().changeLocale(Locale(code));
            },
          ),
        ],
      ),
      body: Center(child: Text(currentApp.name)),
    );
  }
  
  Future<void> _showAppSwitcher() async {
    await showAppSwitcherDialog(
      context,
      apps: AvailableApps.getAll(),
      currentAppId: AppSwitcherService.getSelectedAppId(),
      onAppSelected: (id) async {
        await AppSwitcherService.setSelectedAppId(id);
        setState(() {});
      },
    );
  }
  
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }
}
```

---

## 🤝 Contributing to Modularity

When modifying these components, maintain these principles:

1. **No App-Specific Logic**: Don't add inventory-specific, user-specific, or domain-specific code
2. **Document Changes**: Update this file when adding new reusable patterns
3. **Test in Isolation**: Ensure components work without the parent app context
4. **Keep Dependencies Minimal**: Avoid adding new package dependencies
5. **Use Callbacks**: Prefer callbacks over tight coupling to services

---

## 🔄 Google Drive Sync Components (NEW)

### Overview

Best-of-breed Google Drive sync architecture combining clean separation of concerns with robust timestamp-based conflict detection for data loss prevention.

### Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│ App-Specific Layer (Your Business Logic)                │
│ - InventoryDriveService / ReflectionDriveService       │
│ - Model serialization & deserialization                 │
│ - App-specific sync triggers                            │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Enhanced Service Layer (Reusable)                       │
│ - EnhancedGoogleDriveService                            │
│ - Timestamp-based conflict detection                    │
│ - Debounced uploads, auto-sync                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Platform Auth Layer                                      │
│ - MobileGoogleAuthService (Android/iOS)                 │
│ - DesktopDriveAuth (Windows/macOS/Linux)                │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Core CRUD Layer                                          │
│ - GoogleDriveCrudClient (Pure Drive API operations)     │
│ - GoogleDriveConfig (Configuration)                     │
└─────────────────────────────────────────────────────────┘
```

### Components

#### 1. Core Configuration (`drive_config.dart`)

```dart
class GoogleDriveConfig {
  final String fileName;
  final String mimeType;
  final String scope;
  final String? parentFolder;

  const GoogleDriveConfig({
    required this.fileName,
    required this.mimeType,
    this.scope = 'https://www.googleapis.com/auth/drive.appdata',
    this.parentFolder = 'appDataFolder',
  });
}
```

**What Makes It Modular:**
- ✅ Simple configuration data class
- ✅ No logic, just data
- ✅ Supports both appDataFolder and regular Drive

#### 2. CRUD Client (`drive_crud_client.dart`)

```dart
class GoogleDriveCrudClient {
  // Create or update file
  Future<String> upsertFile(String content);
  
  // Read file content
  Future<String?> readFileContent();
  
  // Delete file
  Future<bool> deleteFileByName();
  
  // Check if file exists
  Future<bool> fileExists();
  
  // Get file metadata
  Future<File?> getFileMetadata();
}
```

**What Makes It Modular:**
- ✅ Pure CRUD operations
- ✅ No business logic
- ✅ Uses googleapis and googleapis_auth
- ✅ Works with any file type/content

#### 3. Mobile Authentication (`mobile_google_auth_service.dart`)

```dart
class MobileGoogleAuthService {
  bool get isSignedIn;
  GoogleSignInAccount? get currentUser;
  
  Future<bool> initializeAuth();
  Future<bool> signIn();
  Future<void> signOut();
  Future<GoogleDriveCrudClient?> createDriveClient();
  void listenToAuthChanges(callback);
}
```

**Platform:** Android/iOS only (uses google_sign_in)

**What Makes It Modular:**
- ✅ Encapsulates Google Sign-In complexity
- ✅ Silent sign-in support
- ✅ Token refresh handling
- ✅ Auth state listeners

#### 4. Enhanced Drive Service (`enhanced_google_drive_service.dart`)

**Core Features:**
- Timestamp-based conflict detection
- Debounced uploads (700ms default)
- Auto-sync on sign-in
- Event streams for UI updates
- Data loss prevention

```dart
class EnhancedGoogleDriveService {
  // State
  bool get syncEnabled;
  bool get isAuthenticated;
  DateTime? get localLastModified;
  
  // Streams
  Stream<bool> get onSyncStateChanged;
  Stream<String> get onUpload;
  Stream<String> get onDownload;
  Stream<String> get onError;
  
  // Methods
  Future<void> initialize();
  Future<bool> signIn();
  Future<void> signOut();
  void setSyncEnabled(bool enabled);
  
  // Upload/Download
  Future<void> uploadContent(String content, {DateTime? timestamp});
  Future<DownloadResult?> downloadContent();
  void scheduleUpload(String content, {DateTime? timestamp});
  
  // Utilities
  Future<bool> fileExists();
  void updateLocalTimestamp(DateTime timestamp);
}
```

**What Makes It Modular:**
- ✅ Generic - works with any data type
- ✅ No app-specific logic
- ✅ Callback hooks for timestamp persistence
- ✅ Event-driven architecture

#### 5. App-Specific Service Pattern

Example from `inventory_drive_service.dart`:

```dart
class InventoryDriveService {
  late final EnhancedGoogleDriveService _driveService;
  
  InventoryDriveService._() {
    const config = GoogleDriveConfig(
      fileName: 'aa4step_inventory_data.json',
      mimeType: 'application/json',
      scope: 'https://www.googleapis.com/auth/drive.appdata',
      parentFolder: 'appDataFolder',
    );
    
    _driveService = EnhancedGoogleDriveService(
      config: config,
      onSaveTimestamp: _saveLastModified,
      onLoadTimestamp: _getLocalLastModified,
    );
  }
  
  // App-specific methods
  Future<void> uploadFromBox(Box<InventoryEntry> box);
  Future<List<InventoryEntry>?> downloadEntries();
  Future<bool> checkAndSyncIfNeeded();
  void scheduleUploadFromBox(Box<InventoryEntry> box);
}
```

### Data Format Pattern

**Critical:** Always include version and lastModified:

```json
{
  "version": "2.0",
  "exportDate": "2025-11-15T10:30:00.000Z",
  "lastModified": "2025-11-15T10:30:00.000Z",
  "yourDataKey": [
    {
      "id": "...",
      "data": "...",
      "lastModified": "2025-11-15T10:30:00.000Z"
    }
  ]
}
```

### Timestamp-Based Conflict Detection

```dart
// On app start or sign-in:
Future<bool> checkAndSyncIfNeeded() async {
  // Download remote file
  final result = await _driveService.downloadContent();
  if (result == null) return false;

  // Parse remote timestamp
  final decoded = json.decode(result.content);
  final remoteTimestamp = DateTime.parse(decoded['lastModified']);
  final localTimestamp = await _getLocalLastModified();

  // Compare
  if (localTimestamp == null || remoteTimestamp.isAfter(localTimestamp)) {
    // Remote is newer - sync down
    await _restoreFromRemote(result.content);
    return true;
  }
  
  return false; // Local is up to date
}
```

### Integration Example

```dart
// 1. Create app-specific service
class MyAppDriveService {
  static MyAppDriveService? _instance;
  static MyAppDriveService get instance => _instance ??= MyAppDriveService._();
  
  late final EnhancedGoogleDriveService _driveService;
  
  MyAppDriveService._() {
    _driveService = EnhancedGoogleDriveService(
      config: GoogleDriveConfig(
        fileName: 'my_app_data.json',
        mimeType: 'application/json',
      ),
      onSaveTimestamp: _saveTimestamp,
      onLoadTimestamp: _loadTimestamp,
    );
  }
  
  Future<void> _saveTimestamp(DateTime ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastModified', ts.toIso8601String());
  }
  
  Future<DateTime?> _loadTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('lastModified');
    return str != null ? DateTime.parse(str) : null;
  }
}

// 2. Initialize in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final driveService = MyAppDriveService.instance;
  await driveService.initialize();
  
  // Check for remote updates
  await driveService.checkAndSyncIfNeeded();
  
  runApp(MyApp());
}

// 3. Upload on data change
Future<void> saveData(MyData data) async {
  // Save locally
  await database.save(data);
  
  // Schedule upload (debounced)
  MyAppDriveService.instance.scheduleUpload();
}
```

### Benefits

**Data Loss Prevention:**
- ✅ Timestamp comparison prevents overwriting newer data
- ✅ Auto-sync on sign-in detects remote changes
- ✅ Debounced uploads reduce API calls
- ✅ Event streams allow UI feedback

**Code Reusability:**
- ✅ Core CRUD layer works with any Drive app
- ✅ Enhanced service works with any data format
- ✅ Auth services handle platform differences
- ✅ App-specific layer only contains business logic

**Ease of Use:**
- ✅ Singleton pattern for app-specific service
- ✅ Event streams for reactive UI
- ✅ Automatic conflict detection
- ✅ No manual merge logic needed

### Files to Copy

**Core (Required):**
- `lib/services/google_drive/drive_config.dart`
- `lib/services/google_drive/drive_crud_client.dart`
- `lib/services/google_drive/enhanced_google_drive_service.dart`

**Mobile Platform (Android/iOS):**
- `lib/services/google_drive/mobile_google_auth_service.dart`

**Desktop Platform (Windows/macOS/Linux):**
- `lib/services/google_drive/desktop_drive_auth.dart`
- `lib/services/google_drive/desktop_drive_client.dart`

**App-Specific Example:**
- `lib/services/inventory_drive_service.dart` (as reference pattern)

### Dependencies

```yaml
dependencies:
  google_sign_in: ^6.1.5  # Mobile only
  googleapis: ^11.4.0
  googleapis_auth: ^1.4.1
  http: ^1.1.0
  # For timestamp storage:
  shared_preferences: ^2.2.0  # or hive_flutter
```

### What Makes It Modular

- ✅ **Layered Architecture**: Each layer has single responsibility
- ✅ **Platform Abstraction**: Mobile and desktop auth separated
- ✅ **No Tight Coupling**: Uses callbacks for timestamp persistence
- ✅ **Event-Driven**: Streams for UI reactivity
- ✅ **Dependency Injection**: Config passed to constructors
- ✅ **Generic Content**: Works with any JSON-serializable data
- ✅ **Stateless CRUD**: Core operations have no side effects

### How to Reuse

1. Copy core files (config, CRUD client, enhanced service)
2. Copy auth service for your platform (mobile or desktop)
3. Create app-specific service extending the pattern
4. Implement timestamp persistence (SharedPreferences or Hive)
5. Add JSON serialization to your models
6. Call initialize() and checkAndSyncIfNeeded() on app start
7. Schedule uploads after data changes

### Important Notes

**Timestamp Storage:**
```dart
// Option 1: SharedPreferences (simple)
final prefs = await SharedPreferences.getInstance();
await prefs.setString('lastModified', timestamp.toIso8601String());

// Option 2: Hive (if already using it)
final box = Hive.box('settings');
await box.put('lastModified', timestamp.toIso8601String());
```

**Auto-Sync Pattern:**
```dart
// In your main.dart or app initialization:
if (driveService.isAuthenticated) {
  final synced = await MyAppDriveService.instance.checkAndSyncIfNeeded();
  if (synced) {
    print('✓ Auto-synced from Google Drive');
  }
}
```

**UI Integration:**
```dart
// Listen to sync events
StreamBuilder<String>(
  stream: driveService.onUpload,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Text('Uploaded: ${snapshot.data}');
    }
    return Container();
  },
)
```

---

**Last Updated:** November 15, 2025
**Version:** 2.0.0
