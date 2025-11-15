# Project Structure

This document describes the organization of the AA 4Step Inventory project.

## Root Directory

```
twelve_step_app/
├── docs/                          # Documentation
├── img/                           # Screenshots and images
├── lib/                           # Dart source code
├── assets/                        # App assets (icons, etc.)
├── scripts/                       # Build/utility scripts
├── no_sync/                       # Local-only files (gitignored)
├── test/                          # Unit and widget tests
├── android/                       # Android platform (gitignored, regenerate with flutter create)
├── ios/                           # iOS platform (gitignored, regenerate with flutter create)
├── web/                           # Web platform (gitignored, regenerate with flutter create)
├── windows/                       # Windows platform (gitignored, regenerate with flutter create)
├── linux/                         # Linux platform (gitignored, regenerate with flutter create)
├── macos/                         # macOS platform (gitignored, regenerate with flutter create)
├── README.md                      # Project overview
├── LICENSE                        # MIT License
├── pubspec.yaml                   # Dependencies
├── analysis_options.yaml          # Linter rules
├── copilot-instructions.md        # AI coding assistant guidelines
├── copy_reusable_components.sh    # Script to copy reusable components
├── android_manifest_template.xml  # Template for AndroidManifest (removes MANAGE_EXTERNAL_STORAGE)
├── icon.png                       # App icon source (1024x1024)
├── google-services_debug.json     # Firebase/Google Services (debug)
└── google-services_release.json   # Firebase/Google Services (release)
```

## Documentation (`docs/`)

| File | Purpose | Status |
|------|---------|--------|
| `DATA_SAFETY.md` | Data integrity testing checklist | ✅ Current |
| `REUSABLE_COMPONENTS.md` | Guide for copying modular components to other projects | ✅ Current |
| `BUILD_SCRIPTS.md` | Build automation and version management | ✅ Current |
| `GOOGLE_OAUTH_SETUP.md` | Google OAuth configuration guide | ✅ Current |
| `VS_CODE_DEBUG.md` | VS Code debugging setup | ✅ Current |
| `PLAY_STORE_DESCRIPTIONS.md` | App store listing content | ✅ Current |
| `PRIVACY_POLICY.md` | Privacy policy for app stores | ✅ Current |

## Images (`img/`)

| File | Description |
|------|-------------|
| `mainScreen.png` | Main app interface screenshot |
| `settings.png` | Settings/data management screenshot |
| `feature.png` | Feature highlight screenshot |

## Source Code (`lib/`)

```
lib/
├── main.dart                      # App entry point
├── localizations.dart             # Translation system
├── google_drive_client.dart       # Drive API HTTP client
│
├── app/                           # Flutter Modular setup
│   ├── app_module.dart           # Routes and DI
│   └── app_widget.dart           # MaterialApp wrapper
│
├── models/                        # Data models (Hive)
│   ├── inventory_entry.dart      # Main entry model
│   ├── inventory_entry.g.dart    # Generated Hive adapter
│   ├── i_am_definition.dart      # I Am definition model
│   ├── i_am_definition.g.dart    # Generated Hive adapter
│   ├── app_entry.dart            # App switcher model
│   └── app_entry.g.dart          # Generated Hive adapter
│
├── pages/                         # UI screens
│   ├── modular_inventory_home.dart   # Main tabbed interface
│   ├── form_tab.dart                 # Create/edit entries
│   ├── list_tab.dart                 # View entries (table/cards)
│   ├── settings_tab.dart             # I Am definitions CRUD
│   ├── data_management_page.dart     # Settings page wrapper
│   └── data_management_tab.dart      # JSON/Drive sync UI
│
├── services/                      # Business logic
│   ├── inventory_service.dart         # Entry CRUD
│   ├── i_am_service.dart             # I Am definition CRUD
│   ├── drive_service.dart            # Drive sync orchestration
│   ├── inventory_drive_service.dart  # Drive service layer
│   ├── locale_provider.dart          # Language state
│   ├── app_switcher_service.dart     # Multi-app switching
│   ├── app_version_service.dart      # Version management
│   └── google_drive/                 # Drive implementation
│       ├── drive_config.dart
│       ├── drive_crud_client.dart
│       ├── mobile_drive_service.dart
│       ├── mobile_google_auth_service.dart
│       ├── desktop_drive_auth.dart
│       ├── desktop_drive_client.dart
│       └── desktop_oauth_config.dart.template
│
└── utils/                         # Utilities
    ├── platform_helper.dart      # Platform detection
    └── sync_utils.dart           # Background serialization
```

