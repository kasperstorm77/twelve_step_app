# Design Specification: Agnosticism & Spiritual Experience Tracker

## 1. Overview
This new app module is designed to support the user's journey through "Current Agnosticism" based on principles often discussed by Mark Houston (smashing old ideas/prejudices to make room for new spiritual experiences).

The app will allow users to:
1.  **Identify & Deconstruct Barriers**: List and examine prejudices, old ideas, or intellectual hurdles regarding a Higher Power.
2.  **Track Spiritual Experiences**: Document daily evidence, "God shots," or moments of clarity that build a new conception.

## 2. Architecture
The module will follow the existing modular architecture of the project (`lib/agnosticism/`).

### Directory Structure
```
lib/agnosticism/
├── models/
│   ├── barrier.dart          (HiveType: 10)
│   └── experience.dart       (HiveType: 11)
├── pages/
│   ├── agnosticism_home.dart (Main Entry with App Switcher)
│   ├── forms/
│   │   ├── barrier_form.dart
│   │   └── experience_form.dart
│   └── lists/
│       ├── barrier_list.dart
│       └── experience_list.dart
├── services/
│   ├── agnosticism_service.dart (CRUD logic)
│   └── agnosticism_drive_service.dart (Sync logic)
└── agnosticism_module.dart
```

## 3. Data Models

### A. Barrier (The "Old Idea")
Represents a prejudice or intellectual block.
*   **id**: String (UUID)
*   **label**: String (e.g., "Organized Religion", "The word 'God'")
*   **description**: String (Details about why this is a barrier)
*   **isSmashed**: Boolean (Has this idea been set aside?)
*   **newPerspective**: String (The updated view, if any)
*   **createdAt**: DateTime

### B. Experience (The "New Evidence")
Represents a moment of spiritual utility or connection.
*   **id**: String (UUID)
*   **date**: DateTime
*   **event**: String (What happened?)
*   **significance**: String (Why was this spiritual?)
*   **tags**: List<String> (e.g., "Nature", "Coincidence", "Service")

## 4. User Interface

### Main Screen (`AgnosticismHome`)
Standard Scaffold with:
*   **AppBar**: Title, App Switcher, Settings, Language.
*   **TabBar**:
    1.  **Deconstruction** (Managing Barriers)
    2.  **Reconstruction** (Tracking Experiences)

### Tab 1: Deconstruction (Barriers)
*   **List View**:
    *   Items divided into "Active Barriers" and "Smashed Ideas".
    *   Swipe to delete or toggle "Smashed".
    *   Tap to edit/refine.
*   **Floating Action Button**: Add new Barrier.

### Tab 2: Reconstruction (Experiences)
*   **Timeline View**: Reverse chronological list of experiences.
*   **Form**:
    *   Date picker.
    *   "What happened?" (Text Area).
    *   "What did it mean?" (Text Area).

## 5. Integration & Requirements

### Localization
*   New keys in `lib/shared/localizations.dart`:
    *   `agnosticism_title`
    *   `barriers_tab`
    *   `experiences_tab`
    *   `add_barrier`
    *   `barrier_smashed`
    *   etc.

### Storage & Sync
*   **Hive**: Two new boxes `agnosticism_barriers` and `agnosticism_experiences`.
*   **Drive Sync**: Implement `DriveService` extension to handle JSON export/import of these new boxes (consistent with `inventory_drive_service.dart`).
*   **Data Management**: Add export/import/delete buttons in the Settings -> Data Management screen.

### App Switcher
*   Add `agnosticism` entry to `AvailableApps` in `lib/shared/models/app_entry.dart`.

## 6. Questions for Approval
1.  Is "Deconstruction" (Barriers) and "Reconstruction" (Experiences) the correct framing for your "Current Agnosticism" concept?
2.  Are there specific fields missing from the "Barrier" or "Experience" models that are crucial to Mark Houston's specific method?
3.  Do you have preferred terminology for the tab titles (e.g., "Doubts vs Data")?
