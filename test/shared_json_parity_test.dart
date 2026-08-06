import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/agnosticism/models/barrier_power_pair.dart';
import 'package:twelvestepsapp/fourth_step/models/inventory_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';

/// Emotional Sobriety imports the five shared sections of this app's `8.0`
/// payload, and it requires every instant to name its zone. Writing a bare
/// local `DateTime.now()` produced values like `2026-08-06T11:38:38.113572`,
/// which that app rejected outright — the whole cross-app import failed on
/// real data while passing against UTC test fixtures. These tests pin the
/// wire format so the two apps stay byte-compatible.
final _zoned = RegExp(r'(?:Z|[+-]\d{2}:\d{2})$');

void main() {
  test('agnosticism instants are zoned', () {
    final pair = BarrierPowerPair(
      id: 'p1',
      barrier: 'B',
      power: 'P',
      connectedFear: 'F',
      // A local instant, exactly as the service creates it.
      createdAt: DateTime(2026, 8, 6, 11, 38, 38),
      archivedAt: DateTime(2026, 8, 6, 12),
      isArchived: true,
    );

    final json = pair.toJson();

    expect(json['createdAt'], matches(_zoned));
    expect(json['archivedAt'], matches(_zoned));
    expect(
      BarrierPowerPair.fromJson(json).createdAt.toUtc(),
      pair.createdAt.toUtc(),
    );
  });

  test('morning definition instants are zoned', () {
    final item = RitualItem(
      id: 'r1',
      name: 'Reading',
      type: RitualItemType.prayer,
      prayerText: 'Text',
      lastModified: DateTime(2026, 8, 6, 11, 38, 38),
    );

    expect(item.toJson()['lastModified'], matches(_zoned));
  });

  test('morning history instants are zoned and the date stays local', () {
    final entry = MorningRitualEntry(
      id: 'e1',
      date: DateTime(2026, 8, 6),
      items: [
        RitualItemRecord(
          ritualItemId: 'r1',
          ritualItemName: 'Reading',
          status: RitualItemStatus.completed,
          actualDurationSeconds: 30,
        ),
      ],
      startedAt: DateTime(2026, 8, 6, 6),
      completedAt: DateTime(2026, 8, 6, 6, 1),
      lastModified: DateTime(2026, 8, 6, 6, 1),
    );

    final json = entry.toJson();

    expect(json['startedAt'], matches(_zoned));
    expect(json['completedAt'], matches(_zoned));
    expect(json['lastModified'], matches(_zoned));
    // The ritual date is a calendar day, not an instant: converting it to UTC
    // would move an early-morning ritual to the previous day.
    expect(json['date'], '2026-08-06');
  });

  test('the shared record shapes carry exactly the expected keys', () {
    // Emotional Sobriety rejects unknown keys on these records, so a new field
    // here must be added there in the same change.
    expect(
      BarrierPowerPair(
        id: 'p',
        barrier: 'b',
        power: 'p',
        createdAt: DateTime(2026, 8, 6),
      ).toJson().keys.toSet(),
      <String>{
        'id',
        'barrier',
        'power',
        'isArchived',
        'createdAt',
        'archivedAt',
        'position',
        'connectedFear',
      },
    );

    expect(
      RitualItem(
        id: 'r',
        name: 'n',
        type: RitualItemType.prayer,
      ).toJson().keys.toSet(),
      <String>{
        'id',
        'name',
        'type',
        'durationSeconds',
        'prayerText',
        'sortOrder',
        'isActive',
        'vibrateEnabled',
        'soundEnabled',
        'soundId',
        'randomizerSourceId',
        'lastModified',
      },
    );

    expect(
      MorningRitualEntry(
        id: 'e',
        date: DateTime(2026, 8, 6),
        items: const [],
      ).toJson().keys.toSet(),
      <String>{
        'id',
        'date',
        'items',
        'startedAt',
        'completedAt',
        'lastModified',
      },
    );

    expect(
      InventoryEntry(
        'r',
        're',
        'a',
        'p',
        'd',
        id: 'i',
        order: 1,
        category: InventoryCategory.resentment,
        iAmIds: ['d1'],
      ).toJson().keys.toSet(),
      <String>{
        'id',
        'order',
        'resentment',
        'reason',
        'affect',
        'part',
        'defect',
        'iAmId',
        'iAmIds',
        'category',
      },
    );
  });

  test('the other app writes the same shared record shapes', () {
    // The reverse direction of the contract, proven against a payload captured
    // from Emotional Sobriety's own SyncPayloadBuilder. If either app adds a
    // key without the other, this is where it shows up — the two apps reject
    // unknown keys on these records, so a one-sided field is a broken import.
    final captured =
        jsonDecode(
              File(
                'test/fixtures/emotional_sobriety_export_1_0.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    Set<String> keysOf(String section, {int index = 0}) =>
        ((captured[section] as List<dynamic>)[index] as Map<String, dynamic>)
            .keys
            .toSet();

    expect(
      keysOf('agnosticismPairs'),
      BarrierPowerPair(
        id: 'p',
        barrier: 'b',
        power: 'p',
        createdAt: DateTime(2026, 8, 6),
      ).toJson().keys.toSet(),
    );
    expect(
      keysOf('morningRitualItems'),
      RitualItem(
        id: 'r',
        name: 'n',
        type: RitualItemType.prayer,
      ).toJson().keys.toSet(),
    );
    expect(
      keysOf('morningRitualEntries'),
      MorningRitualEntry(
        id: 'e',
        date: DateTime(2026, 8, 6),
        items: const [],
      ).toJson().keys.toSet(),
    );

    // And it round-trips through this app's decoders unchanged.
    for (final section in [
      'agnosticismPairs',
      'morningRitualItems',
      'morningRitualEntries',
    ]) {
      for (final raw in captured[section] as List<dynamic>) {
        final json = raw as Map<String, dynamic>;
        final reencoded = switch (section) {
          'agnosticismPairs' => BarrierPowerPair.fromJson(json).toJson(),
          'morningRitualItems' => RitualItem.fromJson(json).toJson(),
          _ => MorningRitualEntry.fromJson(json).toJson(),
        };
        expect(reencoded.keys.toSet(), json.keys.toSet());
      }
    }
  });

  test('instants written before this change still read', () {
    // Records already on devices carry zone-less local strings; they must keep
    // decoding rather than throwing.
    final pair = BarrierPowerPair.fromJson(<String, dynamic>{
      'id': 'p1',
      'barrier': 'B',
      'power': 'P',
      'createdAt': '2026-08-06T11:38:38.113572',
      'position': 0,
    });

    expect(pair.createdAt.year, 2026);
    expect(pair.toJson()['createdAt'], matches(_zoned));
  });
}
