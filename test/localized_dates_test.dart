import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:twelvestepsapp/shared/localizations.dart';
import 'package:twelvestepsapp/shared/utils/date_formats.dart';

/// Dates and calendar labels follow the EN/DA popup (implementation plan P1.6).
///
/// Every `DateFormat` in this app used to be constructed without a locale, so
/// `Intl.defaultLocale` (en_US) won a Danish screen: "August 6, 2026" and
/// "Wednesday" under Danish UI text. The calendar format toggle was a
/// hardcoded English literal on top of that.
void main() {
  setUpAll(initializeDateFormatting);

  Future<String> render(
    WidgetTester tester,
    String languageCode,
    String Function(BuildContext) build,
  ) async {
    late String value;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(languageCode),
        supportedLocales: const [Locale('en'), Locale('da')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            value = build(context);
            return Text(value);
          },
        ),
      ),
    );
    return value;
  }

  final date = DateTime(2026, 8, 6, 14, 30);

  testWidgets('the long date follows the active locale', (tester) async {
    final english = await render(tester, 'en', (c) => formatLongDate(c, date));
    final danish = await render(tester, 'da', (c) => formatLongDate(c, date));

    expect(english, contains('August'));
    expect(danish, contains('august'));
    expect(
      danish,
      isNot(equals(english)),
      reason: 'a Danish screen must not render an English date',
    );
  });

  testWidgets('month, weekday and time all follow the locale', (tester) async {
    final enMonth = await render(
      tester,
      'en',
      (c) => formatMonthAbbrev(c, date),
    );
    final daMonth = await render(
      tester,
      'da',
      (c) => formatMonthAbbrev(c, date),
    );
    expect(daMonth, isNot(equals(enMonth)));

    final enWeekday = await render(
      tester,
      'en',
      (c) => formatWeekdayFull(c, date),
    );
    final daWeekday = await render(
      tester,
      'da',
      (c) => formatWeekdayFull(c, date),
    );
    expect(enWeekday, 'Thursday');
    expect(daWeekday, 'torsdag');

    // Danish is a 24-hour locale — the same instant reads differently.
    final enTime = await render(tester, 'en', (c) => formatTimeOfDay(c, date));
    final daTime = await render(tester, 'da', (c) => formatTimeOfDay(c, date));
    expect(enTime, contains('2:30'));
    expect(daTime, contains('14'));
  });

  testWidgets('the calendar format toggle is localized, not a literal', (
    tester,
  ) async {
    final enWeek = await render(tester, 'en', (c) => t(c, 'calendar_week'));
    final enMonth = await render(tester, 'en', (c) => t(c, 'calendar_month'));
    final daWeek = await render(tester, 'da', (c) => t(c, 'calendar_week'));
    final daMonth = await render(tester, 'da', (c) => t(c, 'calendar_month'));

    expect(enWeek, 'Week');
    expect(enMonth, 'Month');
    expect(daWeek, 'Uge');
    expect(daMonth, 'Måned');
  });

  test('both locales define every key the other does', () {
    final en = localizedValues['en']!.keys.toSet();
    final da = localizedValues['da']!.keys.toSet();

    expect(
      en.difference(da),
      isEmpty,
      reason: 'these keys have no Danish translation',
    );
    expect(
      da.difference(en),
      isEmpty,
      reason: 'these Danish keys have no English fallback',
    );
  });

  test('the Danish prayer type and prayer text field read differently', () {
    // They were both "Bøn", in the same dialog (plan P3.4b).
    final da = localizedValues['da']!;
    expect(
      da['morning_ritual_prayer_text'],
      isNot(equals(da['morning_ritual_type_prayer'])),
    );
  });
}
