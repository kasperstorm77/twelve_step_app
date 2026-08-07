import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/fourth_step/models/inventory_entry.dart';
import 'package:twelvestepsapp/shared/services/all_apps_drive_service.dart';

import 'support/hive_test_harness.dart';

/// "Never auto-overwrite local data" is hard rule 8, and it rests on three
/// things that are easy to undo by accident (implementation plan P3.3):
/// `checkAndSyncIfNeeded()` staying a no-op, `blockUploads()` actually
/// stopping uploads, and only an explicit unblock releasing them.
void main() {
  setUp(openAllBoxes);
  tearDown(() async {
    AllAppsDriveService.instance.unblockUploads();
    await closeAllBoxes();
  });

  test('checkAndSyncIfNeeded never restores anything', () async {
    await Hive.box<InventoryEntry>(
      'entries',
    ).add(InventoryEntry('Local work', null, null, null, null, id: 'local'));

    // ignore: deprecated_member_use_from_same_package
    final didSync = await AllAppsDriveService.instance.checkAndSyncIfNeeded();

    expect(
      didSync,
      isFalse,
      reason:
          'auto-restore is permanently disabled; a true here would mean local '
          'data can be replaced without the user asking',
    );
    expect(Hive.box<InventoryEntry>('entries').length, 1);
  });

  test('isRemoteNewer is inert when signed out', () async {
    // Nothing to compare against and no session, so it must answer "no" rather
    // than treat an unknown remote as newer.
    expect(AllAppsDriveService.instance.isAuthenticated, isFalse);
    expect(await AllAppsDriveService.instance.isRemoteNewer(), isFalse);
  });

  test('blockUploads stops uploads until the user explicitly unblocks', () async {
    final service = AllAppsDriveService.instance;
    expect(service.uploadsBlocked, isFalse);

    // This is what the startup conflict check does when the remote copy is
    // newer: block, then let the dialog decide. It must never restore here.
    service.blockUploads();
    expect(service.uploadsBlocked, isTrue);

    final blockedStates = <bool>[];
    final subscription = service.onUploadsBlockedChanged.listen(
      blockedStates.add,
    );

    // A mutation while blocked must not push local state over the newer remote.
    await Hive.box<InventoryEntry>(
      'entries',
    ).add(InventoryEntry('Written while blocked', null, null, null, null));
    service.scheduleUploadFromBox(Hive.box<InventoryEntry>('entries'));
    expect(service.uploadsBlocked, isTrue);

    // "Keep Local" is the only thing that clears it.
    service.unblockUploads();
    expect(service.uploadsBlocked, isFalse);

    await Future<void>.delayed(Duration.zero);
    expect(blockedStates, [false]);
    await subscription.cancel();
  });
}
