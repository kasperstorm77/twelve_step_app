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

**IMPORTANT FOR AI ASSISTANTS**: This guide is optimized for AI code assistants. Follow instructions precisely in the order given. Check for conflicts before implementing.

Source Repository: https://github.com/kasperstorm77/twelve_step_app

---

## ⚠️ CRITICAL: Conflict Resolution Rules

**BEFORE implementing these components, check if the target project already has:**

1. **Existing Sync Functionality** - If Google Drive sync or similar cloud sync already exists:
   - ✅ KEEP the existing sync implementation  
   - ✅ DO NOT copy Drive-related services from this project
   - ✅ Study the existing sync architecture before adding new data models
   - ⚠️ Sync conflicts are the #1 cause of data loss - never mix sync approaches

2. **Existing Localization** - If locale/translation system exists:
   - ✅ KEEP the existing localization system
   - ✅ DO NOT overwrite with LocaleProvider  
   - ✅ Adapt new features to existing locale management

3. **Existing Settings UI** - If settings/data management UI exists:
   - ✅ KEEP the existing UI structure
   - ✅ INTEGRATE new features into existing settings
   - ✅ DO NOT create duplicate settings pages

4. **Existing App Switcher** - If multi-app or multi-mode functionality exists:
   - ✅ KEEP the existing implementation
   - ✅ DO NOT copy AppSwitcherService
   - ✅ Review existing approach before adding app switching

**RULE**: Existing functionality ALWAYS takes precedence. Clean up conflicting copied files after reviewing them.

---

## �� Understanding the Sync Architecture (CRITICAL)

**This section is MANDATORY reading before modifying any data models or services.**

### The Sync Pattern Used in Source Project

The source project uses **Google Drive AppData sync** with a conflict-avoidance design:

```
Local Storage (Hive) ←→ Sync Service ←→ Google Drive (AppData folder)
```

**Key Principles:**

1. **Single Source of Truth**: Google Drive is the authoritative source
   - On startup: Download from Drive → Overwrite local
   - On changes: Upload to Drive → Confirm success  
   - Never merge - always replace

2. **Timestamp-Based Conflict Resolution**:
   ```dart
   // Each synced model includes:
   DateTime lastModified;  // Set on every change
   
   // Sync logic:
   if (driveData.lastModified > localData.lastModified) {
     // Drive is newer - download and replace local
   } else {
     // Local is newer - upload to Drive
   }
   ```

3. **Atomic Operations**:
   - Download entire dataset
   - Parse and validate
   - Replace local storage in single transaction
   - Upload happens immediately after local save

4. **No Partial Syncs**:
   - Always sync complete datasets
   - No field-level merging
   - No conflict markers or resolution dialogs
   - Last-write-wins on full object basis

### Why This Design Avoids Conflicts

✅ **No Concurrent Edits**: Single user per account  
✅ **Immediate Upload**: Changes sync instantly (when online)  
✅ **Download on Startup**: Always gets latest on launch  
✅ **Full Replacement**: No merge logic = no merge conflicts  
✅ **Validation**: Parse errors prevent corrupt data from saving

### Implementing Sync in New Models

If adding sync to a new model in the target project:

```dart
@HiveType(typeId: X)  // Use unique typeId
class YourModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime lastModified;  // REQUIRED for sync
  
  @HiveField(2)
  // ... your fields
  
  YourModel({
    required this.id,
    required this.lastModified,
    // ... your fields
  });
  
  // REQUIRED: toJson for upload
  Map<String, dynamic> toJson() => {
    'id': id,
    'lastModified': lastModified.toIso8601String(),
    // ... your fields
  };
  
  // REQUIRED: fromJson for download
  factory YourModel.fromJson(Map<String, dynamic> json) {
    return YourModel(
      id: json['id'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      // ... your fields
    );
  }
}
```

### Critical Sync Service Pattern

```dart
class YourSyncService {
  // Upload: Called immediately after local save
  static Future<void> uploadToCloud(List<YourModel> items) async {
    final jsonList = items.map((item) => item.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    
    // Upload entire dataset as single file
    await cloudService.uploadFile(
      fileName: 'your_data.json',
      content: jsonString,
    );
  }
  
  // Download: Called on app startup
  static Future<void> downloadFromCloud() async {
    final jsonString = await cloudService.downloadFile('your_data.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    
    // Parse all items
    final items = jsonList.map((json) => YourModel.fromJson(json)).toList();
    
    // Replace local storage atomically
    final box = Hive.box<YourModel>('your_box');
    await box.clear();  // Delete all local data
    await box.addAll(items);  // Add downloaded data
  }
}
```

