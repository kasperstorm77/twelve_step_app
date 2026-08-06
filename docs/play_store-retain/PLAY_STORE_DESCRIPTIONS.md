# Store listing copy — Google Play + App Store

Canonical source for both stores' *listing* text. Release notes are a
different thing and live in [`release.md`](../../release.md).

**Status (2026-08-06).**
- **App Store — applied, text and screenshots.** All of this is staged on
  version **2.3.0** (`PREPARE_FOR_SUBMISSION`): the Danish description
  rewritten, an **`en-GB` localization added** (there was none), keywords,
  promotional text, the app name and both subtitles. **28 new screenshots**
  replaced the old sets — 7 per tool × (iPhone 6.7" + iPad 12.9") × (en-GB +
  da), all `assetDeliveryState: COMPLETE` with zero errors. Remaining:
  attaching build 107 and submitting for review, both deliberately left to
  the owner.
- **Google Play — blocked on a permission, listing unchanged.** The text
  writes into an edit fine (`PUT .../listings/{lang}` → 200) but
  `edits:validate` returns **403 "The caller does not have permission"**, so
  the edit cannot be committed. The service account
  `play-publisher@life-happens.iam.gserviceaccount.com` can release to testing
  tracks but cannot manage store presence. Grant it in **Play Console → Users
  & permissions → that account → App permissions → "Manage store presence"**,
  then re-run the publish. Nothing was committed; the live listing still shows
  the old copy.

> **Naming rule.** No listing text, screenshot, or in-app string may name the
> fellowship or use its initials. A public store listing that names it implies
> an affiliation and an endorsement this app does not have. The concepts —
> step work, sponsor, moral inventory, amends, sobriety — carry the meaning on
> their own. Both live listings currently break this; see the audit.

Character limits — Play: title 30, short 80, full 4000. App Store: name 30,
subtitle 30, keywords 100, promotional text 170, description 4000.

---

## What the live listings got wrong (audit, 2026-08-06)

Read against [architecture.md §1](../architecture.md): the app is **six tools
plus a reminders module**, offline-first, free, EN + DA.

**Google Play (`en-GB`, the only listing language):**
- **Names the fellowship seven times**, including the claim that the app was
  built to work "through [the fellowship]'s 4th Step" and a sign-off as a
  member of it. This is the most urgent fix on either store.
- The description is otherwise **4th-Step-only** — features list resentments,
  fears and character defects. Six of the seven modules are never mentioned.
- **One** phone screenshot, 500×1024, showing only the 4th Step form.
- **No `da-DK` listing at all**, though the app is bilingual and the upload
  script sends `da-DK` release notes.

**App Store (`da`, the only localization):**
- The app's primary locale is **Danish but the description is in English**,
  and there is no English localization — so every user sees English copy filed
  under Danish.
- It advertises *"Fearless moral inventory with **Theatre of the Lies**
  flavor"*. That phrase appears **nowhere in the app** (`grep -ri theatre
  lib/` is empty) — a listed feature that does not exist.
- Lists the six tools but omits **Notifications**.
- Says nothing about the app being free, offline-first, private, optionally
  Drive-backed, or bilingual, and carries no "unofficial, not endorsed"
  disclaimer at all.

**Screenshots (App Store, 7 × iPhone 6.5" + 1 × iPad):**
- *Morning Ritual* shows an **empty state**: "0 items in your ritual", a
  disabled Start button and a red "Add items in the Settings tab first".
- *Agnosticism* predates the **connected fear** field (Phase 19), so it shows
  a shape the current app no longer has.
- Real personal content is redacted with hand-drawn black bars.
- The iPad set has a single 4th-Step shot; nothing anywhere shows
  Notifications or Just for Today.

**In the app and its metadata** (not listing text, but the same rule):
- `lib/app/app_widget.dart` — the `MaterialApp` title names the fellowship.
- `lib/shared/models/app_entry.dart` — a tool description does.
- `lib/fourth_step/services/i_am_service.dart` — the **default "I Am"
  definition seeded on every fresh install** does; this one becomes the user's
  own data.
- `pubspec.yaml` — the package description does.

---

## Google Play

### Title (en-GB) — 29
```
12 Steps App - Recovery Tools
```

### Short description (en-GB) — 73
```
Six recovery tools in one free, private app. No ads, works fully offline.
```

### Full description (en-GB)
```
Six tools for twelve step recovery, plus reminders, in one free app — written
by one person in recovery for his own step work, and shared in case it helps
yours.

