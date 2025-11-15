# VS Code Debug with Auto Version Increment

This project is configured to automatically increment the build number when starting debug sessions in VS Code.

## How It Works

When you press **F5** in VS Code:

1. The `increment-version` task runs first (pre-launch task)
2. This executes `dart scripts/increment_version.dart`
3. The script reads `pubspec.yaml` and increments the build number
4. The Flutter debug session starts with the new version

## Available Debug Configurations

1. **"Debug with Auto Version Increment"** (default) - Increments version automatically
2. **"Debug (Standard)"** - Standard debug without version increment

## Manual Version Increment

You can also run the version increment manually:

```bash
dart run scripts/increment_version.dart
```

## Version Format

The version follows the format: `major.minor.patch+buildNumber`

Example: `1.0.1+6` → `1.0.1+7`

Only the build number (after the `+`) is incremented automatically.