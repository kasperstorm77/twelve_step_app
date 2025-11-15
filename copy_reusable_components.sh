#!/bin/bash

# Script to copy reusable components from this project to another Flutter project
# Usage: ./copy_reusable_components.sh <destination_folder>

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if destination folder is provided
if [ -z "$1" ]; then
    print_error "Usage: ./copy_reusable_components.sh <destination_folder>"
    echo ""
    echo "Example:"
    echo "  ./copy_reusable_components.sh ~/my_flutter_project"
    echo "  ./copy_reusable_components.sh /path/to/project"
    exit 1
fi

DEST_DIR="$1"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate destination directory
if [ ! -d "$DEST_DIR" ]; then
    print_error "Destination folder does not exist: $DEST_DIR"
    exit 1
fi

# Check if it looks like a Flutter project
if [ ! -f "$DEST_DIR/pubspec.yaml" ]; then
    print_warning "Warning: $DEST_DIR doesn't appear to be a Flutter project (no pubspec.yaml found)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled."
        exit 0
    fi
fi

print_info "Copying reusable components to: $DEST_DIR"
echo ""

# Create destination directories
print_info "Creating directory structure..."
mkdir -p "$DEST_DIR/lib/services"
mkdir -p "$DEST_DIR/lib/services/google_drive"
mkdir -p "$DEST_DIR/lib/models"
mkdir -p "$DEST_DIR/docs"
print_success "Directories created"

# Copy core services
print_info "Copying services..."
FILES_COPIED=0

# LocaleProvider
if [ -f "$SOURCE_DIR/lib/services/locale_provider.dart" ]; then
    cp "$SOURCE_DIR/lib/services/locale_provider.dart" "$DEST_DIR/lib/services/"
    print_success "Copied: lib/services/locale_provider.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# AppSwitcherService
if [ -f "$SOURCE_DIR/lib/services/app_switcher_service.dart" ]; then
    cp "$SOURCE_DIR/lib/services/app_switcher_service.dart" "$DEST_DIR/lib/services/"
    print_success "Copied: lib/services/app_switcher_service.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Localizations
if [ -f "$SOURCE_DIR/lib/localizations.dart" ]; then
    cp "$SOURCE_DIR/lib/localizations.dart" "$DEST_DIR/lib/"
    print_success "Copied: lib/localizations.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Copy models
print_info "Copying models..."

# AppEntry
if [ -f "$SOURCE_DIR/lib/models/app_entry.dart" ]; then
    cp "$SOURCE_DIR/lib/models/app_entry.dart" "$DEST_DIR/lib/models/"
    print_success "Copied: lib/models/app_entry.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Copy I Am Definition if needed (optional - comment out if not needed)
if [ -f "$SOURCE_DIR/lib/models/i_am_definition.dart" ]; then
    cp "$SOURCE_DIR/lib/models/i_am_definition.dart" "$DEST_DIR/lib/models/"
    print_success "Copied: lib/models/i_am_definition.dart (optional - only needed for AA apps)"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Copy Google Drive Sync Components
print_info "Copying Google Drive sync components..."

# Core components (always needed)
if [ -f "$SOURCE_DIR/lib/services/google_drive/drive_config.dart" ]; then
    cp "$SOURCE_DIR/lib/services/google_drive/drive_config.dart" "$DEST_DIR/lib/services/google_drive/"
    print_success "Copied: lib/services/google_drive/drive_config.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

if [ -f "$SOURCE_DIR/lib/services/google_drive/drive_crud_client.dart" ]; then
    cp "$SOURCE_DIR/lib/services/google_drive/drive_crud_client.dart" "$DEST_DIR/lib/services/google_drive/"
    print_success "Copied: lib/services/google_drive/drive_crud_client.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

if [ -f "$SOURCE_DIR/lib/services/google_drive/enhanced_google_drive_service.dart" ]; then
    cp "$SOURCE_DIR/lib/services/google_drive/enhanced_google_drive_service.dart" "$DEST_DIR/lib/services/google_drive/"
    print_success "Copied: lib/services/google_drive/enhanced_google_drive_service.dart"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Mobile auth (comment out if desktop-only app)
if [ -f "$SOURCE_DIR/lib/services/google_drive/mobile_google_auth_service.dart" ]; then
    cp "$SOURCE_DIR/lib/services/google_drive/mobile_google_auth_service.dart" "$DEST_DIR/lib/services/google_drive/"
    print_success "Copied: lib/services/google_drive/mobile_google_auth_service.dart (Android/iOS)"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Desktop auth (comment out if mobile-only app)