THE TOOLS
• 4th Step Inventory — a fearless moral inventory across resentment, fear,
  harms and sexual harms, using the familiar five-column structure and
  reusable "I Am" identities.
• 8th Step Amends — everyone harmed, sorted Yes / No / Maybe on a
  drag-and-drop board, with amends notes and a done flag.
• Morning Ritual — build your own morning practice from timers and readings,
  then run it step by step with an alarm at the end of each timer.
• Evening Ritual — the nightly 10th Step review across the usual questions,
  plus a self-versus-others focus slider.
• Gratitude — a two-field daily gratitude journal.
• Surrender & Correction — the barrier, the fear underneath it, and the
  corrective truth, on a paper you flip between the two sides.
• Reminders — daily or weekday notifications for any of it.

FREE AND PRIVATE
• Completely free. No ads, no subscriptions, no in-app purchases.
• Offline first. Your data lives on your device and the app works fully
  without an account.
• Optional Google Drive backup writes only to the app's own private folder —
  it cannot see the rest of your Drive, and nothing leaves your device until
  you turn sync on.
• No tracking, no analytics, no data sharing.
• Export and import your data as JSON whenever you like.
• English and Danish.

IMPORTANT
• This is an UNOFFICIAL, independent tool. It is not affiliated with,
  endorsed by, or approved by any twelve step fellowship or its service
  organisation.
• It was written by one person in recovery as a personal project.
• Follow your sponsor's guidance for step work. This supplements the
  traditional methods; it does not replace them.

I built this because pen and paper never stuck for me. If you prefer a
digital tool, it might help. It will stay free — recovery tools should be
available to everyone.

Your sponsor is your best guide. This is just a notebook. The real work
happens between you, your higher power and your sponsor.
```

### Title (da-DK) — 24
```
12 Trins App - Værktøjer
```

### Short description (da-DK) — 75
```
Seks værktøjer til bedring i én gratis app. Ingen reklamer, virker offline.
```

### Full description (da-DK)
```
Seks værktøjer til tolvtrinsarbejde plus påmindelser i én gratis app —
skrevet af én person i bedring til hans eget trinarbejde og delt, hvis det
kan hjælpe dit.

VÆRKTØJERNE
• 4. trins liste — en frygtløs moralsk opgørelse over vrede, frygt, skade og
  seksuel skade med den velkendte femdelte struktur og genbrugelige "Jeg
  Er"-identiteter.
• 8. trins liste — alle vi har gjort fortræd, fordelt på Ja / Nej / Måske på
  en træk-og-slip-tavle med noter og et felt for udført godtgørelse.
• Morgenritual — byg din egen morgenpraksis af tidtagere og læsninger, og kør
  den trin for trin med en alarm, når hver tidtager slutter.
• Aftenritual — den daglige 10. trins gennemgang med de sædvanlige spørgsmål
  og en skala for fokus på dig selv kontra andre.
• Taknemmelighed — en daglig taknemmelighedsdagbog med to felter.
• Overgivelse & Korrektion — barrieren, frygten under den og den korrigerende
  sandhed på et papir, du vender mellem de to sider.
• Påmindelser — daglige eller ugedagsbestemte notifikationer til det hele.

GRATIS OG PRIVAT
• Helt gratis. Ingen reklamer, abonnementer eller køb i appen.
• Offline først. Dine data ligger på din enhed, og appen virker fuldt ud uden
  en konto.
