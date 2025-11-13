# I Am Feature Implementation Progress

## Requirements Summary
Transform the app from a simple 5-field format to support contextual "I Am" definitions:

**Old Structure:**
- Resentment, Reason, Affect, Part, Defect

**New Structure:**  
- Resentment, Reason, **[Optional "I Am" context]**, Affect My, My Take, Shortcomings
- "+" button before "Affect My" to select/add "I Am" definition
- "I Am" definitions managed via CRUD in Settings tab
- Each "I Am" has optional "Reason to exist" field (shown via "?" tooltip)

## Completed Tasks ✅

### 1. Data Model
- ✅ Created `IAmDefinition` Hive model (typeId: 1)
  - Fields: id (String), name (String), reasonToExist (String?)
  - Generated adapter with build_runner
  
- ✅ Updated `InventoryEntry` model
  - Added @HiveField(5) String? iAmId (links to IAmDefinition)
  - Added convenience getters: myTake, shortcomings
  - Kept original field indices (3=part, 4=defect) for backward compatibility
  - Regenerated adapter

- ✅ Registered adapters in main.dart
  - Registered IAmDefinitionAdapter
  - Opened 'i_am_definitions' Hive box

### 2. Service Layer
- ✅ Created `IAmService`
  - CRUD operations for IAmDefinitions
  - UUID generation for IDs
  - Default "Sober member of AA" initialization
  - Initialized in main.dart

- ✅ Added uuid package dependency

## Remaining Tasks 📋

### 3. Settings Tab UI (Priority: HIGH)
**File**: `lib/pages/settings_tab.dart`

Replace placeholder with I Am management UI:
- List all I Am definitions (name + optional reason icon)
- Add button → Dialog with name & optional reason fields
- Edit icon per item → Same dialog pre-filled
- Delete icon per item → Confirmation dialog
- Show count of definitions

### 4. Form Tab UI (Priority: HIGH)  
**File**: `lib/pages/form_tab.dart`

Current fields to update:
- Keep: Resentment, Reason fields
- Add: "+" IconButton before "Affect" field
  - Opens dropdown to select I Am definition
  - Selected I Am shown above "Affect My" field
  - "?" icon next to I Am shows "Reason to exist" tooltip
- Rename labels:
  - "Affect" → "Affect My"  
  - "Part" → "My Take"
  - "Defect" → "Shortcomings"
- Update InventoryService calls to include iAmId

### 5. List Tab Display (Priority: MEDIUM)
**File**: `lib/pages/list_tab.dart`

- Update column headers:
  - "Part" → "My Take"
  - "Defect" → "Shortcomings"
- Optionally add "I Am" column (shows name if set)

### 6. Localizations (Priority: HIGH)
**File**: `lib/localizations.dart`

Add translations (en/da):
- `i_am`: "I Am" / "Jeg er"
- `my_take`: "My Take" / "Min opfattelse"
- `shortcomings`: "Shortcomings" / "Mangler"
- `reason_to_exist`: "Reason to exist" / "Grund til at eksistere"
- `add_i_am`: "Add I Am" / "Tilføj Jeg er"
- `edit_i_am`: "Edit I Am" / "Rediger Jeg er"
- `delete_i_am`: "Delete I Am" / "Slet Jeg er"
- `i_am_name`: "I Am name" / "Jeg er navn"
- `affect_my`: "Affects my" / "Påvirker min"
- `select_i_am`: "Select I Am" / "Vælg Jeg er"
- `no_i_am_selected`: "Standard (no I Am)" / "Standard (ingen Jeg er)"

### 7. CSV Import/Export (Priority: MEDIUM)
**File**: `lib/pages/data_management_tab.dart`

- Update CSV headers: Add "I Am" column
- Export: Include I Am name (not ID)
- Import: Look up I Am by name, create if doesn't exist
- Handle missing I Am gracefully

### 8. Testing (Priority: HIGH)
- Test I Am CRUD in settings
- Test form with/without I Am selection
- Test existing entries (should work without I Am)
- Test CSV export/import with I Am data
- Test Drive sync (should include I Am data)

## Technical Notes

### Backward Compatibility
- Old entries without iAmId will continue to work
- Field indices preserved (part=3, defect=4)
- New iAmId field is optional (nullable)

### Data Relationships
- InventoryEntry.iAmId → IAmDefinition.id (1-to-many)
- If IAmDefinition is deleted, entries keep the ID (orphaned)
  - Consider: Null out iAmId on I Am delete?
  - Or: Prevent delete if in use?

### Drive Sync
- I Am definitions need separate sync mechanism
- Or: Include in same JSON structure as entries
- Decision needed on sync strategy

## Files Modified So Far
- ✅ lib/models/i_am_definition.dart (created)
- ✅ lib/models/i_am_definition.g.dart (generated)
- ✅ lib/models/inventory_entry.dart (updated)
- ✅ lib/models/inventory_entry.g.dart (regenerated)
- ✅ lib/services/i_am_service.dart (created)
- ✅ lib/main.dart (updated)
- ✅ pubspec.yaml (added uuid)

## Next Steps
1. Update localizations with new keys
2. Implement Settings tab I Am CRUD UI
3. Update Form tab with I Am selection + renamed fields
4. Update List tab column headers
5. Test all functionality
6. Update CSV import/export
7. Test Drive sync
8. Update documentation (README, copilot-instructions)

## Commit Messages
- ✅ "Add I Am Definition model and service: new Hive model (typeId 1), update InventoryEntry with iAmId field, create IAmService for CRUD operations"
