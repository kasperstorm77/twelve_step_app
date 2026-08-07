import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/morning_ritual/services/alarm_sound.dart';

/// `RitualItem.soundId` actually selects a sound (implementation plan P2.1).
///
/// The value has been persisted and synced for a long time, and the item editor
/// has offered all four choices — but the runner played the system alarm
/// whatever was stored, so the dropdown did nothing.
void main() {
  test('the default and the explicit alarm both use the alarm stream', () {
    for (final id in [null, 'system_default_alarm']) {
      final sound = alarmSoundFor(id);
      expect(sound.android, AndroidSounds.alarm);
      expect(sound.ios, IosSounds.alarm);
      expect(sound.asAlarm, isTrue, reason: 'for id: $id');
    }
  });

  test(
    'notification and ringtone pick their own sound, off the alarm stream',
    () {
      final notification = alarmSoundFor('system_default_notification');
      expect(notification.android, AndroidSounds.notification);
      expect(
        notification.asAlarm,
        isFalse,
        reason:
            'routing the quiet choice through the alarm stream would play it at '
            'full alarm volume anyway',
      );

      final ringtone = alarmSoundFor('system_default_ringtone');
      expect(ringtone.android, AndroidSounds.ringtone);
      expect(ringtone.asAlarm, isFalse);
    },
  );

  test('the four choices are actually distinguishable', () {
    final sounds = [
      null,
      'system_default_notification',
      'system_default_alarm',
      'system_default_ringtone',
    ].map(alarmSoundFor).map((s) => s.android.value).toSet();

    // null and system_default_alarm intentionally coincide; the other two must
    // not, or the dropdown is still decorative.
    expect(sounds, hasLength(3));
  });

  test('an unknown id falls back to the alarm rather than going silent', () {
    // A future version of the other app could introduce a value this build has
    // never seen; the timer must still ring.
    final sound = alarmSoundFor('some_future_sound');
    expect(sound.android, AndroidSounds.alarm);
    expect(sound.asAlarm, isTrue);
  });
}
