import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/agnosticism/models/barrier_power_pair.dart';
import 'package:twelvestepsapp/eighth_step/models/person.dart';
import 'package:twelvestepsapp/evening_ritual/models/reflection_entry.dart';
import 'package:twelvestepsapp/fourth_step/models/i_am_definition.dart';
import 'package:twelvestepsapp/fourth_step/models/inventory_entry.dart';
import 'package:twelvestepsapp/gratitude/models/gratitude_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_ritual_service.dart';
import 'package:twelvestepsapp/notifications/models/app_notification.dart';
import 'package:twelvestepsapp/shared/services/backup_restore_service.dart';
import 'package:twelvestepsapp/shared/services/sync_payload_builder.dart';

/// Importing an Emotional Sobriety backup (implementation plan P2.6).
///
/// The fixture is **captured from that app's own `SyncPayloadBuilder`**, not
/// hand-written: the last cross-app defect survived both suites precisely
/// because every fixture on both sides was hand-authored with values no device
/// produces.
Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            'test/fixtures/emotional_sobriety_export_1_0.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('twelve_step_es_import_');
    Hive.init(directory.path);
    _registerAdapters();
    await Hive.openBox<InventoryEntry>('entries');
    await Hive.openBox<IAmDefinition>('i_am_definitions');
    await Hive.openBox<Person>('people_box');
    await Hive.openBox<ReflectionEntry>('reflections_box');
    await Hive.openBox<GratitudeEntry>('gratitude_box');
    await Hive.openBox<BarrierPowerPair>('agnosticism_pairs');
    await Hive.openBox<RitualItem>('morning_ritual_items');
    await Hive.openBox<MorningRitualEntry>('morning_ritual_entries');
    await Hive.openBox<AppNotification>('notifications_box');
    await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await directory.delete(recursive: true);
  });

  group('recognising a foreign payload', () {
    test('this app\'s own payload is never foreign', () {
      expect(
        BackupRestoreService.foreignProductOf(<String, dynamic>{
          'version': '8.0',
          'entries': <dynamic>[],
        }),
        isNull,
      );
      expect(
        SyncPayloadBuilder.buildPayload().containsKey('product'),
        isFalse,
        reason: 'writing a product tag would make our own backups foreign',
      );
    });

    test('the captured file is tagged emotional-sobriety 1.0', () {
      final data = _fixture();
      expect(data['product'], 'emotional-sobriety');
      expect(data['version'], '1.0');
      expect(BackupRestoreService.isSupportedForeignPayload(data), isTrue);
    });

    test('the summary names every dataset before anything is written', () {
      final summary = BackupRestoreService.describeForeignPayload(_fixture())!;
      expect(summary.product, 'emotional-sobriety');
      expect(summary.version, '1.0');
      expect(summary.sectionCounts, <String, int>{
        'iAmDefinitions': 1,
        'entries': 1,
        'agnosticism': 2,
        'morningRitualItems': 2,
        'morningRitualEntries': 1,
      });
      // The Morning draft is null in this capture, so only the two sections
      // actually carrying data are reported as ignored.
      expect(
        summary.ignoredSections,
        containsAll(<String>['workshopProgress', 'emotionalSobrietySettings']),
      );
    });

    test('an unknown product is not describable and not importable', () async {
      final data = <String, dynamic>{
        'product': 'some-other-app',
        'version': '3.0',
        'entries': <dynamic>[],
      };
      expect(BackupRestoreService.describeForeignPayload(data), isNull);
      final result = await BackupRestoreService.restoreFromPayload(
        data,
        createSafetyBackup: false,
        allowForeignProduct: true,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('some-other-app'));
    });
  });

  test('the automatic path refuses a foreign payload outright', () async {
    final pairs = Hive.box<BarrierPowerPair>('agnosticism_pairs');
    await pairs.put(
      'local',
      BarrierPowerPair(
        id: 'local',
        barrier: 'Local barrier',
        power: 'Local power',
        createdAt: DateTime(2026, 8, 1),
        connectedFear: 'Local fear',
      ),
    );

    // No allowForeignProduct flag: this is what a Drive restore does.
    final result = await BackupRestoreService.restoreFromPayload(
      _fixture(),
      createSafetyBackup: false,
    );

    expect(result.success, isFalse);
    expect(result.error, contains('another app'));
    // Nothing was touched.
    expect(pairs.length, 1);
    expect(pairs.get('local')!.barrier, 'Local barrier');
  });

  group('importing the captured file', () {
    Future<RestoreResult> importFixture() =>
        BackupRestoreService.restoreFromPayload(
          _fixture(),
          createSafetyBackup: false,
          allowForeignProduct: true,
        );

    test('the five shared datasets arrive intact', () async {
      final result = await importFixture();
      expect(result.success, isTrue, reason: result.error);
      expect(result.counts.skippedRecords, 0);
      expect(result.counts.iAmDefinitions, 1);
      expect(result.counts.entries, 1);
      expect(result.counts.agnosticism, 2);
      expect(result.counts.morningRitualItems, 2);
      expect(result.counts.morningRitualEntries, 1);

      final definition = Hive.box<IAmDefinition>(
        'i_am_definitions',
      ).values.single;
      expect(definition.id, 'source-definition');
      expect(definition.reasonToExist, 'Source reason');

      final entry = Hive.box<InventoryEntry>('entries').values.single;
      expect(entry.id, 'source-inventory');
      // `order` and `category` are modelled here, so they are kept, not dropped.
      expect(entry.order, 1);
      expect(entry.effectiveCategory, InventoryCategory.fear);
      expect(entry.effectiveIAmIds, <String>['source-definition']);
    });

    test('agnosticism pairs import with connectedFear preserved', () async {
      await importFixture();
      final pairs = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      expect(pairs.length, 2);
      expect(
        pairs.get('source-active-pair')!.connectedFear,
        'Source uncertainty',
      );
      expect(pairs.get('source-active-pair')!.isArchived, isFalse);
      expect(
        pairs.get('source-archived-pair')!.connectedFear,
        'Source disconnection',
      );
      expect(pairs.get('source-archived-pair')!.isArchived, isTrue);
    });

    test('the randomizer definition and history snapshot survive', () async {
      await importFixture();
      final item = Hive.box<RitualItem>(
        'morning_ritual_items',
      ).get('source-jft')!;
      expect(item.randomizerSourceId, 'just_for_today');
      expect(item.type, RitualItemType.prayer);

      final record = Hive.box<MorningRitualEntry>(
        'morning_ritual_entries',
      ).get('source-ritual-entry')!.items.single;
      expect(record.selectedContentId, 'present_moment');
      expect(record.selectedContentText, isNotNull);
    });

    test(
      'sections the other app does not have leave local data alone',
      () async {
        final gratitude = Hive.box<GratitudeEntry>('gratitude_box');
        await gratitude.add(
          GratitudeEntry(
            gratitudeTowards: 'My sponsor',
            gratefulFor: 'Answering the phone',
            date: DateTime(2026, 8, 5),
            createdAt: DateTime(2026, 8, 5, 20),
          ),
        );
        final people = Hive.box<Person>('people_box');
        await people.put('p1', Person(name: 'Someone', column: ColumnType.yes));

        final result = await importFixture();
        expect(result.success, isTrue, reason: result.error);

        // Emotional Sobriety has no gratitude or amends list; importing its file
        // must not wipe this device's.
        expect(gratitude.length, 1);
        expect(people.length, 1);
        expect(result.counts.gratitude, 0);
        expect(result.counts.people, 0);
      },
    );

    test('a round trip re-exports every field this app models', () async {
      await importFixture();
      final rebuilt = SyncPayloadBuilder.buildPayload();

      expect(rebuilt['version'], '8.0');

      final pair = (rebuilt['agnosticism'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['id'] == 'source-active-pair');
      expect(pair['connectedFear'], 'Source uncertainty');
      expect(pair['createdAt'], endsWith('Z'));

      final item = (rebuilt['morningRitualItems'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((i) => i['id'] == 'source-jft');
      expect(item['randomizerSourceId'], 'just_for_today');

      final entry =
          (rebuilt['morningRitualEntries'] as List<dynamic>).single
              as Map<String, dynamic>;
      // The ritual date stays a local calendar day on the way back out.
      expect(entry['date'], '2026-07-20');
      final record =
          (entry['items'] as List<dynamic>).single as Map<String, dynamic>;
      expect(record['selectedContentId'], 'present_moment');
      expect(record['selectedContentText'], isNotNull);

      final inventory =
          (rebuilt['entries'] as List<dynamic>).single as Map<String, dynamic>;
      expect(inventory['order'], 1);
      expect(inventory['category'], 'fear');
    });
  });

  group('normalising a foreign set to this app\'s rules', () {
    test('excess active pairs are archived, never dropped', () async {
      final data = _fixture();
      data['agnosticismPairs'] = <Map<String, dynamic>>[
        for (var i = 0; i < 8; i += 1)
          <String, dynamic>{
            'id': 'pair-$i',
            'barrier': 'Barrier $i',
            'power': 'Power $i',
            'isArchived': false,
            'createdAt': '2026-07-0${i + 1}T07:00:00.000Z',
            'archivedAt': null,
            'position': i,
            'connectedFear': 'Fear $i',
          },
      ];

      final result = await BackupRestoreService.restoreFromPayload(
        data,
        createSafetyBackup: false,
        allowForeignProduct: true,
      );
      expect(result.success, isTrue, reason: result.error);

      final pairs = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      // Nothing is lost — all eight are still there.
      expect(pairs.length, 8);
      final active = pairs.values.where((p) => !p.isArchived).toList();
      expect(active, hasLength(5));
      expect(active.map((p) => p.position).toList()..sort(), <int>[
        0,
        1,
        2,
        3,
        4,
      ]);
      final archived = pairs.values.where((p) => p.isArchived).toList();
      expect(archived, hasLength(3));
      expect(archived.every((p) => p.archivedAt != null), isTrue);
      expect(archived.every((p) => p.connectedFear.isNotEmpty), isTrue);
    });

    test('a second randomized reading becomes an ordinary prayer', () async {
      final data = _fixture();
      final items = (data['morningRitualItems'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      data['morningRitualItems'] = <Map<String, dynamic>>[
        ...items,
        <String, dynamic>{
          ...items.firstWhere((i) => i['randomizerSourceId'] != null),
          'id': 'source-jft-2',
          'sortOrder': 2,
        },
      ];

      final result = await BackupRestoreService.restoreFromPayload(
        data,
        createSafetyBackup: false,
        allowForeignProduct: true,
      );
      expect(result.success, isTrue, reason: result.error);

      final box = Hive.box<RitualItem>('morning_ritual_items');
      // Both items survive; only one keeps the reading source.
      expect(box.length, 3);
      expect(
        box.values.where((i) => i.randomizerSourceId != null),
        hasLength(1),
      );
      expect(box.get('source-jft-2')!.type, RitualItemType.prayer);
    });

    test('deleting a definition leaves no gap in the sort order', () async {
      // Emotional Sobriety refuses a backup whose Morning sort orders are not
      // contiguous from zero — and it refuses the *whole file*, not just the
      // Morning section. Deleting an item used to open exactly such a gap.
      final items = Hive.box<RitualItem>('morning_ritual_items');
      for (var i = 0; i < 4; i += 1) {
        await MorningRitualService.addRitualItem(
          RitualItem(
            id: 'item-$i',
            name: 'Item $i',
            type: RitualItemType.prayer,
            prayerText: 'Text $i',
          ),
        );
      }
      expect(items.values.map((i) => i.sortOrder).toList()..sort(), [
        0,
        1,
        2,
        3,
      ]);

      await MorningRitualService.deleteRitualItem('item-1');

      final orders = items.values.map((i) => i.sortOrder).toList()..sort();
      expect(orders, <int>[0, 1, 2]);
      expect(orders.toSet(), hasLength(3));
    });

    test('a gapped set already on disk is repaired at startup', () async {
      final items = Hive.box<RitualItem>('morning_ritual_items');
      await items.put(
        'a',
        RitualItem(
          id: 'a',
          name: 'A',
          type: RitualItemType.timer,
          sortOrder: 0,
        ),
      );
      await items.put(
        'b',
        RitualItem(
          id: 'b',
          name: 'B',
          type: RitualItemType.timer,
          sortOrder: 7,
        ),
      );
      await items.put(
        'c',
        RitualItem(
          id: 'c',
          name: 'C',
          type: RitualItemType.timer,
          sortOrder: 7,
        ),
      );

      await MorningRitualService.migrateSortOrders();

      final orders = items.values.map((i) => i.sortOrder).toList()..sort();
      expect(orders, <int>[0, 1, 2]);
      expect(items.get('a')!.sortOrder, 0, reason: 'relative order is kept');
      // Idempotent: a second run changes nothing.
      await MorningRitualService.migrateSortOrders();
      expect(items.values.map((i) => i.sortOrder).toList()..sort(), <int>[
        0,
        1,
        2,
      ]);
    });

    test(
      'an unreadable record is skipped, not fatal, and never half-writes',
      () async {
        final data = _fixture();
        final items = (data['morningRitualItems'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        data['morningRitualItems'] = <Map<String, dynamic>>[
          // A shape this app cannot represent: a randomized *timer*.
          <String, dynamic>{
            ...items.first,
            'id': 'impossible',
            'type': RitualItemType.timer.index,
            'durationSeconds': 60,
            'randomizerSourceId': 'just_for_today',
          },
          ...items,
        ];

        final result = await BackupRestoreService.restoreFromPayload(
          data,
          createSafetyBackup: false,
          allowForeignProduct: true,
        );

        expect(result.success, isTrue, reason: result.error);
        expect(result.counts.skippedRecords, 1);
        // The rest of the section still landed — the old code threw part-way
        // through the rewrite and left the box holding a fragment.
        expect(Hive.box<RitualItem>('morning_ritual_items').length, 2);
        expect(result.counts.morningRitualEntries, 1);
      },
    );
  });
}

/// Register every adapter exactly as `main.dart` does.
///
/// Each call must keep its concrete type argument: registering through a
/// `TypeAdapter<dynamic>` variable makes Hive match the first adapter to every
/// object, and each box then writes with the wrong one.
void _registerAdapters() {
  if (Hive.isAdapterRegistered(0)) return;
  Hive.registerAdapter(InventoryEntryAdapter());
  Hive.registerAdapter(IAmDefinitionAdapter());
  Hive.registerAdapter(PersonAdapter());
  Hive.registerAdapter(ColumnTypeAdapter());
  Hive.registerAdapter(ReflectionEntryAdapter());
  Hive.registerAdapter(ReflectionTypeAdapter());
  Hive.registerAdapter(GratitudeEntryAdapter());
  Hive.registerAdapter(BarrierPowerPairAdapter());
  Hive.registerAdapter(RitualItemTypeAdapter());
  Hive.registerAdapter(RitualItemAdapter());
  Hive.registerAdapter(RitualItemStatusAdapter());
  Hive.registerAdapter(RitualItemRecordAdapter());
  Hive.registerAdapter(MorningRitualEntryAdapter());
  Hive.registerAdapter(InventoryCategoryAdapter());
  Hive.registerAdapter(NotificationScheduleTypeAdapter());
  Hive.registerAdapter(AppNotificationAdapter());
}
