import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/shared/services/sync_clocks.dart';

/// A finished ritual that never reached Drive (found 2026-08-07).
///
/// A morning ritual was completed on a phone and did not appear on the desktop
/// after an explicit Fetch. The desktop was right: the newest backup in Drive
/// predated the ritual, because the phone never uploaded it.
///
/// `saveEntry` does call `scheduleUploadFromBox`, but that only starts a
/// **1000 ms debounce timer**. Put the phone down inside that second — which is
/// exactly what someone does when they finish a morning ritual — and the
/// process is suspended before the timer fires. The upload is simply lost, and
/// nothing ever retried it: startup only ever *blocked* uploads when the remote
/// was newer, and there was no path anywhere that pushed when the **local**
/// copy was newer. The entry stayed on the phone until some unrelated edit
/// happened to trigger another upload.
///
/// This pins the comparison both directions now use.
void main() {
  final earlier = DateTime.utc(2026, 8, 6, 10, 32, 22);
  final later = DateTime.utc(2026, 8, 7, 6, 15, 0);

  group('which side is ahead', () {
    test('remote ahead of local is remoteNewer', () {
      expect(
        compareSyncClocks(local: earlier, remote: later),
        SyncClockVerdict.remoteNewer,
      );
    });

    test('local ahead of remote is localNewer — the case that was missing', () {
      expect(
        compareSyncClocks(local: later, remote: earlier),
        SyncClockVerdict.localNewer,
      );
    });

    test('identical timestamps are inSync', () {
      expect(
        compareSyncClocks(local: later, remote: later),
        SyncClockVerdict.inSync,
      );
    });
  });

  group('missing clocks', () {
    test('no local timestamp means the remote wins', () {
      // Preserves isRemoteNewer()'s long-standing behaviour: a fresh install
      // with a backup in Drive must be offered the fetch.
      expect(
        compareSyncClocks(local: null, remote: later),
        SyncClockVerdict.remoteNewer,
      );
    });

    test('no remote backup but local work exists means we should upload', () {
      expect(
        compareSyncClocks(local: later, remote: null),
        SyncClockVerdict.localNewer,
      );
    });

    test('neither side has anything is inSync, not an upload', () {
      expect(
        compareSyncClocks(local: null, remote: null),
        SyncClockVerdict.inSync,
      );
    });
  });

  group('the verdict drives the two actions', () {
    test('only remoteNewer blocks uploads', () {
      expect(SyncClockVerdict.remoteNewer.shouldBlockUploads, isTrue);
      expect(SyncClockVerdict.localNewer.shouldBlockUploads, isFalse);
      expect(SyncClockVerdict.inSync.shouldBlockUploads, isFalse);
    });

    test('only localNewer triggers a catch-up upload', () {
      expect(SyncClockVerdict.localNewer.shouldCatchUpUpload, isTrue);
      expect(SyncClockVerdict.remoteNewer.shouldCatchUpUpload, isFalse);
      expect(
        SyncClockVerdict.inSync.shouldCatchUpUpload,
        isFalse,
        reason: 'an equal clock must not re-upload on every launch',
      );
    });
  });

  test('timezones do not decide the winner', () {
    // The local clock is written as UTC but a payload may carry an offset; a
    // naive string or wall-clock comparison would flip these.
    final utc = DateTime.utc(2026, 8, 7, 6, 0);
    final sameInstantElsewhere = DateTime.parse('2026-08-07T08:00:00+02:00');
    expect(
      compareSyncClocks(local: utc, remote: sameInstantElsewhere),
      SyncClockVerdict.inSync,
    );

    final aMinuteLater = DateTime.parse('2026-08-07T08:01:00+02:00');
    expect(
      compareSyncClocks(local: utc, remote: aMinuteLater),
      SyncClockVerdict.remoteNewer,
    );
  });
}
