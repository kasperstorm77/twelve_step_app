import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/agnosticism/models/barrier_power_pair.dart';
import 'package:twelvestepsapp/fourth_step/models/i_am_definition.dart';
import 'package:twelvestepsapp/fourth_step/models/inventory_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/shared/services/sync_payload_builder.dart';

import 'support/hive_test_harness.dart';

/// Writes a **real** export for the other app's validator to chew on.
///
/// This is not a fixture in the usual sense: it is produced by the live
/// `SyncPayloadBuilder`, seeded with the awkward cases that have actually
/// broken the cross-app contract before — a Danish Just for Today draw, a pair
/// with a connected fear and one without, an archived pair, and definitions
/// whose sort orders must come out contiguous from zero.
///
/// `scripts/verify-cross-app.sh` runs this, then feeds the output through
/// Emotional Sobriety's own `BackupValidator`. Hand-authoring either side is
/// what let the last cross-app defect through both test suites.
const exportPath = 'build/cross_app/twelve_steps_export.json';

void main() {
  setUp(openAllBoxes);
  tearDown(closeAllBoxes);

  test('writes a realistic export for the other app to validate', () async {
    final iAm = Hive.box<IAmDefinition>('i_am_definitions');
    await iAm.add(IAmDefinition(id: 'i-am-1', name: 'Sober today'));
    await iAm.add(
      IAmDefinition(
        id: 'i-am-2',
        name: 'Ædru i dag',
        reasonToExist: 'En dag ad gangen',
      ),
    );

    await Hive.box<InventoryEntry>('entries').add(
      InventoryEntry(
        'My manager',
        'Gave away the project I had been leading',
        'Self-esteem, ambition, security',
        'I never said that I wanted it',
        'Pride, self-pity',
        id: 'entry-1',
        iAmIds: ['i-am-1'],
        order: 1,
      ),
    );
    // Danish text: the other app rejects a payload it cannot decode, and
    // non-ASCII is where a UTF-8 mistake would show up first.
    await Hive.box<InventoryEntry>('entries').add(
      InventoryEntry(
        'Min bror',
        'Gentog en gammel historie om mig',
        'Personlige forhold, stolthed',
        'Jeg har fortalt værre om ham',
        'Vrede, uærlighed',
        id: 'entry-2',
        iAmIds: ['i-am-2'],
        order: 2,
      ),
    );

    final pairs = Hive.box<BarrierPowerPair>('agnosticism_pairs');
    await pairs.put(
      'pair-fear',
      BarrierPowerPair(
        id: 'pair-fear',
        barrier: 'I have to be right',
        power: 'I can be wrong and still be loved',
        connectedFear: 'Being dismissed',
        createdAt: DateTime.utc(2026, 8, 1, 6),
        position: 0,
      ),
    );
    // An empty connected fear means "not recorded yet" and must survive as
    // empty — never be dropped, never fail the other side's validation.
    await pairs.put(
      'pair-plain',
      BarrierPowerPair(
        id: 'pair-plain',
        barrier: 'Jeg skal klare alt selv',
        power: 'Jeg må bede om hjælp',
        createdAt: DateTime.utc(2026, 8, 1, 7),
        position: 1,
      ),
    );
    await pairs.put(
      'pair-archived',
      BarrierPowerPair(
        id: 'pair-archived',
        barrier: 'Nothing ever changes',
        power: 'Today is not yesterday',
        connectedFear: 'Hopelessness',
        createdAt: DateTime.utc(2026, 7, 1, 6),
        archivedAt: DateTime.utc(2026, 8, 2, 6),
        isArchived: true,
        position: 2,
      ),
    );

    // Definitions: sortOrder must be unique and contiguous from zero, and at
    // most one may name a randomizer source. A gap makes the other app refuse
    // the whole file — not just the Morning section.
    final items = Hive.box<RitualItem>('morning_ritual_items');
    await items.put(
      'item-timer',
      RitualItem(
        id: 'item-timer',
        name: 'Stille bøn',
        type: RitualItemType.timer,
        durationSeconds: 300,
        sortOrder: 0,
        soundId: 'system_default_alarm',
      ),
    );
    await items.put(
      'item-prayer',
      RitualItem(
        id: 'item-prayer',
        name: '3rd Step Prayer',
        type: RitualItemType.prayer,
        prayerText: 'God, I offer myself to Thee',
        sortOrder: 1,
      ),
    );
    await items.put(
      'item-random',
      RitualItem(
        id: 'item-random',
        name: 'Kun for i dag',
        type: RitualItemType.prayer,
        randomizerSourceId: 'just_for_today',
        sortOrder: 2,
      ),
    );

    // A finished day carrying a Danish draw: the snapshot pair must be both
    // present, and its option id must be one the other app's catalog knows.
    await Hive.box<MorningRitualEntry>('morning_ritual_entries').put(
      'entry-day',
      MorningRitualEntry(
        id: 'entry-day',
        date: DateTime(2026, 8, 6),
        startedAt: DateTime.utc(2026, 8, 6, 5, 30),
        completedAt: DateTime.utc(2026, 8, 6, 5, 52),
        lastModified: DateTime.utc(2026, 8, 6, 5, 52),
        items: [
          RitualItemRecord(
            ritualItemId: 'item-timer',
            ritualItemName: 'Stille bøn',
            status: RitualItemStatus.completed,
            actualDurationSeconds: 300,
            originalDurationSeconds: 300,
          ),
          RitualItemRecord(
            ritualItemId: 'item-prayer',
            ritualItemName: '3rd Step Prayer',
            status: RitualItemStatus.skipped,
          ),
          RitualItemRecord(
            ritualItemId: 'item-random',
            ritualItemName: 'Kun for i dag',
            status: RitualItemStatus.completed,
            selectedContentId: 'happy_and_still',
            selectedContentText:
                'Kun for i dag vil jeg være glad. Jeg vil ikke have '
                'forventninger eller stille krav i dag.',
          ),
        ],
      ),
    );

    final payload = SyncPayloadBuilder.buildPayload();

    // Guard the invariants the other app enforces on the whole file, so a
    // failure here names the cause instead of surfacing as "invalid backup".
    expect(payload['version'], '8.0');
    expect(payload.containsKey('product'), isFalse);
    final ritualItems = (payload['morningRitualItems'] as List)
        .cast<Map<String, dynamic>>();
    final orders = ritualItems.map((i) => i['sortOrder'] as int).toList()
      ..sort();
    expect(
      orders,
      List<int>.generate(orders.length, (i) => i),
      reason: 'sortOrder must be unique and contiguous from zero',
    );
    expect(
      ritualItems.where((i) => i['randomizerSourceId'] != null).length,
      lessThanOrEqualTo(1),
      reason: 'the other app refuses a backup with two randomized items',
    );

    final file = File(exportPath);
    await file.parent.create(recursive: true);
    // UTF-8, like every real backup — never String.codeUnits.
    await file.writeAsBytes(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );

    expect(file.existsSync(), isTrue);
    // ignore: avoid_print
    print('cross-app export written: ${file.absolute.path}');
  });
}