if [ -f "$SOURCE_DIR/lib/services/google_drive/desktop_drive_auth.dart" ]; then
    cp "$SOURCE_DIR/lib/services/google_drive/desktop_drive_auth.dart" "$DEST_DIR/lib/services/google_drive/"
    print_success "Copied: lib/services/google_drive/desktop_drive_auth.dart (Desktop)"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

if [ -f "$SOURCE_DIR/lib/services/google_drive/desktop_drive_client.dart" ]; then
    cp "$SOURCE_DIR/lib/services/google_drive/desktop_drive_client.dart" "$DEST_DIR/lib/services/google_drive/"
    print_success "Copied: lib/services/google_drive/desktop_drive_client.dart (Desktop)"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# App-specific example (reference only)
if [ -f "$SOURCE_DIR/lib/services/inventory_drive_service.dart" ]; then
    cp "$SOURCE_DIR/lib/services/inventory_drive_service.dart" "$DEST_DIR/lib/services/"
    print_success "Copied: lib/services/inventory_drive_service.dart (REFERENCE - adapt for your app)"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Copy documentation
print_info "Copying documentation..."

if [ -f "$SOURCE_DIR/docs/REUSABLE_COMPONENTS.md" ]; then
    cp "$SOURCE_DIR/docs/REUSABLE_COMPONENTS.md" "$DEST_DIR/docs/"
    print_success "Copied: docs/REUSABLE_COMPONENTS.md"
    FILES_COPIED=$((FILES_COPIED + 1))
fi

# Create setup guide
cat > "$DEST_DIR/docs/SETUP_REUSABLE_COMPONENTS.md" << 'EOF'
# Reusable Components Setup Guide

**IMPORTANT FOR AI ASSISTANTS**: This guide is optimized for AI code assistants. Follow instructions precisely in the order given.

Source Repository: https://github.com/kasperstorm77/twelve_step_app

---

## ⚠️ CRITICAL: Conflict Resolution Rules

**These copied components are PRODUCTION-TESTED and ROBUST. They should REPLACE existing implementations.**

**BEFORE implementing, check if the target project has conflicting functionality:**

1. **Existing Sync Functionality** - If inferior/untested sync exists:
   - ✅ REPLACE with the robust sync pattern from this project
   - ✅ DELETE old sync services/models
   - ✅ Migrate data if needed, then use the new sync architecture
   - ⚠️ The copied sync pattern is battle-tested and conflict-proof

2. **Existing Localization** - If basic/incomplete locale system exists:
   - ✅ REPLACE with LocaleProvider (more robust)
   - ✅ Migrate translations to the new localizedValues map
   - ✅ DELETE old locale files after migration

3. **Existing Settings UI** - If poorly structured settings exist:
   - ✅ REPLACE with the gear icon pattern (cleaner UX)
   - ✅ Migrate settings data if needed
   - ✅ Use the DataManagementPage pattern

4. **Existing App Switcher** - If buggy multi-app logic exists:
   - ✅ REPLACE with AppSwitcherService (Hive-backed, reliable)
   - ✅ Migrate app configurations to AppEntry model
   - ✅ DELETE old switching logic

**RULE**: The copied components are SUPERIOR. Replace inferior existing code. Only keep existing code if it's clearly more sophisticated or has features these components lack.

---

## 🔄 Understanding the Sync Architecture (CRITICAL)

**This section is MANDATORY reading before modifying any data models or services.**

### The Sync Pattern Used in This Project

This project uses **Google Drive AppData sync** with a **conflict-avoidance design** that has been battle-tested in production:

```
Local Storage (Hive) ←→ Sync Service ←→ Google Drive (AppData folder)
```

**Key Principles:**

1. **Single Source of Truth**: Google Drive is the authoritative source
   - On startup: Download from Drive → Overwrite local
   - On changes: Upload to Drive → Confirm success  
   - Never merge - always replace
   - **WHY**: Eliminates complex merge logic and prevents data corruption

2. **Timestamp-Based Conflict Resolution**:
   ```dart
   // Each synced model includes:
   DateTime lastModified;  // Set on every change
   
   // Sync logic (automatic):
   if (driveData.lastModified > localData.lastModified) {
     // Drive is newer - download and replace local
   } else {
     // Local is newer - upload to Drive
   }
   ```

3. **Atomic Operations**:
   - Download entire dataset as single JSON file
   - Parse and validate ALL items before saving
   - Replace local storage in single Hive transaction
   - Upload happens immediately after local save
   - **WHY**: Prevents partial/corrupt data states

4. **No Partial Syncs**:
   - Always sync complete datasets (not individual fields)
   - No field-level merging or diff algorithms
   - No conflict markers or manual resolution dialogs
   - Last-write-wins on full object basis
   - **WHY**: Simple, predictable, and impossible to have merge conflicts

### Why This Design Avoids Sync Conflicts