## Scripts (`scripts/`)

| File | Purpose |
|------|---------|
| `increment_version.dart` | Automatically increments version in pubspec.yaml |

## Local-Only Files (`no_sync/` - gitignored)

Contains sensitive files that should never be committed:

- `LOCAL_SETUP.md` - Setup instructions with actual credentials
- `debug.keystore` - Android debug keystore (current platform)
- `my-release-key.jks` - Android release keystore (current platform)
- `debug.keystore.windows` - Backup from Windows
- `my-release-key.jks.windows` - Backup from Windows
- `README.md` - Keystore management instructions

## Assets (`assets/`)

```
assets/
└── icon/
    └── icon.png       # Optimized app icon (657KB)
```

## Platform Folders (Gitignored)

These folders are **not tracked in git** and must be regenerated after cloning:

```bash
flutter create --platforms=android,ios,windows,linux,macos,web .
```

Then copy the AndroidManifest template:
```bash
cp android_manifest_template.xml android/app/src/main/AndroidManifest.xml
```

### Why Platform Folders Are Gitignored

1. **Reduces repository size** - Platform folders contain large amounts of boilerplate
2. **Prevents merge conflicts** - Flutter generates these differently on different machines
3. **Cleaner diffs** - Only track your actual Dart code changes
4. **Easy regeneration** - `flutter create` rebuilds them perfectly
5. **Cross-platform flexibility** - Generate only the platforms you need

### Critical Files to Restore After Regeneration

After running `flutter create`, you must:

1. **Copy AndroidManifest template**:
   ```bash
   cp android_manifest_template.xml android/app/src/main/AndroidManifest.xml
   ```
   This removes the `MANAGE_EXTERNAL_STORAGE` permission for Play Store compliance.

2. **Create key.properties** (for release builds):
   See `no_sync/LOCAL_SETUP.md` for details.

3. **Copy keystores** (if building on a new machine):
   ```bash
   cp no_sync/debug.keystore ~/.android/debug.keystore
   cp no_sync/my-release-key.jks ~/my-release-key.jks
   ```

## Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies, assets, version |
| `analysis_options.yaml` | Linter rules and code style |
| `.gitignore` | Excludes platform folders, secrets, generated files |
| `android_manifest_template.xml` | Removes MANAGE_EXTERNAL_STORAGE permission |
| `google-services_debug.json` | Firebase config (debug) |
| `google-services_release.json` | Firebase config (release) |

## Build Outputs (Gitignored)

```
build/
└── app/
    └── outputs/
        ├── flutter-apk/
        │   └── app-release.apk
        └── bundle/
            └── release/
                └── app-release.aab    # Upload this to Play Store
```

## Development Workflow Files

| File | Purpose | Gitignored |
|------|---------|------------|
| `.dart_tool/` | Dart SDK cache | ✅ Yes |
| `.flutter-plugins` | Flutter plugin registry | ✅ Yes |
| `.flutter-plugins-dependencies` | Plugin dependency tree | ✅ Yes |
| `.packages` | Package resolution | ✅ Yes |
| `pubspec.lock` | Locked dependency versions | ✅ Yes |
| `*.g.dart` | Generated Hive adapters | ✅ Yes |
| `.idea/` | IntelliJ IDEA settings | ✅ Yes |
| `.vscode/` | VS Code settings | ⚠️ Tracked (tasks.json) |
| `*.iml` | IntelliJ module files | ✅ Yes |
| `.metadata` | Flutter metadata | ✅ Yes |

## Icon Management

### Source Icons
- **Root**: `icon.png` (1.5MB, 1024x1024) - Master icon
- **Assets**: `assets/icon/icon.png` (657KB) - Optimized

### Generated Icons
Run `flutter pub run flutter_launcher_icons` to generate:
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Windows: `windows/runner/resources/app_icon.ico`
- macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Web: `web/icons/`

## Google Services Setup

Both files should be in the project root:
- `google-services_debug.json` - For debug builds
- `google-services_release.json` - For release builds

The build system automatically copies the correct one to `android/app/google-services.json`.

## Quick Reference

### Clone and Setup
```bash
git clone <repo>
cd twelve_step_app
flutter create --platforms=android,ios,windows,linux,macos,web .
cp android_manifest_template.xml android/app/src/main/AndroidManifest.xml
flutter pub get
flutter pub run build_runner build
```

### Build Release
```bash
dart scripts/increment_version.dart
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Copy Reusable Components to Another Project
```bash
./copy_reusable_components.sh ~/path/to/other/project
```

---

**Last Updated:** November 15, 2025
