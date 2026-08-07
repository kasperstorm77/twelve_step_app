import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// The platform sounds a `RitualItem.soundId` resolves to.
///
/// `soundId` is persisted (Hive field 10) and synced, and the item editor has
/// offered these four choices for a long time — but the runner used to play the
/// system alarm regardless, so the dropdown did nothing (historic Phase 21).
class AlarmSound {
  const AlarmSound({
    required this.android,
    required this.ios,
    required this.asAlarm,
  });

  final AndroidSound android;
  final IosSound ios;

  /// Whether to route through the alarm audio stream. Only the alarm choice
  /// does; a notification or ringtone should follow its own stream volume, or
  /// a user who picked the quiet option still gets a full-volume alarm.
  final bool asAlarm;
}

/// Maps a stored `soundId` to the sound to play.
///
/// The four values are frozen by what the editor writes and what backups from
/// either app may carry: `null` (system default), `system_default_notification`,
/// `system_default_alarm`, `system_default_ringtone`. An unrecognised value —
/// which a future version of the other app could introduce — falls back to the
/// alarm rather than going silent.
AlarmSound alarmSoundFor(String? soundId) {
  switch (soundId) {
    case 'system_default_notification':
      return const AlarmSound(
        android: AndroidSounds.notification,
        ios: IosSounds.triTone,
        asAlarm: false,
      );
    case 'system_default_ringtone':
      return const AlarmSound(
        android: AndroidSounds.ringtone,
        ios: IosSounds.bell,
        asAlarm: false,
      );
    case 'system_default_alarm':
    case null:
    default:
      return const AlarmSound(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        asAlarm: true,
      );
  }
}
