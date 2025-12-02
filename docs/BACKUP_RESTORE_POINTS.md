# Google Drive Backup & Restore Points

## Overview

The app now maintains **daily dated backups** on Google Drive with a **3-day rolling history**. Users can restore from any backup point within the last 3 days. All 6 apps sync to a single backup file.

## How It Works

### Automatic Dated Backups

When data syncs to Google Drive, the system:

1. **Creates dated backup** - Saves file with date suffix (e.g., `aa4step_inventory_data_2025-11-23.json`)
2. **Maintains current file** - Also updates `aa4step_inventory_data.json` for backward compatibility
3. **Cleans up old backups** - Automatically deletes backups older than 3 days

### Backup File Naming

```
aa4step_inventory_data_2025-11-23.json  (Today's backup)
aa4step_inventory_data_2025-11-22.json  (Yesterday's backup)
aa4step_inventory_data_2025-11-21.json  (2 days ago backup)
aa4step_inventory_data.json             (Current file - always latest)
```

### Restore Point Selection

Users can select which backup to restore from:

- **Latest (Current)** - Restores from the main current file
- **2025-11-23** - Restores from today's backup
- **2025-11-22** - Restores from yesterday's backup
- **2025-11-21** - Restores from 2 days ago backup

## User Interface

### Backup Selection Card (Data Management Tab)

Located above the "Clear All" button when signed into Google Drive:

```
┌─────────────────────────────────────────┐
│ 🔄 Select Restore Point         [Refresh]│
│                                           │
│ ┌───────────────────────────────────────┐│
│ │ 📅 Latest (Current)              ▼   ││
│ └───────────────────────────────────────┘│
│                                           │
│ [ ⬇️ Restore from Backup ]               │
└─────────────────────────────────────────┘
```

**Dropdown Options:**
- 📅 **Latest (Current)** - Most recent sync
- 🕒 **2025-11-23** - Today's dated backup
- 🕒 **2025-11-22** - Yesterday's dated backup
- 🕒 **2025-11-21** - Backup from 2 days ago

**Refresh Button:** Reloads available backups from Drive

## Technical Implementation

### Modified Services

#### 1. `GoogleDriveCrudClient`
New methods:
- `findBackupFiles(String fileNamePattern)` - List all dated backup files
- `createDatedBackupFile(String content, DateTime date)` - Create backup with date suffix
- `readBackupFile(String fileName)` - Read specific backup by name

#### 2. `MobileDriveService`
New methods:
- `_createDatedBackup(String content)` - Create today's backup
- `_cleanupOldBackups()` - Delete backups older than 7 days
- `listAvailableBackups()` - Return list of available backups with dates
- `downloadBackupContent(String fileName)` - Download specific backup

Modified methods:
- `uploadContent()` - Now creates dated backup + updates current file

#### 3. `AllAppsDriveService`
New methods:
- `listAvailableBackups()` - Expose backup listing
- `downloadBackupContent(String fileName)` - Expose backup download

#### 4. `DriveService` (Legacy Wrapper)
New methods:
- `listAvailableBackups()` - Delegate to new service
- `downloadBackupContent(String fileName)` - Delegate to new service

### UI Changes (`data_management_tab.dart`)

New state variables:
```dart
List<Map<String, dynamic>> _availableBackups = [];
String? _selectedBackupFileName;
bool _loadingBackups = false;
```

New methods:
```dart
Future<void> _loadAvailableBackups() // Load backups on init/sign-in
```

Modified methods:
```dart
Future<void> _fetchFromGoogle() // Now uses selected backup or current file
```

### Localization Keys

**English (`en`):**
- `select_restore_point` - "Select Restore Point"
- `restore_point_latest` - "Latest (Current)"
- `restore_from_backup` - "Restore from Backup"
- `loading_backups` - "Loading backups..."
- `no_backups_available` - "No backups available"

**Danish (`da`):**
- `select_restore_point` - "Vælg Gendannelsespunkt"
- `restore_point_latest` - "Seneste (Nuværende)"
- `restore_from_backup` - "Gendan fra Backup"
- `loading_backups` - "Indlæser backups..."
- `no_backups_available` - "Ingen backups tilgængelige"

## Usage Flow

### Creating Backups

Backups are created automatically when:
1. User manually uploads to Drive
2. Auto-sync triggers after data changes
3. User adds/edits/deletes entries in any of the 6 apps

### Restoring from Backup

1. **Sign in** to Google Drive (mobile only)
2. Navigate to **Data Management** tab
3. Card shows **"Select Restore Point"**
4. **Dropdown** displays available backups (last 3 days)
5. Select desired restore point
6. Tap **"Restore from Backup"**
7. Confirm overwrite warning
8. Data restores from selected backup

### Backup Cleanup

- Runs automatically after each sync
- Deletes backups older than **3 days**
- Keeps exactly **3-4 backup files** (today + last 2-3 days depending on timing)
- Current file (`aa4step_inventory_data.json`) always remains

## Data Safety

### Multiple Restore Points
- **Protection against accidental deletion** - Restore yesterday's data if today's was corrupted
- **Recovery from bad imports** - Roll back to pre-import state
- **Undo sync mistakes** - Revert to earlier backup if sync caused issues

### Automatic Cleanup
- Prevents Drive quota bloat (JSON files are small ~10-50KB each)
- Rolling window ensures recent history without indefinite accumulation

### Backward Compatibility
- Main file (`aa4step_inventory_data.json`) still updated on every sync
- Older app versions without backup feature continue to work normally
- Dated backups are additional safety net, not replacement for current file

## Example Scenarios

### Scenario 1: Accidental Data Deletion
1. User accidentally clears all entries at 2pm
2. Realizes mistake at 3pm
3. Opens Data Management → Select Restore Point
4. Chooses yesterday's backup (`2025-11-22`)
5. Restores → Data from yesterday is back

### Scenario 2: Bad JSON Import
1. User imports corrupted JSON file that breaks data at 4pm
2. App becomes unusable
3. Selects restore point from earlier today (before import)
4. Restores → Clean data from this morning restored

### Scenario 3: Rolling Back After Testing
1. Sponsor suggests trying aggressive 4th step approach
2. User enters many test entries over 2 days
3. Decides original approach was better
4. Restores from backup 2 days ago
5. All test entries removed, original data intact

## Future Enhancements (Not Implemented)

Potential additions:
- Longer retention (7 days, 30 days, etc.) - configurable
- Manual backup creation with custom labels
- Backup comparison view (see what changed between dates)
- Backup metadata (entry count, last modified time in list)
- Export backups to local JSON files
- Cloud storage provider options (Dropbox, iCloud, etc.)

## Platform Support

- ✅ **Android** - Full support
- ✅ **iOS** - Full support
- ❌ **Desktop** - Manual Drive sync only (no dated backups)

Desktop users must use manual JSON export/import for backup needs.

## Testing Checklist

- [x] Create dated backup on sync
- [x] List available backups in dropdown
- [x] Restore from selected backup
- [x] Restore from "Latest" (current file)
- [x] Cleanup old backups (>3 days)
- [x] Refresh backups button works
- [x] Loading state displays correctly
- [x] Empty state when no backups
- [x] Localization (EN/DA) displays correctly
- [x] Backward compatibility (main file still updated)
