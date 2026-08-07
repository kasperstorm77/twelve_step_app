import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/morning_ritual/pages/morning_ritual_settings_tab.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_randomizer_source.dart';
import 'package:twelvestepsapp/shared/pages/foreign_import_dialog.dart';
import 'package:twelvestepsapp/shared/services/backup_restore_service.dart';

/// Renders the two screens this change added, in **both** languages.
///
/// Danish copy runs longer than English (CLAUDE.md rule 10), and a widget test
/// turns a RenderFlex overflow into a failure — so pumping each dialog at a
/// realistic size is the check that the layout actually holds, not just that
/// the strings exist.
///
/// Interactions that write to Hive go through [act]; see the note in
/// `morning_ritual_runner_test.dart` for why.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mr_editor_');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  Widget harness(Widget child, String locale) => MaterialApp(
    locale: Locale(locale),
    supportedLocales: const [Locale('en'), Locale('da')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );

  Box<RitualItem> items() => Hive.box<RitualItem>('morning_ritual_items');

  Future<void> openEditor(WidgetTester tester, {String locale = 'en'}) async {
    await tester.pumpWidget(harness(const MorningRitualSettingsTab(), locale));
    await tester.pumpAndSettle();
    await act(tester, () => tester.tap(find.byIcon(Icons.edit).first));
  }

  group('Just for Today toggle in the item editor', () {
    setUp(() async {
      await items().put(
        'prayer',
        RitualItem(
          id: 'prayer',
          name: '3rd Step Prayer',
          type: RitualItemType.prayer,
          prayerText: 'God, I offer myself to Thee',
          sortOrder: 0,
        ),
      );
    });

    testWidgets('turning it on stores the shared source id', (tester) async {
      await openEditor(tester);

      expect(find.text('Just for Today'), findsOneWidget);
      // Off by default: the item keeps its own text field.
      expect(find.text('Prayer Text'), findsOneWidget);

      await act(tester, () => tester.tap(find.byType(SwitchListTile)));
      // A randomized reading has no fixed text of its own.
      expect(find.text('Prayer Text'), findsNothing);

      await act(tester, () => tester.tap(find.text('Update')));

      expect(
        items().get('prayer')!.randomizerSourceId,
        MorningRandomizerContract.justForTodaySourceId,
      );
      expect(items().get('prayer')!.type, RitualItemType.prayer);
    });

    testWidgets('turning it back off clears the source id', (tester) async {
      // Seeding writes to Hive, so it must leave the fake-async zone too.
      await tester.runAsync(
        () => items().put(
          'prayer',
          RitualItem(
            id: 'prayer',
            name: 'Just for Today',
            type: RitualItemType.prayer,
            sortOrder: 0,
            randomizerSourceId: MorningRandomizerContract.justForTodaySourceId,
          ),
        ),
      );
      await openEditor(tester);

      await act(tester, () => tester.tap(find.byType(SwitchListTile)));
      await act(tester, () => tester.tap(find.text('Update')));

      expect(items().get('prayer')!.randomizerSourceId, isNull);
    });

    testWidgets('a second Just for Today item is refused', (tester) async {
      // Emotional Sobriety rejects a backup carrying two of them.
      await tester.runAsync(
        () => items().put(
          'existing',
          RitualItem(
            id: 'existing',
            name: 'Just for Today',
            type: RitualItemType.prayer,
            sortOrder: 1,
            randomizerSourceId: MorningRandomizerContract.justForTodaySourceId,
          ),
        ),
      );
      await openEditor(tester);

      await act(tester, () => tester.tap(find.byType(SwitchListTile)));
      await act(tester, () => tester.tap(find.text('Update')));

      expect(
        find.text('Only one Just for Today item is supported.'),
        findsOneWidget,
      );
      expect(items().get('prayer')!.randomizerSourceId, isNull);
    });

    testWidgets('the toggle is not offered for a timer', (tester) async {
      await tester.runAsync(
        () => items().put(
          'prayer',
          RitualItem(
            id: 'prayer',
            name: 'Meditation',
            type: RitualItemType.timer,
            durationSeconds: 300,
            sortOrder: 0,
          ),
        ),
      );
      await openEditor(tester);

      expect(find.text('Just for Today'), findsNothing);
    });

    testWidgets('the Danish editor lays out without overflowing', (
      tester,
    ) async {
      await openEditor(tester, locale: 'da');

      // The reading keeps its English name in Danish — it is the feature's
      // name, not a phrase to translate.
      expect(find.text('Just for Today'), findsOneWidget);
      expect(
        find.textContaining('Trækker én af de ti'),
        findsOneWidget,
        reason: 'the Danish help text must be the Danish one',
      );
      // Two text fields with the toggle off: the name and the prayer text.
      // (Danish labels the prayer *type* and the prayer *text* both "Bøn", so
      // matching on that string cannot tell them apart — count the fields.)
      expect(find.byType(TextField), findsNWidgets(2));

      // Reaching here without a RenderFlex overflow is the layout assertion.
      await act(tester, () => tester.tap(find.byType(SwitchListTile)));
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'a randomized reading has no text field of its own',
      );
    });
  });

  group('foreign import confirmation', () {
    const summary = ForeignImportSummary(
      product: 'emotional-sobriety',
      version: '1.0',
      sectionCounts: {
        'iAmDefinitions': 1,
        'entries': 12,
        'agnosticism': 2,
        'morningRitualItems': 7,
        'morningRitualEntries': 34,
      },
      ignoredSections: [
        'workshopProgress',
        'morningRitualDraft',
        'emotionalSobrietySettings',
      ],
    );

    Future<bool?> showIt(WidgetTester tester, String locale) async {
      bool? outcome;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                outcome = await confirmForeignImport(context, summary);
              },
              child: const Text('open'),
            ),
          ),
          locale,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return outcome;
    }

    testWidgets('English names every dataset and count', (tester) async {
      await showIt(tester, 'en');

      expect(find.text('Import from Emotional Sobriety'), findsOneWidget);
      expect(find.text('These datasets will be replaced:'), findsOneWidget);
      expect(find.text('• I Am definitions: 1'), findsOneWidget);
      expect(find.text('• 4th Step entries: 12'), findsOneWidget);
      expect(find.text('• Barrier/Power pairs: 2'), findsOneWidget);
      expect(find.text('• Morning Ritual items: 7'), findsOneWidget);
      expect(find.text('• Morning Ritual history: 34'), findsOneWidget);
      // And what is dropped, so nothing is a surprise.
      expect(find.text('• Workshop progress'), findsOneWidget);
      expect(find.text('• Emotional Sobriety settings'), findsOneWidget);
      expect(
        find.textContaining('Everything else on this device'),
        findsOneWidget,
      );
    });

    testWidgets('Danish is fully translated and fits', (tester) async {
      await showIt(tester, 'da');

      expect(find.text('Importér fra Emotional Sobriety'), findsOneWidget);
      expect(find.text('Disse datasæt bliver erstattet:'), findsOneWidget);
      expect(find.text('• Jeg Er - definitioner: 1'), findsOneWidget);
      expect(find.text('• Barriere/Kraft-par: 2'), findsOneWidget);
      expect(find.text('• Morgenritual-historik: 34'), findsOneWidget);
      expect(find.text('• Workshop-fremdrift'), findsOneWidget);
      expect(find.textContaining('Alt andet på denne enhed'), findsOneWidget);
      // No English leaked into the Danish dialog.
      expect(find.textContaining('will be replaced'), findsNothing);
    });

    testWidgets('cancel means no, import means yes', (tester) async {
      await showIt(tester, 'en');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Import from Emotional Sobriety'), findsNothing);

      final confirmed = await showIt(tester, 'en');
      expect(confirmed, isNull, reason: 'not answered yet');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pumpAndSettle();
      expect(find.text('Import from Emotional Sobriety'), findsNothing);
    });
  });
}
