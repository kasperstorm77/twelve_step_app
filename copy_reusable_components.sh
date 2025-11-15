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
    ((FILES_COPIED++))
fi

# AppSwitcherService
if [ -f "$SOURCE_DIR/lib/services/app_switcher_service.dart" ]; then
    cp "$SOURCE_DIR/lib/services/app_switcher_service.dart" "$DEST_DIR/lib/services/"
    print_success "Copied: lib/services/app_switcher_service.dart"
    ((FILES_COPIED++))
fi

# Localizations
if [ -f "$SOURCE_DIR/lib/localizations.dart" ]; then
    cp "$SOURCE_DIR/lib/localizations.dart" "$DEST_DIR/lib/"
    print_success "Copied: lib/localizations.dart"
    ((FILES_COPIED++))
fi

# Copy models
print_info "Copying models..."

# AppEntry
if [ -f "$SOURCE_DIR/lib/models/app_entry.dart" ]; then
    cp "$SOURCE_DIR/lib/models/app_entry.dart" "$DEST_DIR/lib/models/"
    print_success "Copied: lib/models/app_entry.dart"
    ((FILES_COPIED++))
fi

# Copy I Am Definition if needed (optional - comment out if not needed)
if [ -f "$SOURCE_DIR/lib/models/i_am_definition.dart" ]; then
    cp "$SOURCE_DIR/lib/models/i_am_definition.dart" "$DEST_DIR/lib/models/"
    print_success "Copied: lib/models/i_am_definition.dart (optional - only needed for AA apps)"
    ((FILES_COPIED++))
fi

# Copy documentation
print_info "Copying documentation..."

if [ -f "$SOURCE_DIR/docs/REUSABLE_COMPONENTS.md" ]; then
    cp "$SOURCE_DIR/docs/REUSABLE_COMPONENTS.md" "$DEST_DIR/docs/"
    print_success "Copied: docs/REUSABLE_COMPONENTS.md"
    ((FILES_COPIED++))
fi

# Create a README in the destination
cat > "$DEST_DIR/docs/SETUP_REUSABLE_COMPONENTS.md" << 'EOF'
# Reusable Components Setup Guide

This folder contains reusable components copied from the Twelve Step App project.

Repository: https://github.com/kasperstorm77/twelve_step_app

## Files Copied

### Services
- `lib/services/locale_provider.dart` - Locale state management
- `lib/services/app_switcher_service.dart` - Multi-app switching

### Models
- `lib/models/app_entry.dart` - App metadata model (Hive)

### Localization
- `lib/localizations.dart` - Translation system

## Quick Setup Checklist

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

**IMPORTANT:** Open `lib/models/app_entry.dart` and change the typeId to avoid conflicts:

```dart
// Change this:
@HiveType(typeId: 2)

// To an unused number in your project:
@HiveType(typeId: 10)  // Or any number not used elsewhere
```

### 3. Generate Hive Adapters

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will create `lib/models/app_entry.g.dart`

### 4. Register Adapters in main.dart

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'models/app_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(AppEntryAdapter());
  
  // Open settings box (used by AppSwitcherService)
  await Hive.openBox('settings');
  
  runApp(MyApp());
}
```

### 5. Setup LocaleProvider

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

### 6. Update Translations

Open `lib/localizations.dart` and replace the `localizedValues` map with your app's translations.

### 7. Update Available Apps

Open `lib/models/app_entry.dart` and modify `AvailableApps.getAll()` to return your apps.

## Next Steps

See `REUSABLE_COMPONENTS.md` for:
- Detailed integration examples
- UI component patterns
- Complete usage guide

## Removing Unused Components

If you don't need app switching:
- Delete `lib/services/app_switcher_service.dart`
- Delete `lib/models/app_entry.dart`
- Delete `lib/models/app_entry.g.dart` (after generation)

If you don't need localization:
- Delete `lib/localizations.dart`
- Delete `lib/services/locale_provider.dart`

---

**Generated by:** copy_reusable_components.sh
**Source:** Twelve Step App (https://github.com/kasperstorm77/twelve_step_app)
EOF

print_success "Created: docs/SETUP_REUSABLE_COMPONENTS.md"
((FILES_COPIED++))

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Copy complete! $FILES_COPIED files copied."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Next steps:"
echo "  1. cd $DEST_DIR"
echo "  2. Read: docs/SETUP_REUSABLE_COMPONENTS.md"
echo "  3. Read: docs/REUSABLE_COMPONENTS.md"
echo "  4. Update lib/models/app_entry.dart (change typeId!)"
echo "  5. Update lib/localizations.dart (your translations)"
echo "  6. Run: flutter pub get"
echo "  7. Run: flutter pub run build_runner build"
echo ""
print_warning "IMPORTANT: Change the Hive typeId in app_entry.dart to avoid conflicts!"
echo ""
