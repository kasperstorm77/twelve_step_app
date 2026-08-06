import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_randomizer_source.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_ritual_service.dart';

/// The ten Just for Today option IDs Emotional Sobriety froze. A snapshot
/// written here travels to that app as `selectedContentId`, so these IDs are a
/// cross-app contract, not an implementation detail.
const _justForTodayOptionIds = <String>[
  'happy_and_still',
  'adjust_to_what_is',
  'one_day_only',
  'agreeable_conduct',
  'others_opinions',
  'present_moment',
  'cease_fighting',
  'unafraid_beauty',
  'quiet_half_hour',
  'exercise_the_soul',
];

RitualItem _justForTodayItem({String id = 'jft'}) => RitualItem(
  id: id,
  name: 'Just for Today',
  type: RitualItemType.prayer,
  prayerText: 'A reading is chosen when the ritual begins.',
  randomizerSourceId: MorningRandomizerContract.justForTodaySourceId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalog', () {
    setUp(() async {
      MorningRandomizerSource.resetForTest();
      await MorningRandomizerSource.ensureLoaded();
    });

    test('resolves all ten option IDs from data, in both languages', () {
      for (final locale in ['en', 'da']) {
        final options = MorningRandomizerSource.optionsFor(
          MorningRandomizerContract.justForTodaySourceId,
          locale,
        );
        expect(
          options.map((o) => o.id).toList(),
          _justForTodayOptionIds,
          reason:
              'option IDs and order must match Emotional Sobriety ($locale)',
        );
        expect(
          options.every((o) => o.text.trim().isNotEmpty),
          isTrue,
          reason: 'every $locale option needs real copy',
        );
      }
    });

    test('English and Danish are meaning-equivalent, not the same string', () {
      final english = MorningRandomizerSource.optionsFor(
        MorningRandomizerContract.justForTodaySourceId,
        'en',
      );
      final danish = MorningRandomizerSource.optionsFor(
        MorningRandomizerContract.justForTodaySourceId,
        'da',
      );
      for (var i = 0; i < english.length; i += 1) {
        expect(danish[i].id, english[i].id);
        expect(danish[i].text, isNot(english[i].text));
      }
    });

    test('an unknown locale falls back to English rather than failing', () {
      expect(
        MorningRandomizerSource.optionsFor(
          MorningRandomizerContract.justForTodaySourceId,
          'de',
        ).map((o) => o.id),
        _justForTodayOptionIds,
      );
    });

    test('an unknown source yields no options instead of throwing', () {
      expect(MorningRandomizerSource.optionsFor('not_shipped', 'en'), isEmpty);
    });

    test('re-resolves a stored option ID in the other language', () {
      final english = MorningRandomizerSource.textForOption(
        MorningRandomizerContract.justForTodaySourceId,
        'present_moment',
        'en',
      );
      final danish = MorningRandomizerSource.textForOption(
        MorningRandomizerContract.justForTodaySourceId,
        'present_moment',
        'da',
      );
      expect(english, isNotNull);
      expect(danish, isNotNull);
      expect(danish, isNot(english));
      // An option the catalog doesn't know keeps the caller's snapshot.
      expect(
        MorningRandomizerSource.textForOption(
          MorningRandomizerContract.justForTodaySourceId,
          'from_a_future_release',
          'en',
        ),
        isNull,
      );
    });

    test('a catalog missing a language is rejected', () {
      expect(
        () => MorningRandomizerSource.loadFromStringForTest(
          '{"schemaVersion":1,"sources":[{"id":"s","options":['
          '{"id":"a","order":1,"text":{"en":"Only English"}}]}]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('selection', () {
    setUp(() async {
      MorningRandomizerSource.resetForTest();
      await MorningRandomizerSource.ensureLoaded();
    });

    test('an injected picker can reach every option index', () async {
      final reached = <String>{};
      for (var index = 0; index < _justForTodayOptionIds.length; index += 1) {
        final selections = await MorningRitualService.pickRandomizerSelections(
          items: [_justForTodayItem()],
          localeCode: 'en',
          picker: (_) => index,
        );
        expect(selections, hasLength(1));
        expect(
          selections.single.selectedContentId,
          _justForTodayOptionIds[index],
        );
        expect(selections.single.selectedContentText.trim(), isNotEmpty);
        reached.add(selections.single.selectedContentId);
      }
      expect(reached, _justForTodayOptionIds.toSet());
    });

    test('the default picker stays inside the catalog', () async {
      for (var attempt = 0; attempt < 25; attempt += 1) {
        final selections = await MorningRitualService.pickRandomizerSelections(
          items: [_justForTodayItem()],
          localeCode: 'en',
        );
        expect(
          _justForTodayOptionIds,
          contains(selections.single.selectedContentId),
        );
      }
    });

    test('static items and unknown sources draw nothing', () async {
      final selections = await MorningRitualService.pickRandomizerSelections(
        items: [
          RitualItem(id: 't', name: 'Meditation', type: RitualItemType.timer),
          RitualItem(
            id: 'p',
            name: '3rd Step Prayer',
            type: RitualItemType.prayer,
            prayerText: 'God, I offer myself to Thee...',
          ),
          RitualItem(
            id: 'future',
            name: 'From a later release',
            type: RitualItemType.prayer,
            randomizerSourceId: 'a_source_this_build_does_not_ship',
          ),
        ],
        localeCode: 'en',
      );
      expect(selections, isEmpty);
    });

    test('an out-of-range picker is refused rather than crashing', () async {
      expect(
        await MorningRitualService.pickRandomizerSelections(
          items: [_justForTodayItem()],
          localeCode: 'en',
          picker: (_) => 99,
        ),
        isEmpty,
      );
    });
  });

  group('draft', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mr_randomizer_draft');
      Hive.init(tempDir.path);
      await Hive.openBox('settings');
      MorningRandomizerSource.resetForTest();
      await MorningRandomizerSource.ensureLoaded();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await tempDir.delete(recursive: true);
    });

    test('a draw survives save and resume unchanged', () async {
      final today = DateTime(2026, 8, 6, 6, 30);
      final drawn = await MorningRitualService.pickRandomizerSelections(
        items: [_justForTodayItem()],
        localeCode: 'en',
        picker: (_) => 5,
      );

      await MorningRitualService.saveProgress(
        date: today,
        currentItemIndex: 0,
        startedAt: today,
        records: const [],
        randomizerSelections: drawn,
      );

      final resumed = MorningRitualService.selectionsFromProgress(
        MorningRitualService.loadProgress(today),
      );
      expect(resumed, hasLength(1));
      expect(resumed.single.ritualItemId, 'jft');
      expect(resumed.single.selectedContentId, 'present_moment');
      expect(
        resumed.single.selectedContentText,
        drawn.single.selectedContentText,
      );
    });

    test('a draft written before this feature resumes with no draw', () async {
      final today = DateTime(2026, 8, 6, 6, 30);
      await Hive.box('settings').put(
        'morning_ritual_progress',
        '{"date":"2026-08-06","currentItemIndex":0,"startedAt":null,'
            '"records":[]}',
      );

      final progress = MorningRitualService.loadProgress(today);
      expect(progress, isNotNull);
      expect(MorningRitualService.selectionsFromProgress(progress), isEmpty);
    });

    test('a malformed draw is dropped, not thrown', () {
      expect(
        MorningRitualService.selectionsFromProgress(<String, dynamic>{
          'randomizerSelections': <dynamic>[
            {'ritualItemId': 'jft'},
            'nonsense',
            {
              'ritualItemId': 'jft',
              'selectedContentId': 'present_moment',
              'selectedContentText': 'Text',
            },
          ],
        }),
        hasLength(1),
      );
    });
  });

  group('history snapshot', () {
    test('a completed randomized item carries both snapshot fields', () {
      final record = RitualItemRecord(
        ritualItemId: 'jft',
        ritualItemName: 'Just for Today',
        status: RitualItemStatus.completed,
        selectedContentId: 'quiet_half_hour',
        selectedContentText:
            'Just for today, I will spend a quiet half hour...',
      );
      final decoded = RitualItemRecord.fromJson(record.toJson());
      expect(decoded.selectedContentId, 'quiet_half_hour');
      expect(decoded.selectedContentText, record.selectedContentText);
    });

    test('a missed day snapshots nothing', () async {
      final tempDir = await Directory.systemTemp.createTemp('mr_missed');
      addTearDown(() async {
        await Hive.close();
        await tempDir.delete(recursive: true);
      });
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(9)) {
        Hive.registerAdapter(RitualItemTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(RitualItemAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(RitualItemStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(RitualItemRecordAdapter());
      }
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(MorningRitualEntryAdapter());
      }
      final items = await Hive.openBox<RitualItem>('morning_ritual_items');
      await Hive.openBox<MorningRitualEntry>('morning_ritual_entries');
      await items.put('jft', _justForTodayItem());

      final entry = await MorningRitualService.createMissedEntry(
        DateTime(2026, 8, 5),
      );
      expect(entry.items.single.status, RitualItemStatus.missed);
      expect(entry.items.single.selectedContentId, isNull);
      expect(entry.items.single.selectedContentText, isNull);
    });
  });
}