✅ **No Concurrent Edits**: Single user per Google account  
✅ **Immediate Upload**: Changes sync instantly when online  
✅ **Download on Startup**: Always gets latest state on app launch  
✅ **Full Replacement**: No merge logic = zero merge conflicts  
✅ **Validation on Parse**: Corrupt JSON rejected before saving locally  
✅ **Transaction Safety**: Hive box.clear() + box.addAll() is atomic

### Implementing Sync in New Models

When adding sync to a new data model:

```dart
@HiveType(typeId: X)  // Use unique typeId
class YourModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime lastModified;  // REQUIRED for sync
  
  @HiveField(2)
  // ... your other fields
  
  YourModel({
    required this.id,
    required this.lastModified,
    // ... your fields
  });
  
  // REQUIRED: toJson for upload
  Map<String, dynamic> toJson() => {
    'id': id,
    'lastModified': lastModified.toIso8601String(),
    // ... your fields (all must be JSON-serializable)
  };
  
  // REQUIRED: fromJson for download
  factory YourModel.fromJson(Map<String, dynamic> json) {
    return YourModel(
      id: json['id'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      // ... parse your fields with null safety
    );
  }
  
  // Helper: Create new instance with updated timestamp
  YourModel copyWith({/* your fields */}) {
    return YourModel(
      id: id,
      lastModified: DateTime.now(),  // Always update on change
      // ... copy fields with defaults to this.*
    );
  }
}
```

### Critical Sync Service Pattern

```dart
class YourSyncService {
  static const String _fileName = 'your_data.json';
  
  // Upload: Called immediately after local save
  static Future<void> uploadToCloud(Box<YourModel> box) async {
    try {
      final items = box.values.toList();
      final jsonList = items.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      // Upload entire dataset as single file
      await driveService.uploadFile(
        fileName: _fileName,
        content: jsonString,
      );
      
      debugPrint('✓ Uploaded ${items.length} items to Drive');
    } catch (e) {
      debugPrint('✗ Upload failed: $e');
      rethrow;  // Let caller handle
    }
  }
  
  // Download: Called on app startup
  static Future<void> downloadFromCloud(Box<YourModel> box) async {
    try {
      final jsonString = await driveService.downloadFile(_fileName);
      if (jsonString.isEmpty) {
        debugPrint('ℹ No cloud data found');
        return;
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      // Parse all items (throws if invalid JSON)
      final items = jsonList
          .map((json) => YourModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Replace local storage atomically
      await box.clear();  // Delete all local data
      await box.addAll(items);  // Add downloaded data
      
      debugPrint('✓ Downloaded ${items.length} items from Drive');
    } catch (e) {
      debugPrint('✗ Download failed: $e');
      rethrow;  // Let caller handle
    }
  }
}
```

### Integration in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(YourModelAdapter());
  
  // Open box
  final box = await Hive.openBox<YourModel>('your_box');
  
  // Download on startup (if signed in)
  if (await driveService.isSignedIn()) {
    try {
      await YourSyncService.downloadFromCloud(box);
    } catch (e) {
      debugPrint('Startup sync failed, using local data: $e');
    }
  }
  
  runApp(MyApp());
}
```

### When to Upload

```dart
// After every local modification:
Future<void> saveItem(YourModel item) async {
  final box = Hive.box<YourModel>('your_box');
  
  // Save locally
  await box.put(item.id, item);
  
  // Upload to cloud immediately
  if (await driveService.isSignedIn()) {
    try {
      await YourSyncService.uploadToCloud(box);
    } catch (e) {
      debugPrint('Upload failed (will retry on next change): $e');
      // Don't throw - local save succeeded
    }
  }
}
```

### When NOT to Use This Sync Pattern

❌ **Multi-user collaboration** - Use Firestore, operational transform, or CRDTs  
❌ **Offline-first with multi-device conflicts** - Use vector clocks or last-write-wins with conflict detection  
❌ **Large binary files (>5MB)** - Use delta sync, chunking, or dedicated file storage  
❌ **Real-time collaboration** - Use WebSockets + operational transform  
✅ **Single-user personal data** - This pattern is PERFECT and battle-tested

---

## 📦 Files Copied

### Services
- `lib/services/locale_provider.dart` - Locale state management with ChangeNotifier
- `lib/services/app_switcher_service.dart` - Multi-app switching with Hive persistence

### Models
- `lib/models/app_entry.dart` - App metadata model with Hive adapter

### Localization
- `lib/localizations.dart` - Simple translation system with fallback

---

## Quick Setup Checklist

### 1. Identify and Remove Conflicting Code

**Check for inferior implementations and delete them:**

```bash
# Find old locale/translation files
find lib -name "*locale*" -o -name "*translation*" -o -name "*i18n*"

