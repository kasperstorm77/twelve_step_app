/// Which copy of the data is ahead — the device's, or the one in Drive.
///
/// There are two clocks: the `lastModified` key in the local `settings` box,
/// and the `lastModified` inside the newest backup in Drive. Startup used to
/// ask only one question of them — "is the remote newer?" — and act on it by
/// blocking uploads. The other direction was never asked, and that is how a
/// finished morning ritual could sit on a phone forever:
///
/// `scheduleUploadFromBox` starts a 1000 ms debounce timer. Put the phone down
/// inside that second, as people do the moment a ritual ends, and the process
/// is suspended before the timer fires. The upload is lost, and nothing retried
/// it — the next launch only ever checked whether the *remote* was ahead. The
/// entry stayed local-only until some unrelated edit happened to schedule
/// another upload.
///
/// Both directions now come from one comparison, so they can never disagree
/// about which side is ahead.
library;

enum SyncClockVerdict {
  /// Drive holds work this device does not. Block uploads and let the user
  /// decide — never overwrite local data automatically (hard rule 8).
  remoteNewer,

  /// This device holds work Drive does not. Safe to push: uploading cannot
  /// lose anything, because a backup is a new timestamped file, never an
  /// overwrite.
  localNewer,

  /// Nothing to do.
  inSync;

  /// Only a newer remote may stop uploads.
  bool get shouldBlockUploads => this == SyncClockVerdict.remoteNewer;

  /// Only a newer local copy is worth pushing. `inSync` must not re-upload, or
  /// every launch would write another backup for no reason.
  bool get shouldCatchUpUpload => this == SyncClockVerdict.localNewer;
}

/// Compare the two clocks.
///
/// Both are compared as instants, so a payload written with an offset and a
/// local clock stored as UTC still order correctly — `DateTime.isAfter`
/// compares absolute time, which a string or wall-clock comparison would not.
///
/// The missing-clock cases carry meaning:
/// * no local clock, a backup exists → the remote wins. A fresh install must
///   be offered the fetch; that behaviour predates this function and is
///   deliberately preserved.
/// * local work but no backup at all → push it. This is a device that has
///   never uploaded, which is exactly the state a lost first upload leaves.
/// * neither → nothing has happened yet.
SyncClockVerdict compareSyncClocks({
  required DateTime? local,
  required DateTime? remote,
}) {
  if (remote == null) {
    return local == null
        ? SyncClockVerdict.inSync
        : SyncClockVerdict.localNewer;
  }
  if (local == null) return SyncClockVerdict.remoteNewer;
  if (remote.isAfter(local)) return SyncClockVerdict.remoteNewer;
  if (local.isAfter(remote)) return SyncClockVerdict.localNewer;
  return SyncClockVerdict.inSync;
}
