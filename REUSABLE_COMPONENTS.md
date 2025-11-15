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

**Last Updated:** November 15, 2025
**Version:** 1.0.0
