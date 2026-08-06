import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/agnosticism/models/barrier_power_pair.dart';

void main() {
  test('a pair written before the field decodes with an empty fear', () {
    final released = <String, dynamic>{
      'id': 'pair-1',
      'barrier': 'My finances',
      'power': 'Trust',
      'isArchived': false,
      'createdAt': '2026-08-01T06:00:00.000Z',
      'archivedAt': null,
      'position': 0,
    };

    final pair = BarrierPowerPair.fromJson(released);

    expect(pair.connectedFear, isEmpty);
    expect(pair.barrier, 'My finances');
    expect(pair.power, 'Trust');
  });

  test('the connecting fear round-trips through JSON', () {
    final pair = BarrierPowerPair(
      id: 'pair-2',
      barrier: 'My health',
      power: 'Acceptance',
      createdAt: DateTime.utc(2026, 8, 1, 6),
      connectedFear: 'Losing my footing',
    );

    expect(pair.toJson()['connectedFear'], 'Losing my footing');
    expect(
      BarrierPowerPair.fromJson(pair.toJson()).connectedFear,
      'Losing my footing',
    );
  });

  test('an Emotional Sobriety pair decodes unchanged', () {
    // The other application always writes the field, so its payload must
    // survive a round trip through this one without losing the fear.
    final emotional = <String, dynamic>{
      'id': 'pair-3',
      'barrier': 'My work',
      'power': 'Patience',
      'isArchived': true,
      'createdAt': '2026-07-01T06:00:00.000Z',
      'archivedAt': '2026-07-20T06:00:00.000Z',
      'position': 0,
      'connectedFear': 'Being found out',
    };

    final pair = BarrierPowerPair.fromJson(emotional);

    expect(pair.connectedFear, 'Being found out');
    expect(pair.isArchived, isTrue);
    expect(pair.toJson()['connectedFear'], 'Being found out');
  });

  test('copyWith carries the fear and can replace it', () {
    final pair = BarrierPowerPair(
      id: 'pair-4',
      barrier: 'A barrier',
      power: 'A power',
      createdAt: DateTime.utc(2026, 8, 1),
      connectedFear: 'First fear',
    );

    expect(pair.copyWith().connectedFear, 'First fear');
    expect(
      pair.copyWith(connectedFear: 'Second fear').connectedFear,
      'Second fear',
    );
  });

  group('stored records', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('agnosticism_fear_');
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(BarrierPowerPairAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('a record stored without the field still reads', () async {
      // A record written by the released adapter carries seven fields; the
      // eighth must decode as null rather than throwing, because a throw here
      // would trigger the corruption fallback and wipe real user data.
      final box = await Hive.openBox<BarrierPowerPair>('agnosticism_pairs');
      final legacy = BarrierPowerPair(
        id: 'pair-5',
        barrier: 'Stored barrier',
        power: 'Stored power',
        createdAt: DateTime.utc(2026, 8, 1),
      )..storedConnectedFear = null;
      await box.put(legacy.id, legacy);
      await box.close();

      final reopened = await Hive.openBox<BarrierPowerPair>(
        'agnosticism_pairs',
      );
      final restored = reopened.get('pair-5')!;

      expect(restored.storedConnectedFear, isNull);
      expect(restored.connectedFear, isEmpty);
      expect(restored.barrier, 'Stored barrier');
    });

    test('writing a fear persists it', () async {
      final box = await Hive.openBox<BarrierPowerPair>('agnosticism_pairs');
      final pair = BarrierPowerPair(
        id: 'pair-6',
        barrier: 'Stored barrier',
        power: 'Stored power',
        createdAt: DateTime.utc(2026, 8, 1),
      );
      await box.put(pair.id, pair);
      pair.connectedFear = 'A written fear';
      await pair.save();
      await box.close();

      final reopened = await Hive.openBox<BarrierPowerPair>(
        'agnosticism_pairs',
      );

      expect(reopened.get('pair-6')!.connectedFear, 'A written fear');
    });
  });
}
