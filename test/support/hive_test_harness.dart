import 'dart:io';

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

/// Opens the same box set `main.dart` opens, on a throwaway directory.
///
/// `SyncPayloadBuilder` reads every box with `Hive.box<T>(...)` unguarded, so a
/// test that opens a subset fails for the wrong reason. Keep this list in step
/// with `main.dart` — that is the same invariant the app has to hold.

/// The data boxes, in the order `main.dart` opens them. `settings` is
/// deliberately separate: it is untyped and has no corruption fallback.
const dataBoxNames = <String>[
  'entries',
  'i_am_definitions',
  'people_box',
  'reflections_box',
  'gratitude_box',
  'agnosticism_pairs',
  'morning_ritual_items',
  'morning_ritual_entries',
  'notifications_box',
];

Directory? _directory;

Future<void> openAllBoxes() async {
  _directory = await Directory.systemTemp.createTemp('twelve_step_test_');
  Hive.init(_directory!.path);
  registerAllAdapters();
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
}

/// Empties every data box, the way a restore's "clear and rewrite" would find
/// them. Typed boxes cannot be reopened as `Box<dynamic>`, so each is cleared
/// through its own type.
Future<void> clearAllDataBoxes() async {
  await Hive.box<InventoryEntry>('entries').clear();
  await Hive.box<IAmDefinition>('i_am_definitions').clear();
  await Hive.box<Person>('people_box').clear();
  await Hive.box<ReflectionEntry>('reflections_box').clear();
  await Hive.box<GratitudeEntry>('gratitude_box').clear();
  await Hive.box<BarrierPowerPair>('agnosticism_pairs').clear();
  await Hive.box<RitualItem>('morning_ritual_items').clear();
  await Hive.box<MorningRitualEntry>('morning_ritual_entries').clear();
  await Hive.box<AppNotification>('notifications_box').clear();
}

Future<void> closeAllBoxes() async {
  await Hive.deleteFromDisk();
  await _directory?.delete(recursive: true);
  _directory = null;
}

void registerAllAdapters() {
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
