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
import 'package:twelvestepsapp/notifications/models/app_notification.dart';
import 'package:twelvestepsapp/shared/services/backup_restore_service.dart';
import 'package:twelvestepsapp/shared/services/sync_payload_builder.dart';

void main() {
  test('definition preserves the portable randomizer source field', () {
    final item = RitualItem(
      id: 'retreat-v1-just-for-today',
      name: 'Just for Today',
      type: RitualItemType.prayer,
      prayerText: 'A statement is selected when the ritual begins.',
      randomizerSourceId: 'just_for_today',
      lastModified: DateTime.utc(2026, 8, 1),
    );

    expect(item.toJson()['randomizerSourceId'], 'just_for_today');
    expect(
      RitualItem.fromJson(item.toJson()).randomizerSourceId,
      'just_for_today',
    );
    expect(RitualItemHiveFields.randomizerSourceId, 11);

    final releasedShape = Map<String, dynamic>.of(item.toJson())
      ..remove('randomizerSourceId');
    expect(RitualItem.fromJson(releasedShape).randomizerSourceId, isNull);
  });

  test(
    'editing an imported randomized prayer to a timer clears its source',
    () {
      final imported = RitualItem.fromJson(<String, dynamic>{
        'id': 'retreat-v1-just-for-today',
        'name': 'Just for Today',
        'type': RitualItemType.prayer.index,
        'durationSeconds': null,
        'prayerText': 'A statement is selected when the ritual begins.',
        'sortOrder': 0,
        'isActive': true,
        'vibrateEnabled': true,
        'soundEnabled': true,
        'soundId': null,
        'randomizerSourceId': 'just_for_today',
        'lastModified': '2026-08-01T08:00:00.000Z',
      });

      final edited = imported.copyWith(
        type: RitualItemType.timer,
        durationSeconds: 60,
      );

      expect(edited.randomizerSourceId, isNull);
      expect(edited.toJson()['randomizerSourceId'], isNull);
    },
  );

  test('definition decoder rejects invalid randomizer source combinations', () {
    Map<String, dynamic> definition({
      required RitualItemType type,
      required Object? sourceId,
    }) => <String, dynamic>{
      'id': 'definition',
      'name': 'Definition',
      'type': type.index,
      'durationSeconds': type == RitualItemType.timer ? 60 : null,
      'prayerText': type == RitualItemType.prayer ? 'Reading' : null,
      'sortOrder': 0,
      'isActive': true,
      'vibrateEnabled': true,
      'soundEnabled': true,
      'soundId': null,
      'randomizerSourceId': sourceId,
      'lastModified': '2026-08-01T08:00:00.000Z',
    };

    expect(
      () => RitualItem.fromJson(
        definition(type: RitualItemType.timer, sourceId: 'just_for_today'),
      ),
      throwsFormatException,
    );
    expect(
      () => RitualItem.fromJson(
        definition(type: RitualItemType.prayer, sourceId: '   '),
      ),
      throwsFormatException,
    );
  });

  test('history preserves the selected content snapshot fields', () {
    final record = RitualItemRecord(
      ritualItemId: 'retreat-v1-just-for-today',
      ritualItemName: 'Just for Today',
      status: RitualItemStatus.completed,
      actualDurationSeconds: 12,
      originalDurationSeconds: null,
      selectedContentId: 'present_moment',
      selectedContentText: 'Just for today I will live in this moment.',
    );

    final decoded = RitualItemRecord.fromJson(record.toJson());
    expect(decoded.selectedContentId, 'present_moment');
    expect(
      decoded.selectedContentText,
      'Just for today I will live in this moment.',
    );
    expect(RitualItemRecordHiveFields.selectedContentId, 5);
    expect(RitualItemRecordHiveFields.selectedContentText, 6);

    final releasedShape = Map<String, dynamic>.of(record.toJson())
      ..remove('selectedContentId')
      ..remove('selectedContentText');
    expect(RitualItemRecord.fromJson(releasedShape).selectedContentId, isNull);
  });

  test('Hive adapters preserve all three portable fields', () async {
    final directory = await Directory.systemTemp.createTemp(
      'twelve_step_randomizer_fields_',
    );
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    _registerMorningAdapters();

    final itemBox = await Hive.openBox<RitualItem>('items');
    final recordBox = await Hive.openBox<RitualItemRecord>('records');
    await itemBox.put(
      'item',
      RitualItem(
        id: 'item',
        name: 'Just for Today',
        type: RitualItemType.prayer,
        randomizerSourceId: 'just_for_today',
      ),
    );
    await recordBox.put(
      'record',
      RitualItemRecord(
        ritualItemId: 'item',
        ritualItemName: 'Just for Today',
        status: RitualItemStatus.completed,
        selectedContentId: 'present_moment',
        selectedContentText: 'Just for today I will live in this moment.',
      ),
    );

    expect(itemBox.get('item')!.randomizerSourceId, 'just_for_today');
    expect(recordBox.get('record')!.selectedContentId, 'present_moment');
    expect(
      recordBox.get('record')!.selectedContentText,
      'Just for today I will live in this moment.',
    );
  });

  test(
    'restore and canonical JSON Drive payload preserve the fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'twelve_step_randomizer_backup_',
      );
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      Hive.init(directory.path);
      _registerMorningAdapters();
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

      final result = await BackupRestoreService.restoreFromPayload(
        <String, dynamic>{
          'version': '8.0',
          'morningRitualItems': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'retreat-v1-just-for-today',
              'name': 'Just for Today',
              'type': 1,
              'durationSeconds': null,
              'prayerText': 'A statement is selected when the ritual begins.',
              'sortOrder': 0,
              'isActive': true,
              'vibrateEnabled': true,
              'soundEnabled': true,
              'soundId': null,
              'randomizerSourceId': 'just_for_today',
              'lastModified': '2026-08-01T08:00:00.000Z',
            },
          ],
          'morningRitualEntries': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'history-1',
              'date': '2026-08-01',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'ritualItemId': 'retreat-v1-just-for-today',
                  'ritualItemName': 'Just for Today',
                  'status': 0,
                  'actualDurationSeconds': 12,
                  'originalDurationSeconds': null,
                  'selectedContentId': 'present_moment',
                  'selectedContentText':
                      'Just for today I will live in this moment.',
                },
              ],
              'startedAt': '2026-08-01T06:00:00.000Z',
              'completedAt': '2026-08-01T06:01:00.000Z',
              'lastModified': '2026-08-01T06:01:00.000Z',
            },
          ],
        },
        createSafetyBackup: false,
      );
      expect(result.success, isTrue, reason: result.error);

      final rebuilt = SyncPayloadBuilder.buildPayload();
      final item =
          (rebuilt['morningRitualItems'] as List<dynamic>).single
              as Map<String, dynamic>;
      final entry =
          (rebuilt['morningRitualEntries'] as List<dynamic>).single
              as Map<String, dynamic>;
      final record =
          (entry['items'] as List<dynamic>).single as Map<String, dynamic>;
      expect(rebuilt['version'], '8.0');
      expect(item['randomizerSourceId'], 'just_for_today');
      expect(record['selectedContentId'], 'present_moment');
      expect(
        record['selectedContentText'],
        'Just for today I will live in this moment.',
      );
    },
  );
}

void _registerMorningAdapters() {
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
}
