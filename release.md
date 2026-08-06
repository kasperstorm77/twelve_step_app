# Release notes

Newest-first. The **top** block is the one shipped on the next store upload:
`scripts/upload-aab-to-play.sh` and `scripts/upload-ipa-to-testflight.sh` lift
its `<en-GB>` and `<da-DK>` bodies verbatim into Google Play / TestFlight. Keep
each locale ≤ 500 characters (Play's limit). The version on the `X.Y.Z - DATE:`
line must match `pubspec.yaml`.

2.3.1 - 2026-08-06:
<en-GB>
- New "Just for Today" reading: turn it on for a prayer item and the app draws
  one of ten readings each morning. It stays the same if you pause or go back,
  and your history keeps what you read.
- You can now import a backup from the Emotional Sobriety app: I Am
  definitions, 4th Step entries, pairs and your morning ritual. Everything
  else on this device is kept.
- Fixed: deleting a morning ritual item could make your backup unreadable by
  the other app. Tidier wording in places.
</en-GB>
<da-DK>
- Ny "Kun for i dag"-læsning: slå den til på en bøn, så trækker appen én af ti
  læsninger, når dagens ritual begynder. Den er den samme, hvis du holder
  pause eller går tilbage, og historikken husker den.
- Du kan nu importere en sikkerhedskopi fra Emotional Sobriety: Jeg Er,
  4. trins poster, par og dit morgenritual. Alt andet bevares.
- Rettet: at slette et element i morgenritualet kunne gøre din sikkerhedskopi
  ulæselig for den anden app. Pænere formuleringer enkelte steder.
</da-DK>

2.3.0 - 2026-08-06:
<en-GB>
- New "Just for Today" reading: turn it on for a prayer item and the app draws
  one of ten readings when the day's ritual begins. It stays the same if you
  pause or go back, and your history keeps what you read.
- You can now import a backup from the Emotional Sobriety app: I Am
  definitions, 4th Step entries, Barrier/Power pairs and your morning ritual.
  Everything else on this device is kept.
- Fixed: deleting a morning ritual item could make your backup unreadable by
  the other app.
</en-GB>
<da-DK>
- Ny "Kun for i dag"-læsning: slå den til på en bøn, så trækker appen én af ti
  læsninger, når dagens ritual begynder. Den er den samme, hvis du holder
  pause eller går tilbage, og historikken husker den.
- Du kan nu importere en sikkerhedskopi fra Emotional Sobriety: Jeg Er,
  4. trins poster, Barriere/Kraft-par og dit morgenritual. Alt andet på
  enheden bevares.
- Rettet: at slette et element i morgenritualet kunne gøre din sikkerhedskopi
  ulæselig for den anden app.
</da-DK>

2.2.13 - 2026-06-28:
<en-GB>
- The morning ritual alarm now plays to the end instead of cutting off early.
- On desktop, the app no longer fills your Documents folder with backup files.
</en-GB>
<da-DK>
- Morgenritualets alarm spiller nu helt færdig i stedet for at blive afbrudt.
- På computer fylder appen ikke længere din Dokumenter-mappe med sikkerhedskopier.
</da-DK>
