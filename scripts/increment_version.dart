#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

void main() async {
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  try {
    final content = await pubspecFile.readAsString();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('version:')) {
        final versionParts = line.split(': ')[1];
        final parts = versionParts.split('+');
        final versionNumber = parts[0];
        final buildNumber = int.parse(parts[1]);
        final newBuildNumber = buildNumber + 1;
        final newVersion = '$versionNumber+$newBuildNumber';

        lines[i] = 'version: $newVersion';

        print('Version incremented: $versionParts -> $newVersion');
        break;
      }
    }

    await pubspecFile.writeAsString(lines.join('\n'));
    print('pubspec.yaml updated successfully');
  } catch (e) {
    print('Error updating version: $e');
    exit(1);
  }
}
