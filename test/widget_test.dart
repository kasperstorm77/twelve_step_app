// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:twelvestepsapp/app/app_module.dart';
import 'package:twelvestepsapp/app/app_widget.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ModularApp(module: AppModule(), child: const AppWidget()));

    // Verify that the app loads without errors.
    await tester.pumpAndSettle();
    
    // This is a basic smoke test - just verify the app builds successfully.
    expect(find.byType(AppWidget), findsOneWidget);
  });
}