### When NOT to Use This Sync Pattern

❌ **Multi-user collaboration** - Use operational transform or CRDTs  
❌ **Offline-first with long offline periods** - Use vector clocks  
❌ **Large binary files** - Use delta sync or chunking  
❌ **Real-time collaboration** - Use WebSockets + OT/CRDT  
✅ **Single-user personal data** - This pattern is perfect

---

## 📦 Files Copied

### Services
- `lib/services/locale_provider.dart` - Locale state management
- `lib/services/app_switcher_service.dart` - Multi-app switching

### Models
- `lib/models/app_entry.dart` - App metadata model (Hive)

### Localization
- `lib/localizations.dart` - Translation system

---

## Quick Setup Checklist

**STEP 0: Conflict Check (DO THIS FIRST)**

- [ ] Check if sync functionality already exists → If YES, DO NOT copy Drive services
- [ ] Check if localization exists → If YES, DO NOT copy LocaleProvider/localizations.dart
- [ ] Check if settings UI exists → If YES, integrate into existing UI
- [ ] Check if app switching exists → If YES, DO NOT copy AppSwitcherService
- [ ] Document existing patterns before proceeding

### 1. Update Dependencies

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

### 2. Change Hive TypeId

**CRITICAL - DO NOT SKIP**: Open `lib/models/app_entry.dart` and change the typeId to avoid conflicts:

```dart
// BEFORE (from source project):
@HiveType(typeId: 2)

// AFTER (in target project - use unique unused number):
@HiveType(typeId: 10)  // Or 15, 20, 100 - any number not used elsewhere
```

**How to check for conflicts:**
```bash
# Search all Hive models for typeId usage
grep -r "@HiveType(typeId:" lib/models/
```

Each model MUST have a unique typeId within the same project.

### 3. Generate Hive Adapters

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected output: `lib/models/app_entry.g.dart` created

### 4. Register Adapters in main.dart

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'models/app_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register adapters (use same typeId as in app_entry.dart)
  Hive.registerAdapter(AppEntryAdapter());
  
  // Open settings box (used by AppSwitcherService)
  await Hive.openBox('settings');
  
  runApp(MyApp());
}
```

### 5. Setup LocaleProvider (If No Existing Localization)

**Only if conflict check passed - no existing locale system.**

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

### 6. Update Translations (If Using Copied Localization)

**Only if using the copied localization.dart file.**

Open `lib/localizations.dart` and replace the `localizedValues` map with your app's translations.

### 7. Update Available Apps (If Using AppSwitcher)

**Only if using AppSwitcherService.**

Open `lib/models/app_entry.dart` and modify `AvailableApps.getAll()` with your app definitions.

### 8. Clean Up Unused Components (IMPORTANT)

**If existing functionality was found in conflict check:**

If NOT using app switching:
```bash
rm lib/services/app_switcher_service.dart
rm lib/models/app_entry.dart
rm lib/models/app_entry.g.dart
```

If NOT using localization:
```bash
rm lib/localizations.dart
rm lib/services/locale_provider.dart
```

If existing sync exists:
```bash
# DO NOT copy or keep any Drive-related files
# Review docs/REUSABLE_COMPONENTS.md for sync patterns only
# Implement sync in existing service architecture
```

---

## Next Steps

See `REUSABLE_COMPONENTS.md` for:
- Detailed integration examples
- UI component patterns
- Complete usage guide

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
echo "  3. STEP 0: Check for existing functionality conflicts"
echo "  4. Read: docs/REUSABLE_COMPONENTS.md"
echo "  5. Update lib/models/app_entry.dart (change typeId!)"
echo "  6. Update lib/localizations.dart (your translations)"
echo "  7. Run: flutter pub get"
echo "  8. Run: flutter pub run build_runner build"
echo ""
print_warning "CRITICAL: Read sync architecture section before modifying data models!"
echo ""
