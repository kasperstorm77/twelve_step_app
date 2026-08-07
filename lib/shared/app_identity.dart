/// The app's name — one string, everywhere, in every language.
///
/// This is deliberately **not** a localization key. A store page, a window
/// title or a launcher icon that reads something other than what the person
/// installed is a different app to them, and a translated name is the same
/// problem in another language.
///
/// The app has carried four names at once: `12 Steps App` on the launcher and
/// in `MaterialApp.title`, `Twelve Steps app` / `Tolv Trins app` on the desktop
/// window (picked off the *system* locale, so a Danish UI could show an English
/// title), `12 Steps App - Recovery` staged on the App Store, and
/// `12 Trins App - Værktøjer` briefly on the Play listing.
///
/// Every Dart reference now comes from here. The values outside Dart —
/// `android:label`, `CFBundleDisplayName`, and both store listing titles — must
/// match it exactly; `test/naming_rule_test.dart` checks the ones in the repo.
const appDisplayName = '12 Steps App';
