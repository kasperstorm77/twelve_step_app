# Build Scripts

This project includes automatic version increment scripts for Flutter builds.

## Scripts Available

### Windows
- `build_increment.bat` - Batch script (recommended for Windows)
- `build_increment.ps1` - PowerShell script
- `build_increment.sh` - Bash script (for Git Bash/WSL)

## Usage

### Basic Usage
```bash
# Debug build (default)
build_increment.bat

# Release APK
build_increment.bat release

# Release App Bundle
build_increment.bat appbundle
```

### What it does
1. Reads the current version from `pubspec.yaml`
2. Increments the build number (the part after the `+`)
3. Updates `pubspec.yaml` with the new version
4. Builds the Flutter app with the specified type

### Example
If your current version is `1.0.1+1`, after running the script it will become `1.0.1+2`.

## Version Detection in App

The app automatically detects new installations and updates using the `AppVersionService`:

- **New Installation**: When the app is installed for the first time, it will prompt to fetch data from Google Drive if the user is signed in
- **App Update**: When the app version changes, it will also prompt for Google Drive sync
- **Debug Mode**: Additional console output shows version detection details

## Manual Version Updates

You can still manually update the version in `pubspec.yaml`:
```yaml
version: 1.0.1+1  # major.minor.patch+buildNumber
```

The version format follows semantic versioning with a build number suffix.