import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/morning_ritual/pages/morning_ritual_today_tab.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_randomizer_source.dart';

/// Drives the real Today-tab runner.
///
/// The selection semantics implementation-plan P2.5 asks for — start draws,
/// previous / start-over / resume do **not** redraw, complete and skip
/// snapshot what was shown — live in this widget, so proving them means
/// pumping the widget rather than calling the service.
///
/// **Every interaction goes through [act].** A `testWidgets` body runs inside
/// a fake-async zone, and the runner writes to Hive on each step (draft saves,
/// the finished entry). Those futures resolve on the real event loop, which
/// the fake zone never advances, so a plain `tester.tap` leaves a write
/// permanently in flight — and Hive's per-box lock then deadlocks teardown.
/// `runAsync` steps outside the fake zone so the write actually lands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory supportDir;

  /// Plugin channels the runner touches. Without these the alarm and
  /// wake-lock calls raise MissingPluginException after the test completes.
  void mockPlugins() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const ['flutter_ringtone_player', 'vibration']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => supportDir.path,
    );
    // wakelock_plus is a Pigeon API, so it speaks over BasicMessageChannels
    // rather than a MethodChannel. A Pigeon reply for a void call is a
    // one-element list holding the result.
    const pigeon = StandardMessageCodec();
    for (final method in const ['toggle', 'isEnabled']) {
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.'
        'WakelockPlusApi.$method',
        (message) async => pigeon.encodeMessage(<Object?>[
          method == 'isEnabled' ? false : null,
        ]),
      );
    }
  }

  /// A Just for Today reading followed by an ordinary prayer.
  Future<void> seedDefaultItems() async {
    final box = Hive.box<RitualItem>('morning_ritual_items');
    await box.clear();
    await box.put(
      'jft',
      RitualItem(
        id: 'jft',
        name: 'Just for Today',
        type: RitualItemType.prayer,
        // If this ever reaches the screen, the draw was not used.
        prayerText: 'PLACEHOLDER-NEVER-SHOWN',
        sortOrder: 0,
        randomizerSourceId: MorningRandomizerContract.justForTodaySourceId,
      ),
    );
    await box.put(
      'third-step',
      RitualItem(
        id: 'third-step',
        name: '3rd Step Prayer',
        type: RitualItemType.prayer,
        prayerText: 'God, I offer myself to Thee',
        sortOrder: 1,
      ),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mr_runner_');
    supportDir = await Directory.systemTemp.createTemp('mr_runner_support_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(RitualItemTypeAdapter());
      Hive.registerAdapter(RitualItemAdapter());
      Hive.registerAdapter(RitualItemStatusAdapter());
      Hive.registerAdapter(RitualItemRecordAdapter());
      Hive.registerAdapter(MorningRitualEntryAdapter());
    }
    await Hive.openBox<RitualItem>('morning_ritual_items');
    await Hive.openBox<MorningRitualEntry>('morning_ritual_entries');
    await Hive.openBox<dynamic>('settings');
    MorningRandomizerSource.resetForTest();
    await MorningRandomizerSource.ensureLoaded();
    mockPlugins();
    await seedDefaultItems();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
    await supportDir.delete(recursive: true);
  });

  /// Run [body] outside the fake-async zone, let its Hive writes land, then
  /// rebuild. See the note at the top of the file.
  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) =>
      act(tester, () => tester.tap(find.text(label)));

  /// Tap [finder] once it exists.
  ///
  /// `act`'s fixed 150ms was enough on an idle machine but not when the whole
  /// suite runs in parallel: a dialog that had not been built yet made the tap
  /// throw "Bad state: No element" perhaps one run in four. Wait for the widget
  /// instead of for a duration.
  /// Tap [trigger] until [confirm] exists, then tap [confirm].
  ///
  /// The confirm-dialog steps were the one flaky corner of this suite: `act`'s
  /// fixed 150ms was enough on an idle machine, but with every test file
  /// running in parallel the dialog sometimes had not been pushed yet and the
  /// follow-up tap threw. Re-issuing the trigger is exactly what a user would
  /// do and is harmless once the dialog is up, since the check runs first.
  ///
  /// Pass *unqualified* finders — a `.last` finder throws "Bad state: No
  /// element" out of `evaluate()` itself, so it cannot answer "is it there
  /// yet?".
  Future<void> tapToConfirm(
    WidgetTester tester, {
    required Finder trigger,
    required Finder confirm,
  }) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (confirm.evaluate().isNotEmpty) {
        await act(tester, () => tester.tap(confirm.last));
        return;
      }
      if (trigger.evaluate().isNotEmpty) {
        await act(tester, () => tester.tap(trigger.last));
      } else {
        await act(tester, () async {});
      }
    }
    fail('Timed out waiting for $confirm');
  }

  Future<void> pumpRunner(WidgetTester tester, {String locale = 'en'}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('en'), Locale('da')],
        // Mirror AppWidget: without these, Danish has no MaterialLocalizations
        // and the framework throws.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MorningRitualTodayTab(selectedDate: DateTime.now()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The catalog reading currently on screen, whichever option was drawn.
  String shownReading([String localeCode = 'en']) {
    final matches = MorningRandomizerSource.optionsFor(
      MorningRandomizerContract.justForTodaySourceId,
      localeCode,
    ).where((o) => find.text(o.text).evaluate().isNotEmpty).toList();
    expect(
      matches,
      hasLength(1),
      reason: 'exactly one catalog reading should be on screen',
    );
    return matches.single.text;
  }

  RitualItemRecord recordFor(String itemId) => Hive.box<MorningRitualEntry>(
    'morning_ritual_entries',
  ).values.single.items.firstWhere((r) => r.ritualItemId == itemId);

  testWidgets('starting the ritual draws a reading, not the prayer text', (
    tester,
  ) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');

    expect(find.text('Just for Today'), findsOneWidget);
    expect(find.text('PLACEHOLDER-NEVER-SHOWN'), findsNothing);
    shownReading();
  });

  testWidgets('previous shows the same reading, not a new draw', (
    tester,
  ) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');
    final first = shownReading();

    await tapText(tester, 'Complete');
    expect(find.text('God, I offer myself to Thee'), findsOneWidget);

    await tapText(tester, 'Previous');
    expect(
      shownReading(),
      first,
      reason: 'stepping back must not redraw the day\'s reading',
    );
  });

  testWidgets('start over keeps the day\'s reading', (tester) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');
    final first = shownReading();

    // The page's Start Over is an OutlinedButton; the confirmation dialog's is
    // an ElevatedButton with the same label.
    await tapToConfirm(
      tester,
      trigger: find.widgetWithText(OutlinedButton, 'Start Over'),
      confirm: find.widgetWithText(ElevatedButton, 'Start Over'),
    );

    expect(
      shownReading(),
      first,
      reason: 'restarting the ritual is still the same day',
    );
  });

  testWidgets('resuming after leaving the screen shows the same reading', (
    tester,
  ) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');
    final first = shownReading();

    // Navigate away, then come back to a fresh widget reading the draft.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await pumpRunner(tester);

    expect(
      shownReading(),
      first,
      reason: 'the device-local draft carries the draw across a rebuild',
    );
  });

  testWidgets('completing snapshots exactly what was on screen', (
    tester,
  ) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');
    final shown = shownReading();

    await tapText(tester, 'Complete');
    await tapText(tester, 'Complete');

    final reading = recordFor('jft');
    expect(reading.status, RitualItemStatus.completed);
    expect(reading.selectedContentId, isNotNull);
    expect(reading.selectedContentText, shown);

    // A static item snapshots nothing — both fields stay null.
    final plain = recordFor('third-step');
    expect(plain.selectedContentId, isNull);
    expect(plain.selectedContentText, isNull);
  });

  testWidgets('skipping still records the reading that was offered', (
    tester,
  ) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');
    final shown = shownReading();

    await tapText(tester, 'Skip');
    await tapText(tester, 'Complete');

    final reading = recordFor('jft');
    expect(reading.status, RitualItemStatus.skipped);
    expect(reading.selectedContentText, shown);
  });

  testWidgets('the finished day shows the reading it recorded', (tester) async {
    await pumpRunner(tester);
    await tapText(tester, 'Start Ritual');
    final shown = shownReading();
    await tapText(tester, 'Complete');
    await tapText(tester, 'Complete');

    // The completed view replaces the runner for the same day.
    expect(find.text(shown), findsOneWidget);
  });

  testWidgets('a Danish ritual draws and records Danish text', (tester) async {
    await pumpRunner(tester, locale: 'da');
    await tapText(tester, 'Start Ritual');

    final danish = shownReading('da');
    expect(
      MorningRandomizerSource.optionsFor(
        MorningRandomizerContract.justForTodaySourceId,
        'en',
      ).every((o) => o.text != danish),
      isTrue,
      reason: 'a Danish ritual must not show English copy',
    );

    await tapText(tester, 'Fuldfør');
    await tapText(tester, 'Fuldfør');
    expect(recordFor('jft').selectedContentText, danish);
  });

  testWidgets('a ritual with no randomized item behaves exactly as before', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final box = Hive.box<RitualItem>('morning_ritual_items');
      await box.clear();
      await box.put(
        'third-step',
        RitualItem(
          id: 'third-step',
          name: '3rd Step Prayer',
          type: RitualItemType.prayer,
          prayerText: 'God, I offer myself to Thee',
          sortOrder: 0,
        ),
      );
    });
    await pumpRunner(tester);

    await tapText(tester, 'Start Ritual');
    expect(find.text('God, I offer myself to Thee'), findsOneWidget);

    await tapText(tester, 'Complete');
    final record = recordFor('third-step');
    expect(record.selectedContentId, isNull);
    expect(record.selectedContentText, isNull);
  });

  testWidgets('an unknown reading source falls back to the prayer text', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final box = Hive.box<RitualItem>('morning_ritual_items');
      await box.clear();
      await box.put(
        'future',
        RitualItem(
          id: 'future',
          name: 'From a later release',
          type: RitualItemType.prayer,
          prayerText: 'Fallback text',
          sortOrder: 0,
          randomizerSourceId: 'a_source_this_build_does_not_ship',
        ),
      );
    });
    await pumpRunner(tester);

    await tapText(tester, 'Start Ritual');
    expect(find.text('Fallback text'), findsOneWidget);
  });
}
