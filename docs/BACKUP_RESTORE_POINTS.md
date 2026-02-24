# Google Drive Backup & Restore Points

## Overview

The app maintains **timestamped backups** on Google Drive. All 6 apps sync to a single backup file with the following retention policy:

- **Today**: All backups with timestamps (e.g., `twelve_steps_backup_2025-12-03_14-30-15.json`)
- **Previous 7 days**: One backup per day (the latest from that day)
- **Previous 12 months** (outside last week): One backup per month (the latest from that month)
- **Older than 12 months**: Automatically deleted

## How It Works

### Automatic Timestamped Backups

When data syncs to Google Drive, the system:

1. **Creates timestamped backup** - Saves file with date and time (e.g., `twelve_steps_backup_2025-12-03_14-30-15.json`)
2. **Cleans up old backups** - Enforces retention policy (today all, weekly daily, monthly for year)

### Backup File Naming

```
twelve_steps_backup_2025-12-03_14-30-15.json  (Today 2:30:15 PM)
twelve_steps_backup_2025-12-03_10-15-42.json  (Today 10:15:42 AM)
twelve_steps_backup_2025-12-02.json           (Yesterday - single backup)
twelve_steps_backup_2025-12-01.json           (2 days ago - single backup)
twelve_steps_backup_2025-11-30.json           (Last week - single backup)
twelve_steps_backup_2025-11-15.json           (November - monthly backup)
twelve_steps_backup_2025-10-28.json           (October - monthly backup)
...
```

Note: Previous days keep one backup per day. Previous months (outside last week) keep one backup per month.

### Restore Point Selection

Users can select which backup to restore from:

- **2025-12-03 14:30** - Today's backup at 2:30 PM
- **2025-12-03 10:15** - Today's backup at 10:15 AM  
- **2025-12-02** - Yesterday's backup
- **2025-12-01** - 2 days ago backup
- **2025-11-15** - November's monthly backup
- **2025-10-28** - October's monthly backup

## User Interface

### Backup Selection Card (Data Management Tab)

Located in the Data Management settings when signed into Google Drive:

```
┌─────────────────────────────────────────┐
│ 🔄 Select Restore Point         [Refresh]│
│                                           │
│ ┌───────────────────────────────────────┐│
│ │ 📅 2025-12-03 14:30              ▼   ││
│ └───────────────────────────────────────┘│
│                                           │
│ [ ⬇️ Restore from Backup ]               │
└─────────────────────────────────────────┘
```

**Dropdown Options:**
- 🕒 **2025-12-03 14:30** - Today's latest backup
- 🕒 **2025-12-03 10:15** - Earlier today
- 🕒 **2025-12-02** - Yesterday's backup
- 🕒 **2025-12-01** - 2 days ago

**Refresh Button:** Reloads available backups from Drive

## Technical Implementation

### JSON Format (v7.0)

```json
{
  "version": "7.0",
  "exportDate": "2025-12-03T14:30:15.123Z",
  "lastModified": "2025-12-03T14:30:15.123Z",
  "iAmDefinitions": [...],
  "entries": [...],
  "people": [...],
  "reflections": [...],
  "gratitude": [...],
  "agnosticism": [...],
  "morningRitualItems": [...],
  "morningRitualEntries": [...]
}
```

### Services

#### `MobileDriveService` (Android/iOS)
- `uploadContent(content)` - Creates timestamped backup, then cleans up
- `_createDatedBackup(content)` - Creates backup file with timestamp
- `_cleanupOldBackups()` - Enforces retention policy
- `listAvailableBackups()` - Returns list of available backups
- `downloadBackupContent(fileName)` - Downloads specific backup

#### `WindowsDriveService` (Windows)
- Same methods as mobile, uses loopback OAuth for authentication

#### `AllAppsDriveService` (Main entry point)
- `listAvailableBackups()` - Delegates to platform service
- `downloadBackupContent(fileName)` - Delegates to platform service

### Filename Pattern

```dart
// Generated filename format:
final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
final timeStr = '${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}-${date.second.toString().padLeft(2, '0')}';
final datedFileName = 'twelve_steps_backup_${dateStr}_$timeStr.json';
// Example: twelve_steps_backup_2025-12-03_14-30-15.json
```

### Cleanup Logic

