import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/services/locale_provider.dart';
import '../shared/services/app_settings_service.dart';
import '../shared/services/app_switcher_service.dart';
import '../shared/models/app_entry.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
  late LocaleProvider _localeProvider;

  @override
  void initState() {
    super.initState();
    _localeProvider = Modular.get<LocaleProvider>();
    _localeProvider.addListener(_onLocaleChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localeProvider.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background, check if we should switch to morning ritual
    if (state == AppLifecycleState.resumed) {
      _checkMorningRitualAutoLoad();
    }
  }

  void _checkMorningRitualAutoLoad() async {
    // Only force morning ritual once per day
    if (AppSettingsService.shouldForceMorningRitual()) {
      final currentAppId = AppSwitcherService.getSelectedAppId();
      if (currentAppId != AvailableApps.morningRitual) {
        if (kDebugMode) print('AppWidget: Within morning ritual window (first time today), switching to morning ritual');
        await AppSwitcherService.setSelectedAppId(AvailableApps.morningRitual);
        await AppSettingsService.markMorningRitualForced();
        // Trigger rebuild to show morning ritual
        setState(() {});
      } else {
        // Already on morning ritual, just mark as forced
        await AppSettingsService.markMorningRitualForced();
      }
    }
  }

  void _onLocaleChanged() {
    setState(() {
      // Trigger rebuild when locale changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AA 4Step Inventory',
      debugShowCheckedModeBanner: false,
      locale: _localeProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('da'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        primarySwatch: Colors.blue,
      ),
      routerConfig: Modular.routerConfig,
    );
  }
}