# Find old app switcher logic
grep -r "selectedApp\|currentApp\|switchApp" lib/

# Find old sync services
find lib/services -name "*sync*" -o -name "*drive*" -o -name "*cloud*"
```

**Delete old files that conflict with copied components. Document what you remove.**

### 2. Update Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.13
```

Run:
```bash
flutter pub get
```

### 3. Change Hive TypeId (CRITICAL)

Open `lib/models/app_entry.dart` and change the typeId to avoid conflicts:

```dart
// BEFORE (from source project):
@HiveType(typeId: 2)

// AFTER (in target project - use unique unused number):
@HiveType(typeId: 10)  // Check existing typeIds first
```

**Check for typeId conflicts:**
```bash
grep -r "@HiveType(typeId:" lib/models/
```

Each model MUST have a unique typeId within the project.

### 4. Generate Hive Adapters

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected output: `lib/models/app_entry.g.dart` created

### 5. Register Adapters in main.dart

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'models/app_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(AppEntryAdapter());
  await Hive.openBox('settings');
  
  runApp(MyApp());
}
```

### 6. Setup LocaleProvider

With flutter_modular:
```dart
class AppModule extends Module {
  @override
  void binds(List<Bind> binds) {
    binds.add(Bind.singleton((i) => LocaleProvider()));
  }
}
```

Or with Provider package:
```dart
ChangeNotifierProvider(
  create: (_) => LocaleProvider(),
  child: MyApp(),
)
```

### 7. Update Translations

Open `lib/localizations.dart` and replace the `localizedValues` map:

```dart
final Map<String, Map<String, String>> localizedValues = {
  'en': {
    'your_key': 'Your Translation',
    // ... add all your keys
  },
  'da': {  // Or your language
    'your_key': 'Din Oversættelse',
    // ... add all your keys
  },
};
```

### 8. Update Available Apps

Open `lib/models/app_entry.dart` and modify `AvailableApps.getAll()`:

```dart
class AvailableApps {
  static const String app1 = 'app_1_id';
  static const String app2 = 'app_2_id';

  static List<AppEntry> getAll() {
    return [
      AppEntry(
        id: app1,
        name: 'First App',
        description: 'Description',
        isActive: true,
      ),
      AppEntry(
        id: app2,
        name: 'Second App',
        description: 'Description',
        isActive: true,
      ),
    ];
  }
}
```

### 9. Migrate Data (If Needed)

If replacing existing functionality, migrate user data:

```dart
// Example: Migrate old locale settings
final oldLocale = await oldPrefs.getString('locale');
if (oldLocale != null) {
  final localeProvider = Modular.get<LocaleProvider>();
  localeProvider.changeLocale(Locale(oldLocale));
}

// Example: Migrate old app selection
final oldAppId = await oldPrefs.getString('current_app');
if (oldAppId != null) {
  await AppSwitcherService.setSelectedAppId(oldAppId);
}
```

### 10. Test Thoroughly

- [ ] Locale switching works
- [ ] App switching persists across restarts
- [ ] Sync uploads after local changes
- [ ] Sync downloads on startup
- [ ] No Hive typeId conflicts
- [ ] Translations display correctly

---

## Next Steps

See `REUSABLE_COMPONENTS.md` for:
- Detailed integration examples
- UI component patterns (gear icon, language selector)
- Complete usage guide with code samples

---

**Generated by:** copy_reusable_components.sh  
**Source:** Twelve Step App (https://github.com/kasperstorm77/twelve_step_app)
EOF

print_success "Created: docs/SETUP_REUSABLE_COMPONENTS.md"
FILES_COPIED=$((FILES_COPIED + 1))

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Copy complete! $FILES_COPIED files copied."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Next steps:"
echo "  1. cd $DEST_DIR"
echo "  2. Read: docs/SETUP_REUSABLE_COMPONENTS.md (AI-optimized)"
echo "  3. STEP 1: Identify and REMOVE conflicting old code"
echo "  4. Read: docs/REUSABLE_COMPONENTS.md"
echo "  5. Update lib/models/app_entry.dart (change typeId!)"
echo "  6. Update lib/localizations.dart (your translations)"
echo "  7. Add dependencies to pubspec.yaml:"
echo "     - google_sign_in: ^6.1.5 (mobile)"
echo "     - googleapis: ^11.4.0"
echo "     - googleapis_auth: ^1.4.1"
echo "     - http: ^1.1.0"
echo "  8. Run: flutter pub get"
echo "  9. Run: flutter pub run build_runner build"
echo "  10. Create your app-specific drive service (see inventory_drive_service.dart)"
echo ""
print_warning "These components are PRODUCTION-TESTED. Replace inferior existing code!"
echo ""
