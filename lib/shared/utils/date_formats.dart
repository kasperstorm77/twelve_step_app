import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale-aware date/time formatting for everything the user reads.
///
/// `intl`'s `DateFormat` uses `Intl.defaultLocale` when constructed without a
/// locale, and nothing in this app ever sets it — so a bare
/// `DateFormat.yMMMMd()` renders "August 6, 2026" and "Wednesday" inside the
/// Danish UI. Every user-visible date goes through one of these helpers, which
/// read the active locale out of the widget tree, so the EN/DA popup changes
/// dates and month names along with the rest of the screen.
///
/// `initializeDateFormatting()` must have run before any of these are called
/// with a non-`en` locale — `main.dart` does it at startup, and widget tests
/// that render a Danish screen must do the same in `setUp`.
String _localeCode(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// "6 August 2026" / "6. august 2026"
String formatLongDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMMd(_localeCode(context)).format(date);

/// "Aug" / "aug."
String formatMonthAbbrev(BuildContext context, DateTime date) =>
    DateFormat.MMM(_localeCode(context)).format(date);

/// "6"
String formatDayOfMonth(BuildContext context, DateTime date) =>
    DateFormat.d(_localeCode(context)).format(date);

/// "2026"
String formatYear(BuildContext context, DateTime date) =>
    DateFormat.y(_localeCode(context)).format(date);

/// "Thu" / "tor."
String formatWeekdayAbbrev(BuildContext context, DateTime date) =>
    DateFormat.E(_localeCode(context)).format(date);

/// "Thursday" / "torsdag"
String formatWeekdayFull(BuildContext context, DateTime date) =>
    DateFormat.EEEE(_localeCode(context)).format(date);

/// "2:30 PM" / "14.30" — Danish is a 24-hour locale, which is the point.
String formatTimeOfDay(BuildContext context, DateTime time) =>
    DateFormat.jm(_localeCode(context)).format(time);
