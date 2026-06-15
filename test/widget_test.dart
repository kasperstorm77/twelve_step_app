// Smoke test: verifies the app builds and renders its first frame without
// runtime errors.
//
// The widget tree reads Hive boxes during its first build (e.g.
// InventoryService opens the `entries` box in initState), so this test mirrors
// main.dart's Hive initialization — register every adapter and open every box —
// against a temporary directory before pumping the app.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:twelvestepsapp/app/app_module.dart';
import 'package:twelvestepsapp/app/app_widget.dart';
import 'package:twelvestepsapp/fourth_step/models/inventory_entry.dart';
import 'package:twelvestepsapp/fourth_step/models/i_am_definition.dart';
import 'package:twelvestepsapp/shared/models/app_entry.dart';
import 'package:twelvestepsapp/eighth_step/models/person.dart';
import 'package:twelvestepsapp/evening_ritual/models/reflection_entry.dart';
import 'package:twelvestepsapp/morning_ritual/models/ritual_item.dart';
import 'package:twelvestepsapp/morning_ritual/models/morning_ritual_entry.dart';
import 'package:twelvestepsapp/gratitude/models/gratitude_entry.dart';
import 'package:twelvestepsapp/agnosticism/models/barrier_power_pair.dart';
import 'package:twelvestepsapp/notifications/models/app_notification.dart';

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('twelve_steps_test_hive');
    Hive.init(hiveDir.path);

    // Mirror main.dart: every adapter is registered before any box is opened.
    _registerAdapter(InventoryEntryAdapter());
    _registerAdapter(InventoryCategoryAdapter());
    _registerAdapter(IAmDefinitionAdapter());
    _registerAdapter(AppEntryAdapter());
    _registerAdapter(PersonAdapter());
    _registerAdapter(ColumnTypeAdapter());
    _registerAdapter(ReflectionEntryAdapter());
    _registerAdapter(ReflectionTypeAdapter());
    _registerAdapter(GratitudeEntryAdapter());
    _registerAdapter(BarrierPowerPairAdapter());
    _registerAdapter(RitualItemTypeAdapter());
    _registerAdapter(RitualItemAdapter());
    _registerAdapter(RitualItemStatusAdapter());
    _registerAdapter(RitualItemRecordAdapter());
    _registerAdapter(MorningRitualEntryAdapter());
    _registerAdapter(NotificationScheduleTypeAdapter());
    _registerAdapter(AppNotificationAdapter());

    // Open every box the app reads at build time (frozen names, see
    // docs/architecture.md §2.2).
    await Hive.openBox<InventoryEntry>('entries');
    await Hive.openBox<IAmDefinition>('i_am_definitions');
    await Hive.openBox<Person>('people_box');
    await Hive.openBox<ReflectionEntry>('reflections_box');
    await Hive.openBox<GratitudeEntry>('gratitude_box');
    await Hive.openBox<BarrierPowerPair>('agnosticism_pairs');
    await Hive.openBox<RitualItem>('morning_ritual_items');
    await Hive.openBox<MorningRitualEntry>('morning_ritual_entries');
    await Hive.openBox<AppNotification>('notifications_box');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(
      ModularApp(module: AppModule(), child: const AppWidget()),
    );

    // Let the first build settle (initState box reads, post-frame callbacks).
    await tester.pumpAndSettle();

    // initState schedules a post-frame uploads-blocked check that waits 500ms
    // before returning early (no prompt on a fresh install). Advance past it so
    // the timer fires rather than outliving the disposed widget tree.
    await tester.pump(const Duration(milliseconds: 600));

    // Basic smoke check: the app shell built without throwing.
    expect(find.byType(AppWidget), findsOneWidget);
  });
}
