import 'package:flutter/services.dart';

/// System-bar styling that sets **no bar colours at all**.
///
/// `Window.setStatusBarColor`, `setNavigationBarColor` and
/// `setNavigationBarDividerColor` are deprecated in Android 15, and Google Play
/// flagged release 106 (2.2.13) for reaching them through
/// `io.flutter.plugin.platform.PlatformPlugin.setSystemChromeSystemUIOverlayStyle`.
///
/// Nothing in this app calls `SystemChrome` directly. The calls came from
/// Material: with no `AppBarTheme.systemOverlayStyle` set, every `AppBar` fell
/// back to `AppBar._systemOverlayStyleForBrightness`, which fills in a
/// `statusBarColor` — and Flutter's platform plugin invokes the deprecated
/// setter for each colour that is **non-null**.
///
/// Leaving all three null keeps the icon-brightness half of the style, which
/// goes through `WindowInsetsControllerCompat` and is not deprecated, and lets
/// the system paint the bars. That is what edge-to-edge means from Android 15
/// on, where these setters are no-ops regardless. The app ships no dark
/// `ThemeData`, so its surfaces are always light and the icons are always dark.
///
/// Do not add a colour here to "fix" a bar tint — draw behind the bar instead.
const appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: null,
  systemNavigationBarColor: null,
  systemNavigationBarDividerColor: null,
  // Android: dark icons, for a light bar.
  statusBarIconBrightness: Brightness.dark,
  // iOS: describes the bar itself, not the icons.
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
);
