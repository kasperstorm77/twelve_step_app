import 'package:flutter/material.dart';
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
import 'package:twelvestepsapp/shared/services/app_settings_service.dart';
import 'package:twelvestepsapp/shared/services/backup_restore_service.dart';
import 'package:twelvestepsapp/shared/services/sync_payload_builder.dart';

import 'support/hive_test_harness.dart';

/// Round-tripping the boxes only this app has (implementation plan P3.3).
///
/// The cross-app sections already had coverage; people, reflections, gratitude,
/// notifications and appSettings had none, and neither did the two legacy
/// import aliases or the "I Am definitions before entries" ordering that the
/// restore path depends on.
void main() {
  setUp(openAllBoxes);
  tearDown(closeAllBoxes);

  Future<Map<String, dynamic>> exportThenWipe() async {
    final payload = SyncPayloadBuilder.buildPayload();
    await clearAllDataBoxes();
    return payload;
  }

  group('this app\'s own sections survive export → restore', () {
    test(
      'people, reflections, gratitude and notifications all come back',
      () async {
        await Hive.box<Person>('people_box').put(
          'p1',
          Person(
            internalId: 'p1',
            name: 'Someone I owe',
            amends: 'Return what I took',
            column: ColumnType.maybe,
            amendsDone: true,
            sortOrder: 2000,
          ),
        );
        await Hive.box<ReflectionEntry>('reflections_box').put(
          'r1',
          ReflectionEntry(
            internalId: 'r1',
            date: DateTime(2026, 8, 6),
            type: ReflectionType.afraid,
            detail: 'Money again',
          ),
        );
        // The thinking-focus slider is not its own model — it is a reflection
        // with thinkingFocus set, and it has to survive as one.
        await Hive.box<ReflectionEntry>('reflections_box').put(
          'r2',
          ReflectionEntry(
            internalId: 'r2',
            date: DateTime(2026, 8, 6),
            type: ReflectionType.godsForgiveness,
            thinkingFocus: 7,
          ),
        );
        await Hive.box<GratitudeEntry>('gratitude_box').add(
          GratitudeEntry(
            date: DateTime(2026, 8, 6),
            gratitudeTowards: 'My sponsor',
            gratefulFor: 'Picking up the phone',
            createdAt: DateTime(2026, 8, 6, 7, 30),
          ),
        );
        await Hive.box<AppNotification>('notifications_box').put(
          'n1',
          AppNotification(
            id: 'n1',
            notificationId: 4242,
            title: 'Evening review',
            body: 'Ten minutes before bed',
            enabled: true,
            scheduleType: NotificationScheduleType.weekly,
            timeMinutes: 21 * 60 + 30,
            weekdays: const [1, 3, 5],
            vibrateEnabled: false,
            soundEnabled: true,
          ),
        );

        final payload = await exportThenWipe();
        final result = await BackupRestoreService.restoreFromPayload(
          payload,
          createSafetyBackup: false,
        );
        expect(result.success, isTrue, reason: result.error);
        expect(result.counts.skippedRecords, 0);

        final person = Hive.box<Person>('people_box').values.single;
        expect(person.internalId, 'p1');
        expect(person.name, 'Someone I owe');
        expect(person.amends, 'Return what I took');
        expect(person.column, ColumnType.maybe);
        expect(person.amendsDone, isTrue);
        expect(person.sortOrder, 2000);

        final reflections = Hive.box<ReflectionEntry>(
          'reflections_box',
        ).values.toList()..sort((a, b) => a.internalId.compareTo(b.internalId));
        expect(reflections, hasLength(2));
        expect(reflections.first.type, ReflectionType.afraid);
        expect(reflections.first.detail, 'Money again');
        expect(reflections.first.thinkingFocus, isNull);
        expect(reflections.last.thinkingFocus, 7);

        final gratitude = Hive.box<GratitudeEntry>(
          'gratitude_box',
        ).values.single;
        expect(gratitude.gratitudeTowards, 'My sponsor');
        expect(gratitude.gratefulFor, 'Picking up the phone');
        expect(gratitude.createdAt, DateTime(2026, 8, 6, 7, 30));

        final reminder = Hive.box<AppNotification>(
          'notifications_box',
        ).values.single;
        expect(reminder.notificationId, 4242);
        expect(reminder.title, 'Evening review');
        expect(reminder.scheduleType, NotificationScheduleType.weekly);
        expect(reminder.timeMinutes, 21 * 60 + 30);
        expect(reminder.weekdays, [1, 3, 5]);
        expect(reminder.vibrateEnabled, isFalse);
        expect(reminder.soundEnabled, isTrue);
      },
    );

    test(
      'appSettings round-trips the auto-load window and compact view',
      () async {
        await AppSettingsService.saveMorningRitualSettings(
          enabled: true,
          startTime: const TimeOfDay(hour: 6, minute: 15),
          endTime: const TimeOfDay(hour: 8, minute: 45),
        );
        await AppSettingsService.setFourthStepCompactViewEnabled(true);

        final payload = SyncPayloadBuilder.buildPayload();
        await Hive.box<dynamic>('settings').clear();

        // A wiped settings box must read back the canonical defaults, not 06:00
        // from one code path and 05:00 from another (plan P2.3).
        final wiped = AppSettingsService.getMorningRitualSettings();
        expect(wiped['enabled'], isFalse);
        expect(wiped['startTime'], AppSettingsService.defaultMorningStartTime);
        expect(wiped['endTime'], AppSettingsService.defaultMorningEndTime);

        final result = await BackupRestoreService.restoreFromPayload(
          payload,
          createSafetyBackup: false,
        );
        expect(result.success, isTrue, reason: result.error);

        final restored = AppSettingsService.getMorningRitualSettings();
        expect(restored['enabled'], isTrue);
        expect(restored['startTime'].hour, 6);
        expect(restored['startTime'].minute, 15);
        expect(restored['endTime'].hour, 8);
        expect(restored['endTime'].minute, 45);
        expect(AppSettingsService.getFourthStepCompactViewEnabled(), isTrue);
      },
    );
  });

  group('import compatibility the restore path must keep', () {
    test(
      'legacy gratitudeEntries and agnosticismPapers aliases still import',
      () async {
        // Export only ever writes `gratitude` / `agnosticism`; a backup written
        // by an old build carries the other names and must still restore.
        final result = await BackupRestoreService.restoreFromPayload(
          <String, dynamic>{
            'version': '8.0',
            'gratitudeEntries': [
              {
                'date': DateTime(2026, 8, 5).toIso8601String(),
                'gratitudeTowards': 'A quiet morning',
                'gratefulFor': 'No phone',
                'createdAt': DateTime(2026, 8, 5, 6).toIso8601String(),
              },
            ],
            'agnosticismPapers': [
              {
                'id': 'a1',
                'barrier': 'I have to be right',
                'power': 'I can be wrong and still be loved',
                'connectedFear': 'Being dismissed',
                'isArchived': false,
                'createdAt': DateTime(2026, 8, 5).toIso8601String(),
                'lastModified': DateTime(2026, 8, 5).toIso8601String(),
              },
            ],
          },
          createSafetyBackup: false,
        );

        expect(result.success, isTrue, reason: result.error);
        expect(Hive.box<GratitudeEntry>('gratitude_box').length, 1);
        expect(Hive.box<BarrierPowerPair>('agnosticism_pairs').length, 1);
        expect(
          Hive.box<BarrierPowerPair>('agnosticism_pairs').values.single.barrier,
          'I have to be right',
        );
      },
    );

    test(
      'I Am definitions are written before the entries that reference them',
      () async {
        // Entries carry I Am ids; if entries landed first the definitions they
        // point at would not exist yet for anything reading during the restore.
        await Hive.box<IAmDefinition>(
          'i_am_definitions',
        ).put('iam1', IAmDefinition(id: 'iam1', name: 'Sober today'));
        await Hive.box<InventoryEntry>('entries').put(
          'e1',
          InventoryEntry(
            'A resentment',
            'The cause',
            'My security',
            'My part',
            'Fear',
            id: 'e1',
            iAmIds: ['iam1'],
            order: 1,
          ),
        );

        final payload = await exportThenWipe();
        final keys = payload.keys.toList();
        expect(
          keys.indexOf('iAmDefinitions'),
          lessThan(keys.indexOf('entries')),
          reason: 'the payload itself must carry definitions before entries',
        );

        final result = await BackupRestoreService.restoreFromPayload(
          payload,
          createSafetyBackup: false,
        );
        expect(result.success, isTrue, reason: result.error);

        final entry = Hive.box<InventoryEntry>('entries').values.single;
        expect(entry.effectiveIAmIds, ['iam1']);
        // Definitions are stored under Hive's own auto-increment keys; `id` is
        // the field entries reference, so that is what has to survive.
        expect(
          Hive.box<IAmDefinition>('i_am_definitions').values.map((d) => d.id),
          contains('iam1'),
          reason: 'the definition the restored entry points at must exist',
        );
      },
    );

    test('a section the payload omits leaves its box untouched', () async {
      await Hive.box<Person>('people_box').put(
        'keep',
        Person(internalId: 'keep', name: 'Still here', column: ColumnType.yes),
      );

      final result = await BackupRestoreService.restoreFromPayload(
        <String, dynamic>{'version': '8.0', 'gratitude': <dynamic>[]},
        createSafetyBackup: false,
      );

      expect(result.success, isTrue, reason: result.error);
      expect(Hive.box<Person>('people_box').length, 1);
    });
  });

  test('every box the payload builder reads is one main.dart opens', () {
    // SyncPayloadBuilder reads each box with Hive.box(...) unguarded, so a box
    // it expects but main.dart did not open throws at upload time.
    expect(() => SyncPayloadBuilder.buildPayload(), returnsNormally);
    final payload = SyncPayloadBuilder.buildPayload();
    expect(payload['version'], '8.0');
    for (final key in const [
      'iAmDefinitions',
      'entries',
      'people',
      'reflections',
      'gratitude',
      'agnosticism',
      'morningRitualItems',
      'morningRitualEntries',
      'notifications',
      'appSettings',
    ]) {
      expect(payload.containsKey(key), isTrue, reason: 'missing $key');
    }
    expect(
      payload.containsKey('product'),
      isFalse,
      reason:
          'this app never tags a product; that is what makes it not foreign',
    );
    expect(
      Hive.box<MorningRitualEntry>('morning_ritual_entries').isOpen,
      isTrue,
    );
    expect(Hive.box<RitualItem>('morning_ritual_items').isOpen, isTrue);
  });
}
