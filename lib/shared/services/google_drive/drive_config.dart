// --------------------------------------------------------------------------
// Google Drive Core Configuration
// --------------------------------------------------------------------------

/// Configuration for Google Drive integration
class GoogleDriveConfig {
  final String fileName;
  final String mimeType;
  final String scope;
  final String? parentFolder;

  const GoogleDriveConfig({
    required this.fileName,
    required this.mimeType,
    this.scope = 'https://www.googleapis.com/auth/drive.appdata',
    this.parentFolder, // null means root, 'appDataFolder' for app data
  });

  /// Default configuration for app data folder storage
  static const appDataConfig = GoogleDriveConfig(
    fileName: 'app_data.json',
    mimeType: 'application/json',
    scope: 'https://www.googleapis.com/auth/drive.appdata',
    parentFolder: 'appDataFolder',
  );

  /// Configuration for regular Drive storage
  static const driveConfig = GoogleDriveConfig(
    fileName: 'app_data.json',
    mimeType: 'application/json',
    scope: 'https://www.googleapis.com/auth/drive.file',
    parentFolder: null,
  );
}
