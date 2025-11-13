# Data Safety & Loss Prevention

## Implemented Safeguards

### 1. I Am Deletion Protection ✅
**Location:** `lib/pages/settings_tab.dart` - `_confirmDelete()`

**Protection:**
- Cannot delete an I Am definition if it's referenced by any entries
- Shows count of affected entries
- Requires user to manually change/remove I Am from entries first

**Test:**
1. Create an I Am definition (e.g., "Test Role")
2. Create an entry and assign "Test Role" to it
3. Try to delete "Test Role" from Settings
4. **Expected:** Warning dialog saying it's used by 1 entry
5. Edit the entry and remove the I Am
6. Now deletion should work

### 2. JSON Import Warning ✅
**Location:** `lib/pages/data_management_tab.dart` - `_importJson()`

**Protection:**
- Shows warning dialog before importing
- Clearly states that ALL current data will be replaced
- Recommends exporting current data first
- Requires explicit confirmation

**Test:**
1. Click "Import from JSON"
2. **Expected:** Warning dialog appears
3. Click "Cancel" - no data should be affected
4. Click "Import" - then file picker opens

### 3. Drive Fetch Warning ✅
**Location:** `lib/pages/data_management_tab.dart` - Built into UI

**Protection:**
- Warning dialog confirms overwriting local data
- Already implemented in existing code

**Test:**
1. Click "Fetch from Google Drive"
2. **Expected:** Confirmation dialog appears

### 4. Order of Operations ✅
**Location:** All import/export functions

**Protection:**
- **Export:** I Am definitions exported BEFORE entries
- **Import:** I Am definitions imported BEFORE entries
- Ensures I Am IDs exist when entries reference them

**Test:**
1. Create I Am definitions and entries
2. Export to JSON
3. **Expected:** JSON structure shows iAmDefinitions array before entries array
4. Import the JSON
5. **Expected:** I Am definitions appear in Settings
6. **Expected:** Entries show correct I Am in list view

### 5. Backward Compatibility ✅
**Location:** `lib/models/inventory_entry.dart` - `fromJson()`

**Protection:**
- `iAmId` field is optional (nullable)
- Old entries without `iAmId` load successfully
- No errors when importing old JSON format

**Test:**
1. Create JSON with old format (no iAmId field):
```json
{
  "version": "1.0",
  "entries": [
    {
      "resentment": "Test",
      "reason": "Test reason",
      "affect": "Test affect",
      "part": "Test part",
      "defect": "Test defect"
    }
  ]
}
```
2. Import this JSON
3. **Expected:** Entry loads without errors
4. **Expected:** No I Am assigned to the entry

### 6. NULL Safety ✅
**Location:** `lib/pages/list_tab.dart` - `_getIAmName()`

**Protection:**
- Handles missing I Am definitions gracefully
- Shows "-" in table view if I Am not found
- Doesn't show I Am line in card view if null

**Test:**
1. Manually corrupt data (edit Hive box, delete I Am but keep entry)
2. View entry in list
3. **Expected:** Shows "-" instead of crashing

## Data Flow Diagram

```
Export Flow:
1. User clicks Export
2. Read entries box
3. Read i_am_definitions box
4. Build JSON: {iAmDefinitions: [...], entries: [...]}
5. Save to file

Import Flow:
1. User clicks Import
2. Show warning dialog
3. User selects file
4. Parse JSON
5. Clear i_am_definitions box
6. Import I Am definitions (restore IDs)
7. Clear entries box
8. Import entries (with iAmId references)
9. Show success message

Drive Sync Upload:
1. Same as Export Flow
2. Upload JSON to Drive appDataFolder

Drive Sync Download:
1. Same as Import Flow steps 4-8
2. Fetch from Drive appDataFolder
```

## Potential Data Loss Scenarios

### ❌ PREVENTED: Deleting in-use I Am
**Risk:** Orphaned entries with invalid iAmId
**Prevention:** Delete protection checks usage count

### ❌ PREVENTED: Importing without warning
**Risk:** Accidental overwrite of all data
**Prevention:** Confirmation dialog with clear warning

### ❌ PREVENTED: Wrong import order
**Risk:** Entries referencing non-existent I Am IDs
**Prevention:** I Am definitions imported before entries

### ⚠️ PARTIAL: Data corruption
**Risk:** Hive database corruption
**Prevention:** 
- JSON export/import provides backup mechanism
- Drive sync provides cloud backup
- **Recommendation:** Regular exports

### ⚠️ PARTIAL: Concurrent modifications
**Risk:** Multiple devices modifying Drive data
**Prevention:**
- Last write wins (Drive overwrites)
- **Recommendation:** Use one device at a time

## Testing Checklist

- [ ] Create I Am → Create Entry → Try to delete I Am (should fail)
- [ ] Export JSON → Verify I Am definitions in file
- [ ] Import JSON → Verify warning dialog
- [ ] Import old JSON (no iAmId) → Verify no errors
- [ ] Drive sync → Upload → Download → Verify I Ams preserved
- [ ] Delete unused I Am → Should succeed
- [ ] Edit entry → Change I Am → Verify persistence
- [ ] Table view with missing I Am → Shows "-"
- [ ] Import replaces ALL data (not merge)
- [ ] Export includes timestamp in filename

## Recommendations for Users

1. **Export regularly** - Use "Export to JSON" as backup
2. **Export before import** - Always export current data first
3. **One device** - Avoid concurrent Drive sync from multiple devices
4. **Test imports** - Import on test device first if unsure
5. **Check I Am usage** - Before deleting, check if it's used

## Future Enhancements

1. **Merge Import** - Option to merge instead of replace
2. **Orphan Cleanup** - Auto-detect and fix orphaned iAmId references
3. **Version Migration** - Auto-upgrade old data formats
4. **Conflict Resolution** - Handle concurrent Drive modifications
5. **Incremental Backup** - Only sync changes, not full replace
