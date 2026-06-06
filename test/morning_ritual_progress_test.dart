import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_ritual_service.dart';

// Regression tests for the device-local in-progress morning-ritual draft.
//
// The draft lets a partially-completed ritual survive navigating away / app
// restart, and resets on a new calendar day. It lives in the `settings` Hive
// box and is intentionally NOT part of the Drive sync payload, so these tests
// only need an untyped settings box (no adapters / no sync).
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mr_progress_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  RitualItemRecord record(String name) => RitualItemRecord(
        ritualItemId: 'id-$name',
        ritualItemName: name,
        status: RitualItemStatus.completed,
      );

  group('MorningRitualService progress draft', () {
    test('round-trips an in-progress ritual saved earlier the same day', () async {
      final today = DateTime(2026, 6, 6, 7, 30);
      await MorningRitualService.saveProgress(
        date: today,
        currentItemIndex: 2,
        startedAt: DateTime(2026, 6, 6, 7, 0),
        records: [record('meditation'), record('prayer')],
      );

      final loaded = MorningRitualService.loadProgress(DateTime(2026, 6, 6, 9, 0));
      expect(loaded, isNotNull);
      expect(loaded!['currentItemIndex'], 2);
      expect((loaded['records'] as List).length, 2);

      final restored = (loaded['records'] as List)
          .map((j) => RitualItemRecord.fromJson(j as Map<String, dynamic>))
          .toList();
      expect(restored[0].ritualItemName, 'meditation');
      expect(restored[1].status, RitualItemStatus.completed);
    });

    test('a draft from a previous day is treated as stale and discarded', () async {
      await MorningRitualService.saveProgress(
        date: DateTime(2026, 6, 5, 7, 30), // yesterday
        currentItemIndex: 1,
        startedAt: DateTime(2026, 6, 5, 7, 0),
        records: [record('meditation')],
      );

      // Loading "today" must not resurrect yesterday's progress...
      final loaded = MorningRitualService.loadProgress(DateTime(2026, 6, 6, 7, 0));
      expect(loaded, isNull);

      // ...and the stale draft must have been cleared from storage.
      expect(Hive.box('settings').get('morning_ritual_progress'), isNull);
    });

    test('clearProgress removes the saved draft', () async {
      final today = DateTime(2026, 6, 6, 7, 30);
      await MorningRitualService.saveProgress(
        date: today,
        currentItemIndex: 0,
        startedAt: today,
        records: const [],
      );
      expect(MorningRitualService.loadProgress(today), isNotNull);

      await MorningRitualService.clearProgress();
      expect(MorningRitualService.loadProgress(today), isNull);
    });
  });
}