• Valgfri Google Drive-sikkerhedskopi skriver kun til appens egen private
  mappe — den kan ikke se resten af dit Drive, og intet forlader din enhed,
  før du selv slår synkronisering til.
• Ingen sporing, ingen analyse, ingen deling af data.
• Eksportér og importér dine data som JSON, når du vil.
• Dansk og engelsk.

VIGTIGT
• Dette er et UOFFICIELT og uafhængigt værktøj. Det er ikke forbundet med
  eller godkendt af noget tolvtrinsfællesskab eller dets serviceorganisation.
• Det er skrevet af én person i bedring som et personligt projekt.
• Følg din sponsors vejledning i trinarbejdet. Dette supplerer de
  traditionelle metoder — det erstatter dem ikke.

Jeg lavede den, fordi papir og blyant aldrig fungerede for mig. Foretrækker du
et digitalt værktøj, kan den måske hjælpe. Den forbliver gratis — værktøjer
til bedring bør være tilgængelige for alle.

Din sponsor er din bedste vejleder. Dette er bare en notesbog. Det virkelige
arbejde sker mellem dig, din højere magt og din sponsor.
```

---

## App Store

The primary locale is `da`. **Add an `en-GB` localization** so English copy
stops being filed under Danish.

### Name — 23
```
12 Steps App - Recovery
```

### Subtitle (en-GB) — 27
```
Six tools, free and private
```
### Subtitle (da) — 22
```
Seks værktøjer, privat
```

### Keywords (en-GB) — 97
```
recovery,sober,sobriety,12 step,twelve step,inventory,4th step,amends,gratitude,meditation,prayer
```
### Keywords (da) — 91
```
bedring,ædru,ædruelighed,12 trin,tolv trin,opgørelse,4. trin,godtgørelse,taknemmelighed,bøn
```

### Description
Use the Play full description above verbatim for the matching locale — both
stores allow 4000 characters and there is no reason for them to differ.

### Promotional text (en-GB) — 142
```
New: a Just for Today reading that draws one of ten intentions each morning,
and you can now import your work from the Emotional Sobriety app.
```
### Promotional text (da) — 141
```
Nyt: en Kun for i dag-læsning, der trækker én af ti intentioner hver morgen,
og du kan nu importere dit arbejde fra Emotional Sobriety-appen.
```

*(Promotional text is editable without a new build — use it for 2.3.0 once
that version reaches the store.)*

---

## Screenshots

**Reproducible, not hand-made.** Two scripts in [`tool/`](../../tool) generate
the sample data, so a reshoot never means digging up personal content and
drawing bars over it:

```bash
dart run tool/seed_demo_data.dart /tmp/demo_hive      # English sample data
dart run tool/seed_demo_data.dart /tmp/demo_hive_da da   # Danish sample data
# then, per tool: copy the .hive files into the simulator's app container,
# point tool/set_demo_settings.dart at it, relaunch, and screenshot.
```

`set_demo_settings.dart` writes `selected_app_id` so the app opens straight
onto a given tool without UI automation, and for Morning Ritual it also seeds
an in-progress draft — which is why that shot now shows the runner mid-ritual
with a real Just for Today reading instead of the old empty state.

Two wrinkles worth knowing next time:
- The notification permission alert covers the first launch after install.
  `simctl privacy` has no `notifications` service; sending Return via
  System Events answers it once, after which it stays answered.
- The API has **no 6.9" display type** — `APP_IPHONE_67` (1290×2796) is the
  newest. Captures from a 6.9" simulator (1320×2868) are resampled to 1290
  wide and cropped to 2796.

| Store / size | Before | Now |
|---|---|---|
| App Store iPhone 6.7" | 7, incl. an empty-state Morning Ritual | **7 per language**, en-GB + da, real data |
| App Store iPad 12.9" | 1 (4th Step only) | **7 per language**, en-GB + da |
| Play phone | 1 (4th Step, 500×1024) | still 1 — blocked on the same permission as the text |

The captures are not committed (they are large and reproducible); regenerate
with the commands above when the Play permission lands.
