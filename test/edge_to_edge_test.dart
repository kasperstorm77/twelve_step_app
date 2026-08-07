import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/shared/utils/system_ui.dart';

/// Android 15 deprecated `Window.setStatusBarColor`,
/// `setNavigationBarColor` and `setNavigationBarDividerColor`, and Google Play
/// flagged release 106 (2.2.13) for reaching all three through
/// `PlatformPlugin.setSystemChromeSystemUIOverlayStyle`.
///
/// Flutter calls each setter only when the Dart-side style supplies that
/// colour, so the migration is to supply none. This app never touches
/// `SystemChrome` itself — the colours came from Material's AppBar default,
/// which only applies when `AppBarTheme.systemOverlayStyle` is unset.
void main() {
  test('the app sets no system bar colours', () {
    expect(
      appSystemOverlayStyle.statusBarColor,
      isNull,
      reason: 'a non-null value here calls the deprecated setStatusBarColor',
    );
    expect(
      appSystemOverlayStyle.systemNavigationBarColor,
      isNull,
      reason:
          'a non-null value here calls the deprecated setNavigationBarColor',
    );
    expect(
      appSystemOverlayStyle.systemNavigationBarDividerColor,
      isNull,
      reason: 'a non-null value here calls setNavigationBarDividerColor',
    );
  });

  test('icon brightness is still specified', () {
    // This half goes through WindowInsetsControllerCompat, which is not
    // deprecated — dropping it would leave unreadable icons on a light bar.
    expect(appSystemOverlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(
      appSystemOverlayStyle.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
    expect(appSystemOverlayStyle.statusBarBrightness, Brightness.light);
  });

  testWidgets('an AppBar under the app theme announces no bar colours', (
    tester,
  ) async {
    // The regression this guards: without AppBarTheme.systemOverlayStyle,
    // AppBar._systemOverlayStyleForBrightness fills in a statusBarColor and the
    // deprecated call comes back.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: appSystemOverlayStyle,
          ),
        ),
        home: Scaffold(appBar: AppBar(title: const Text('t'))),
      ),
    );

    final region = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .first;

    expect(region.value.statusBarColor, isNull);
    expect(region.value.systemNavigationBarColor, isNull);
    expect(region.value.systemNavigationBarDividerColor, isNull);
  });

  testWidgets('without the theme, Material puts the colour back', (
    tester,
  ) async {
    // The negative control — this is what the shipped build was doing, and why
    // Play saw the deprecated call at all. If this ever starts passing as null,
    // Flutter changed its default and the AppBarTheme above is belt-and-braces.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(title: const Text('t'))),
      ),
    );

    final region = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .first;

    expect(region.value.statusBarColor, isNotNull);
  });
}
