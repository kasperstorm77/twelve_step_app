# Release notes

Newest-first. The **top** block is the one shipped on the next store upload:
`scripts/upload-aab-to-play.sh` and `scripts/upload-ipa-to-testflight.sh` lift
its `<en-GB>` and `<da-DK>` bodies verbatim into Google Play / TestFlight. Keep
each locale ≤ 500 characters (Play's limit). The version on the `X.Y.Z - DATE:`
line must match `pubspec.yaml`.

2.2.13 - 2026-06-28:
<en-GB>
- The morning ritual alarm now plays to the end instead of cutting off early.
- On desktop, the app no longer fills your Documents folder with backup files.
</en-GB>
<da-DK>
- Morgenritualets alarm spiller nu helt færdig i stedet for at blive afbrudt.
- På computer fylder appen ikke længere din Dokumenter-mappe med sikkerhedskopier.
</da-DK>
