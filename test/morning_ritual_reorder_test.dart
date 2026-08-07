import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/morning_ritual/services/morning_ritual_service.dart';

import 'support/hive_test_harness.dart';

/// Reordering with inactive definitions in the set (implementation plan P3.5).
///
/// `reorderRitualItems` writes `sortOrder` across **all** definitions — active
/// first, then inactive — because Emotional Sobriety refuses a whole backup
/// whose Morning orders are not unique and contiguous from zero. Nothing in the
/// UI can create an inactive item today; only an import can, so this path had
/// never been exercised against a real mixed set.
void main() {
  setUp(openAllBoxes);
  tearDown(closeAllBoxes);

  Future<void> seed(List<RitualItem> items) async {
    for (final item in items) {
      await MorningRitualService.ritualItemsBox.put(item.id, item);
    }
  }

  RitualItem item(String id, {required int sortOrder, bool isActive = true}) =>
      RitualItem(
        id: id,
        name: id,
        type: RitualItemType.prayer,
        prayerText: 'text for $id',
        sortOrder: sortOrder,
        isActive: isActive,
      );

  List<String> orderOf(List<RitualItem> items) =>
      items.map((i) => i.id).toList();

  void expectContiguousFromZero() {
    final orders = MorningRitualService.getAllRitualItems()
        .map((i) => i.sortOrder)
        .toList();
    expect(
      orders,
      List<int>.generate(orders.length, (i) => i),
      reason:
          'a gap or duplicate here makes the other app refuse the entire '
          'backup, not just the Morning section',
    );
  }

  test('moving an active item renumbers the inactive ones after it', () async {
    await seed([
      item('a', sortOrder: 0),
      item('hidden', sortOrder: 1, isActive: false),
      item('b', sortOrder: 2),
      item('c', sortOrder: 3),
    ]);

    // The UI list only shows a, b, c — move c to the front of that list.
    await MorningRitualService.reorderRitualItems(2, 0);

    expect(orderOf(MorningRitualService.getActiveRitualItems()), [
      'c',
      'a',
      'b',
    ]);
    // The inactive one keeps existing and lands after every active item.
    expect(orderOf(MorningRitualService.getAllRitualItems()), [
      'c',
      'a',
      'b',
      'hidden',
    ]);
    expectContiguousFromZero();
  });

  test('an inactive item never collides with an active one', () async {
    // The collision this guards: inactive definitions used to keep their old
    // sortOrder while the active ones were renumbered from zero.
    await seed([
      item('a', sortOrder: 0),
      item('b', sortOrder: 1),
      item('ghost1', sortOrder: 0, isActive: false),
      item('ghost2', sortOrder: 1, isActive: false),
    ]);

    await MorningRitualService.reorderRitualItems(0, 2);

    final all = MorningRitualService.getAllRitualItems();
    expect(orderOf(all), ['b', 'a', 'ghost1', 'ghost2']);
    expect(
      all.map((i) => i.sortOrder).toSet(),
      hasLength(all.length),
      reason: 'sort orders must be unique across active and inactive',
    );
    expectContiguousFromZero();
  });

  test('reordering an all-inactive set leaves a valid sequence', () async {
    await seed([
      item('x', sortOrder: 5, isActive: false),
      item('y', sortOrder: 9, isActive: false),
    ]);

    // Nothing is visible to drag, but a restore can leave gapped orders behind;
    // migrateSortOrders is what repairs them.
    await MorningRitualService.migrateSortOrders();

    expect(orderOf(MorningRitualService.getAllRitualItems()), ['x', 'y']);
    expectContiguousFromZero();
  });

  test(
    'deleting an active item compacts the whole set, inactive included',
    () async {
      await seed([
        item('a', sortOrder: 0),
        item('gone', sortOrder: 1),
        item('hidden', sortOrder: 2, isActive: false),
        item('b', sortOrder: 3),
      ]);

      await MorningRitualService.deleteRitualItem('gone');

      expect(MorningRitualService.getAllRitualItems(), hasLength(3));
      expectContiguousFromZero();
    },
  );

  test(
    'migrateSortOrders is idempotent on an already-contiguous set',
    () async {
      await seed([
        item('a', sortOrder: 0),
        item('hidden', sortOrder: 1, isActive: false),
        item('b', sortOrder: 2),
      ]);

      await MorningRitualService.migrateSortOrders();
      final first = orderOf(MorningRitualService.getAllRitualItems());
      await MorningRitualService.migrateSortOrders();

      expect(orderOf(MorningRitualService.getAllRitualItems()), first);
      expectContiguousFromZero();
    },
  );
}