```dart
// Retention policy:
// - Today: keep ALL backups (multiple timestamps)
// - Previous 7 days: keep only ONE backup per day (latest)
// - Previous 12 months (outside last week): keep only ONE backup per month (latest)
// - Older than 12 months: DELETE

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
final weekCutoff = today.subtract(const Duration(days: 7));
final yearCutoff = DateTime(now.year - 1, now.month, now.day);

// Group backups by date and by month
final backupsByDate = <DateTime, List<Map<String, dynamic>>>{};
final backupsByMonth = <String, List<Map<String, dynamic>>>{};

// Track which backups to keep
final backupsToKeep = <String>{};

// Today: keep all backups
// Last 7 days: keep latest per day
for (final entry in backupsByDate.entries) {
  final date = entry.key;
  final dateBackups = entry.value;
  
  if (date.isAtSameMomentAs(today) || date.isAfter(today)) {
    // Today: keep all
    for (final backup in dateBackups) {
      backupsToKeep.add(backup['fileName']);
    }
  } else if (date.isAfter(weekCutoff)) {
    // Last 7 days: keep only the latest per day
    dateBackups.sort((a, b) => b['date'].compareTo(a['date']));
    backupsToKeep.add(dateBackups.first['fileName']);
  }
}

// Monthly backups (older than 7 days, within last year)
for (final entry in backupsByMonth.entries) {
  final monthBackups = entry.value;
  
  final eligibleBackups = monthBackups.where((backup) {
    final dateOnly = DateTime(backup['date'].year, backup['date'].month, backup['date'].day);
    return dateOnly.isBefore(weekCutoff) && dateOnly.isAfter(yearCutoff);
  }).toList();
  
  if (eligibleBackups.isNotEmpty) {
    eligibleBackups.sort((a, b) => b['date'].compareTo(a['date']));
    backupsToKeep.add(eligibleBackups.first['fileName']);
  }
}

// Delete all backups not in the keep set
for (final backup in backups) {
  if (!backupsToKeep.contains(backup['fileName'])) {
    await _deleteBackup(backup['fileName']);
  }
}
```

## Usage Flow

### First-Time Sign-In (Fresh Install)

When a user signs in to Google Drive for the first time on a fresh install:

1. **Sign in** to Google Drive in Data Management
2. **Prompt dialog appears** asking if user wants to fetch existing data from Drive
3. **User chooses:**
   - **"Fetch"** - Downloads latest backup from Drive (recommended for restoring to new device)
   - **"Cancel"** - Skips fetch, starts fresh (sync will be enabled for future uploads)
4. Sync is automatically enabled after the prompt

This prompt only appears once per installation. Users can always manually restore from any backup point later.

### Creating Backups

Backups are created automatically when:
1. Auto-sync triggers after data changes (700ms debounce)
2. User manually backs up via Data Management

### Restoring from Backup

1. **Sign in** to Google Drive
2. Navigate to **Settings → Data Management**
3. **Dropdown** displays available backups
4. Select desired restore point
5. Tap **"Restore from Backup"**
6. Confirm overwrite warning
7. Data restores from selected backup

## Data Safety

### Multiple Restore Points
- **Protection against accidental deletion** - Restore from earlier today or yesterday
- **Recovery from bad imports** - Roll back to pre-import state
- **Undo sync mistakes** - Revert to earlier backup
- **Long-term recovery** - Monthly backups for up to a year

### Automatic Cleanup
- Prevents Drive quota bloat
- Rolling 7-day window with daily granularity
- Rolling 12-month window with monthly granularity
- Today keeps all changes for granular recovery

## Example Scenarios

### Scenario 1: Accidental Data Deletion
1. User accidentally clears entries at 2pm
2. Realizes mistake at 3pm
3. Opens Data Management → Select Restore Point
4. Chooses today's 1pm backup (`2025-12-03 13:00`)
5. Restores → Data from before deletion is back

### Scenario 2: Multiple Changes Today
1. User makes changes at 9am, 12pm, and 3pm
2. Each change creates a new timestamped backup
3. User can restore to any of these points
4. Tomorrow, only the 3pm backup (latest) will remain

### Scenario 3: Weekly Recovery
1. User notices data issue on Monday
2. Checks restore points - sees backups for last 7 days
3. Restores from Thursday's backup
4. Issue resolved

### Scenario 4: Monthly Recovery
1. User notices data issue in December
2. Checks restore points - sees monthly backups for the past year
3. Restores from September's monthly backup
4. Long-term data recovered

## Platform Support

- ✅ **Android** - Full support
- ✅ **iOS** - Full support  
- ✅ **Windows** - Full support (loopback OAuth)

## Migration Notes

### From v6.0 to v7.0
- Added `morningRitualItems` and `morningRitualEntries` fields
- Changed filename from `aa4step_inventory_data.json` to `twelve_steps_backup.json`
- Removed backward compatibility main file (only timestamped backups now)

### Upgrading Users
- Existing `aa4step_inventory_data*.json` files will remain but won't be updated
- New backups use `twelve_steps_backup_*.json` naming
- Manual migration: Export from old app version, import into new version
