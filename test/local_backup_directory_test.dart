import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:twelvestepsapp/shared/services/local_backup_service.dart';
import 'package:twelvestepsapp/shared/utils/platform_helper.dart';

/// Fake path_provider that returns distinct documents vs. support paths so we
/// can assert *which* one the backup directory is rooted in.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider({required this.documentsPath, required this.supportPath});

  final String documentsPath;
  final String supportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;

  @override
  Future<String?> getTemporaryPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Directory docs;
  late Directory support;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('local_backup_dir_test');
    docs = Directory('${tmp.path}/Documents')..createSync();
    support = Directory('${tmp.path}/app_support')..createSync();
    PathProviderPlatform.instance = _FakePathProvider(
      documentsPath: docs.path,
      supportPath: support.path,
    );
    // The service is a process-wide singleton; re-arm the one-time migration
    // so each test exercises it against its own temp dirs.
    LocalBackupService.instance.resetLegacyMigrationForTesting();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('desktop local backups live in the app-private support dir, never the '
      'user\'s real Documents folder', () async {
    final dir = await LocalBackupService.instance
        .getBackupDirectoryForTesting();

    if (PlatformHelper.isDesktop) {
      // On desktop, getApplicationDocumentsDirectory() resolves to the real
      // ~/Documents (XDG). Backups must NOT be written there.
      expect(
        dir.path.startsWith(support.path),
        isTrue,
        reason: 'Desktop backups must be rooted in the app support dir.',
      );
      expect(
        dir.path.startsWith(docs.path),
        isFalse,
        reason: 'Desktop backups must not pollute the user Documents folder.',
      );
    } else {
      // Mobile's documents dir is already app-sandboxed — keep using it.
      expect(dir.path.startsWith(docs.path), isTrue);
    }
  });

  test(
    'existing backups in the legacy desktop Documents/backups are migrated out',
    () async {
      if (!PlatformHelper.isDesktop) return;

      // Simulate the old behaviour: a stray backup already in ~/Documents/backups.
      final legacy = Directory('${docs.path}/backups')..createSync();
      final strayName = 'twelve_steps_backup_2026-01-01_08-00-00.json';
      File('${legacy.path}/$strayName').writeAsStringSync('{}');

      final dir = await LocalBackupService.instance
          .getBackupDirectoryForTesting();

      // The stray file moved into the new app-private backup dir...
      expect(File('${dir.path}/$strayName').existsSync(), isTrue);
      // ...and the legacy Documents/backups folder is cleaned up.
      expect(legacy.existsSync(), isFalse);
    },
  );
}
