// Sets device-local `settings` keys in a Hive directory, so screenshot capture
// can open the app straight onto a given tool without UI automation.
//
// Usage: dart run tool/set_demo_settings.dart <hiveDir> <appId> [locale]
//
// Passing the morning ritual id also seeds an in-progress draft for today, so
// the Today tab opens into the runner showing a drawn Just for Today reading
// rather than the "Ready to Begin" screen.
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

Future<void> main(List<String> args) async {
  final dir = args[0];
  final appId = args[1];
  final locale = args.length > 2 ? args[2] : 'en';

  Hive.init(dir);
  final settings = await Hive.openBox<dynamic>('settings');
  await settings.put('selected_app_id', appId);
  await settings.put('language', locale);

  if (appId == 'morning_ritual') {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final today = '${now.year}-${two(now.month)}-${two(now.day)}';
    final reading = locale == 'da'
        ? 'Kun for i dag vil jeg være glad. Jeg vil ikke have forventninger '
              'eller stille krav i dag.'
        : 'Just for today, I will be happy. I will have no expectations, nor '
              'will I make demands today.';
    await settings.put(
      'morning_ritual_progress',
      jsonEncode({
        'date': today,
        'currentItemIndex': 0,
        'startedAt': DateTime(
          now.year,
          now.month,
          now.day,
          6,
          20,
        ).toIso8601String(),
        'records': <dynamic>[],
        'randomizerSelections': [
          {
            'ritualItemId': 'r0',
            'selectedContentId': 'happy_and_still',
            'selectedContentText': reading,
          },
        ],
      }),
    );
  } else {
    await settings.delete('morning_ritual_progress');
  }

  await Hive.close();
  stdout.writeln('settings: app=$appId locale=$locale');
}
