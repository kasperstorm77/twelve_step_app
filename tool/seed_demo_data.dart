// Generates realistic sample data as Hive box files for store screenshots.
//
// Not part of the app: run it with `dart run tool/seed_demo_data.dart <outDir>`
// and copy the resulting `*.hive` files into a simulator's app container. That
// keeps demo content out of the shipped code and means screenshots never show
// somebody's real recovery work with bars drawn over it.
//
// The content below is invented for illustration.
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

Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp/demo_hive';
  // Screenshots for the Danish listing need Danish content, not Danish chrome
  // wrapped around English sample text.
  final da = args.length > 1 && args[1] == 'da';
  T pick<T>(T en, T dk) => da ? dk : en;
  await Directory(out).create(recursive: true);
  Hive.init(out);
  Hive
    ..registerAdapter(InventoryEntryAdapter())
    ..registerAdapter(IAmDefinitionAdapter())
    ..registerAdapter(PersonAdapter())
    ..registerAdapter(ColumnTypeAdapter())
    ..registerAdapter(ReflectionEntryAdapter())
    ..registerAdapter(ReflectionTypeAdapter())
    ..registerAdapter(GratitudeEntryAdapter())
    ..registerAdapter(BarrierPowerPairAdapter())
    ..registerAdapter(RitualItemTypeAdapter())
    ..registerAdapter(RitualItemAdapter())
    ..registerAdapter(RitualItemStatusAdapter())
    ..registerAdapter(RitualItemRecordAdapter())
    ..registerAdapter(MorningRitualEntryAdapter())
    ..registerAdapter(InventoryCategoryAdapter())
    ..registerAdapter(NotificationScheduleTypeAdapter())
    ..registerAdapter(AppNotificationAdapter());

  final now = DateTime.now();
  DateTime day(int back) => DateTime(now.year, now.month, now.day - back);

  // ---- 4th Step -----------------------------------------------------------
  final iAms = await Hive.openBox<IAmDefinition>('i_am_definitions');
  await iAms.clear();
  await iAms.add(
    IAmDefinition(
      id: 'iam-1',
      name: pick('Sober member in recovery', 'Ædru medlem i bedring'),
      reasonToExist: pick(
        'To be useful to the people around me',
        'At være til nytte for dem omkring mig',
      ),
    ),
  );
  await iAms.add(
    IAmDefinition(
      id: 'iam-2',
      name: pick('Father', 'Far'),
      reasonToExist: pick('To be present', 'At være til stede'),
    ),
  );

  final entries = await Hive.openBox<InventoryEntry>('entries');
  await entries.clear();
  final inventory = pick(<List<String>>[
    [
      'My manager',
      'Gave the project I had been leading to someone else',
      'Self-esteem, ambition, security',
      'I never once said that I wanted it',
      'Pride, self-pity',
    ],
    [
      'My brother',
      'Repeated an old story about me at dinner',
      'Personal relationships, pride',
      'I have told worse stories about him',
      'Resentment, dishonesty',
    ],
    [
      'Money',
      'The account is lower than I let on to anyone',
      'Security, fear of the future',
      'I spent it and then hid the statements',
      'Fear, dishonesty',
    ],
  ], <List<String>>[
    [
      'Min chef',
      'Gav projektet, jeg havde ledet, til en anden',
      'Selvværd, ambition, tryghed',
      'Jeg sagde aldrig, at jeg gerne ville have det',
      'Stolthed, selvmedlidenhed',
    ],
    [
      'Min bror',
      'Gentog en gammel historie om mig til middagen',
      'Personlige relationer, stolthed',
      'Jeg har fortalt værre historier om ham',
      'Vrede, uærlighed',
    ],
    [
      'Penge',
      'Kontoen er lavere, end jeg har indrømmet over for nogen',
      'Tryghed, frygt for fremtiden',
      'Jeg brugte dem og gemte så kontoudtogene',
      'Frygt, uærlighed',
    ],
  ]);
  for (var i = 0; i < inventory.length; i += 1) {
    final e = inventory[i];
    await entries.add(
      InventoryEntry(
        e[0],
        e[1],
        e[2],
        e[3],
        e[4],
        id: 'entry-$i',
        order: i + 1,
        category: i == 2
            ? InventoryCategory.fear
            : InventoryCategory.resentment,
        iAmIds: const ['iam-1'],
      ),
    );
  }

  // ---- 8th Step -----------------------------------------------------------
  final people = await Hive.openBox<Person>('people_box');
  await people.clear();
  final amends = pick(<List<Object>>[
    ['My brother', ColumnType.yes, 'Coffee on Saturday. Say it plainly.', true],
    [
      'Mum',
      ColumnType.yes,
      'Tell her about the money before she hears it.',
      false,
    ],
    [
      'My old employer',
      ColumnType.maybe,
      'Ask my sponsor about the timing.',
      false,
    ],
    ['Anna', ColumnType.maybe, 'Living amends — just be reliable.', false],
    [
      'A neighbour I never named',
      ColumnType.no,
      'Contact would do more harm.',
      false,
    ],
  ], <List<Object>>[
    ['Min bror', ColumnType.yes, 'Kaffe på lørdag. Sig det ligeud.', true],
    [
      'Mor',
      ColumnType.yes,
      'Fortæl om pengene, før hun hører det andetsteds.',
      false,
    ],
    [
      'Min gamle arbejdsgiver',
      ColumnType.maybe,
      'Spørg min sponsor om timingen.',
      false,
    ],
    ['Anna', ColumnType.maybe, 'Levende godtgørelse — bare vær til at regne med.', false],
    [
      'En nabo jeg aldrig nævnte',
      ColumnType.no,
      'Kontakt ville gøre mere skade.',
      false,
    ],
  ]);
  for (var i = 0; i < amends.length; i += 1) {
    final a = amends[i];
    await people.put(
      'person-$i',
      Person(
        name: a[0] as String,
        column: a[1] as ColumnType,
        amends: a[2] as String,
        amendsDone: a[3] as bool,
        sortOrder: i * 1000,
      ),
    );
  }

  // ---- Gratitude ----------------------------------------------------------
  final gratitude = await Hive.openBox<GratitudeEntry>('gratitude_box');
  await gratitude.clear();
  final grateful = pick(<List<String>>[
    ['My sponsor', 'He picked up at half past six in the morning'],
    ['A quiet kitchen', 'Ten minutes before anyone else was awake'],
    ['The bus being late', 'I read two pages I would have skipped'],
    ['My daughter', 'She asked me to read to her again'],
  ], <List<String>>[
    ['Min sponsor', 'Han tog telefonen klokken halv syv om morgenen'],
    ['Et stille køkken', 'Ti minutter før nogen andre var vågne'],
    ['At bussen var forsinket', 'Jeg læste to sider, jeg ellers ville springe over'],
    ['Min datter', 'Hun bad mig læse for sig igen'],
  ]);
  for (var i = 0; i < grateful.length; i += 1) {
    await gratitude.add(
      GratitudeEntry(
        date: day(i ~/ 2),
        gratitudeTowards: grateful[i][0],
        gratefulFor: grateful[i][1],
        createdAt: day(i ~/ 2).add(const Duration(hours: 21)),
      ),
    );
  }

  // ---- Evening Ritual -----------------------------------------------------
  final reflections = await Hive.openBox<ReflectionEntry>('reflections_box');
  await reflections.clear();
  final reflected = pick(<List<Object>>[
    [ReflectionType.resentful, 'At the meeting, when I was interrupted.'],
    [ReflectionType.selfish, 'I let someone else clear up after dinner.'],
    [ReflectionType.kindAndLoving, 'Rang a newcomer back the same evening.'],
    [ReflectionType.correctiveMeasures, 'Apologise tomorrow, then let it go.'],
  ], <List<Object>>[
    [ReflectionType.resentful, 'På mødet, da jeg blev afbrudt.'],
    [ReflectionType.selfish, 'Jeg lod en anden rydde op efter middagen.'],
    [ReflectionType.kindAndLoving, 'Ringede en nytilkommen op samme aften.'],
    [ReflectionType.correctiveMeasures, 'Undskyld i morgen, og slip det så.'],
  ]);
  for (var i = 0; i < reflected.length; i += 1) {
    await reflections.put(
      'reflection-$i',
      ReflectionEntry(
        date: day(0),
        type: reflected[i][0] as ReflectionType,
        detail: reflected[i][1] as String,
      ),
    );
  }
  await reflections.put(
    'reflection-focus',
    ReflectionEntry(
      date: day(0),
      type: ReflectionType.resentful,
      thinkingFocus: 7,
    ),
  );

  // ---- Surrender & Correction --------------------------------------------
  final pairs = await Hive.openBox<BarrierPowerPair>('agnosticism_pairs');
  await pairs.clear();
  final surrender = pick(<List<String>>[
    [
      'Wanting to control how it turns out',
      'That it goes wrong without me',
      'I can do the footwork and leave the result',
    ],
    [
      'Needing to be right',
      'That being wrong makes me less',
      'I would rather be free than right',
    ],
    [
      'Keeping the money quiet',
      'That they will think less of me',
      'The truth costs less than the hiding',
    ],
    [
      'Rushing every conversation',
      'That I will be found out as not enough',
      'I have time. I can listen first',
    ],
  ], <List<String>>[
    [
      'At ville styre, hvordan det ender',
      'At det går galt uden mig',
      'Jeg kan gøre arbejdet og slippe resultatet',
    ],
    [
      'At skulle have ret',
      'At det gør mig mindre at tage fejl',
      'Jeg vil hellere være fri end have ret',
    ],
    [
      'At holde pengene skjult',
      'At de vil tænke mindre om mig',
      'Sandheden koster mindre end skjulet',
    ],
    [
      'At haste gennem hver samtale',
      'At jeg bliver afsløret som ikke nok',
      'Jeg har tid. Jeg kan lytte først',
    ],
  ]);
  for (var i = 0; i < surrender.length; i += 1) {
    await pairs.put(
      'pair-$i',
      BarrierPowerPair(
        id: 'pair-$i',
        barrier: surrender[i][0],
        connectedFear: surrender[i][1],
        power: surrender[i][2],
        createdAt: day(10 - i),
        position: i,
      ),
    );
  }

  // ---- Morning Ritual -----------------------------------------------------
  final items = await Hive.openBox<RitualItem>('morning_ritual_items');
  await items.clear();
  await items.put(
    'r0',
    RitualItem(
      id: 'r0',
      name: pick('Just for Today', 'Kun for i dag'),
      type: RitualItemType.prayer,
      prayerText: pick(
        'One reading is chosen when the ritual begins.',
        'Én læsning vælges, når ritualet begynder.',
      ),
      sortOrder: 0,
      randomizerSourceId: 'just_for_today',
    ),
  );
  await items.put(
    'r1',
    RitualItem(
      id: 'r1',
      name: pick('Silent meditation', 'Stille meditation'),
      type: RitualItemType.timer,
      durationSeconds: 600,
      sortOrder: 1,
    ),
  );
  await items.put(
    'r2',
    RitualItem(
      id: 'r2',
      name: pick('3rd Step Prayer', '3. trins bøn'),
      type: RitualItemType.prayer,
      prayerText:
          pick(
            'God, I offer myself to Thee — to build with me and to do with '
                'me as Thou wilt. Relieve me of the bondage of self, that I '
                'may better do Thy will.',
            'Gud, jeg overgiver mig selv til dig — byg med mig og gør med '
                'mig, som du vil. Befri mig fra selvets bånd, så jeg bedre '
                'kan gøre din vilje.',
          ),
      sortOrder: 2,
    ),
  );
  await items.put(
    'r3',
    RitualItem(
      id: 'r3',
      name: pick('Reading', 'Læsning'),
      type: RitualItemType.prayer,
      prayerText: pick(
        'A few pages before the day starts.',
        'Et par sider, før dagen begynder.',
      ),
      sortOrder: 3,
    ),
  );

  final history = await Hive.openBox<MorningRitualEntry>(
    'morning_ritual_entries',
  );
  await history.clear();
  for (var back = 1; back <= 6; back += 1) {
    final skipped = back == 3;
    await history.put(
      'entry-$back',
      MorningRitualEntry(
        id: 'entry-$back',
        date: day(back),
        items: [
          RitualItemRecord(
            ritualItemId: 'r0',
            ritualItemName: pick('Just for Today', 'Kun for i dag'),
            status: RitualItemStatus.completed,
            selectedContentId: 'present_moment',
            selectedContentText: pick(
              'Just for today, I will remember that it is not the '
                  'experience of today that drives people to despair.',
              'Kun for i dag vil jeg huske, at det ikke er oplevelsen af '
                  'i dag, der driver mennesker til fortvivlelse.',
            ),
          ),
          RitualItemRecord(
            ritualItemId: 'r1',
            ritualItemName: pick('Silent meditation', 'Stille meditation'),
            status: skipped
                ? RitualItemStatus.skipped
                : RitualItemStatus.completed,
            actualDurationSeconds: skipped ? 120 : 600,
            originalDurationSeconds: 600,
          ),
          RitualItemRecord(
            ritualItemId: 'r2',
            ritualItemName: pick('3rd Step Prayer', '3. trins bøn'),
            status: RitualItemStatus.completed,
          ),
        ],
        startedAt: day(back).add(const Duration(hours: 6, minutes: 20)),
        completedAt: day(back).add(const Duration(hours: 6, minutes: 41)),
      ),
    );
  }

  // ---- Reminders ----------------------------------------------------------
  final notifications = await Hive.openBox<AppNotification>(
    'notifications_box',
  );
  await notifications.clear();
  final reminders = pick(<List<Object>>[
    ['Morning ritual', 'Before the house wakes up', 6 * 60 + 20, true],
    ['Gratitude', 'Two things, before bed', 21 * 60 + 30, true],
    ['Evening review', 'How was today?', 22 * 60, true],
    ['Ring your sponsor', 'It has been a few days', 18 * 60, false],
  ], <List<Object>>[
    ['Morgenritual', 'Før huset vågner', 6 * 60 + 20, true],
    ['Taknemmelighed', 'To ting, inden du sover', 21 * 60 + 30, true],
    ['Aftenens gennemgang', 'Hvordan var i dag?', 22 * 60, true],
    ['Ring til din sponsor', 'Der er gået et par dage', 18 * 60, false],
  ]);
  for (var i = 0; i < reminders.length; i += 1) {
    final r = reminders[i];
    await notifications.put(
      'n$i',
      AppNotification(
        id: 'n$i',
        notificationId: 1000 + i,
        title: r[0] as String,
        body: r[1] as String,
        timeMinutes: r[2] as int,
        enabled: r[3] as bool,
        scheduleType: NotificationScheduleType.daily,
      ),
    );
  }

  await Hive.close();
  stdout.writeln('Seeded demo boxes into $out');
  for (final f in Directory(out).listSync()) {
    stdout.writeln('  ${f.path.split('/').last}');
  }
}
