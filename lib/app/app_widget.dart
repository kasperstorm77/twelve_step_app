// ignore_for_file: use_build_context_synchronously
// The above ignore is intentional - this file uses Modular's navigator context
// which is freshly fetched from Modular.routerDelegate.navigatorKey.currentContext,
// not the widget's stale context. The analyzer cannot distinguish this case.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../shared/services/locale_provider.dart';
import '../shared/services/app_settings_service.dart';
import '../shared/services/app_switcher_service.dart';
import '../shared/services/all_apps_drive_service_impl.dart';
import '../shared/models/app_entry.dart';
import '../shared/localizations.dart';
import '../fourth_step/models/inventory_entry.dart';
import '../fourth_step/models/i_am_definition.dart';
import '../fourth_step/services/inventory_service.dart';
import '../eighth_step/models/person.dart';
import '../evening_ritual/models/reflection_entry.dart';
import '../gratitude/models/gratitude_entry.dart';
import '../agnosticism/models/barrier_power_pair.dart';
import '../morning_ritual/models/ritual_item.dart';
import '../morning_ritual/models/morning_ritual_entry.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
  late LocaleProvider _localeProvider;
  bool _checkedForNewerData = false;

  @override
  void initState() {
    super.initState();
    _localeProvider = Modular.get<LocaleProvider>();
    _localeProvider.addListener(_onLocaleChanged);
    WidgetsBinding.instance.addObserver(this);
    
    // Check for newer remote data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptIfUploadsBlocked();
    });
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

  /// Check if uploads are blocked (remote has newer data) and prompt user
  Future<void> _checkAndPromptIfUploadsBlocked() async {
    if (_checkedForNewerData) return;
    _checkedForNewerData = true;
    
    // Wait a moment for the UI to be ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Check if uploads are blocked (set in main.dart when remote is newer)
    if (!AllAppsDriveService.instance.uploadsBlocked) {
      if (kDebugMode) print('AppWidget: Uploads not blocked, no prompt needed');
      return;
    }
    
    if (kDebugMode) print('AppWidget: Uploads are blocked - showing newer data prompt');
    
    // Get a valid context for showing the dialog
    var navigatorContext = Modular.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null) {
      if (kDebugMode) print('AppWidget: No navigator context available');
      return;
    }
    
    // Show prompt to user (navigatorContext is freshly fetched from Modular, not the widget's context)
    final shouldFetch = await showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false, // User must make a choice
      builder: (dialogContext) => AlertDialog(
        title: Text(t(dialogContext, 'newer_data_available')),
        content: Text(t(dialogContext, 'newer_data_prompt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t(dialogContext, 'keep_local')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t(dialogContext, 'fetch')),
          ),
        ],
      ),
    );
    
    if (shouldFetch == true) {
      // Re-fetch context after async gap
      navigatorContext = Modular.routerDelegate.navigatorKey.currentContext;
      if (navigatorContext == null) {
        if (kDebugMode) print('AppWidget: No navigator context after dialog');
        AllAppsDriveService.instance.unblockUploads();
        return;
      }
      // User wants to fetch - perform restore directly
      await _performRestore(navigatorContext);
    } else {
      // User chose to keep local data - unblock uploads
      AllAppsDriveService.instance.unblockUploads();
      if (kDebugMode) print('AppWidget: User chose to keep local data - uploads unblocked');
    }
  }

  /// Perform restore from Google Drive (most recent backup)
  Future<void> _performRestore(BuildContext ctx) async {
    // Capture ScaffoldMessenger and localized strings before any async gaps
    // to avoid use_build_context_synchronously warnings
    final messenger = ScaffoldMessenger.of(ctx);
    final fetchingText = t(ctx, 'fetching_data');
    final noBackupText = t(ctx, 'no_backup_found');
    final fetchFailedText = t(ctx, 'fetch_failed');
    final fetchSuccessText = t(ctx, 'fetch_success');

    try {
      // Show loading indicator
      messenger.showSnackBar(
        SnackBar(
          content: Text(fetchingText),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Get most recent backup
      final backups = await AllAppsDriveService.instance.listAvailableBackups();
      if (backups.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(noBackupText)),
        );
        AllAppsDriveService.instance.unblockUploads();
        return;
      }
      
      final backupFileName = backups.first['fileName'] as String;
      final content = await AllAppsDriveService.instance.downloadBackupContent(backupFileName);
      
      if (content == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(fetchFailedText)),
        );
        AllAppsDriveService.instance.unblockUploads();
        return;
      }
      
      // Import the data
      await _importDataFromJson(content);
      
      // Success - unblock uploads
      AllAppsDriveService.instance.unblockUploads();
      
      messenger.showSnackBar(
        SnackBar(content: Text(fetchSuccessText)),
      );
      
      // Trigger UI rebuild to show restored data
      if (mounted) setState(() {});
      
    } catch (e) {
      if (kDebugMode) print('AppWidget: Restore failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('$fetchFailedText: $e')),
      );
      // Unblock on error to avoid permanently blocking
      AllAppsDriveService.instance.unblockUploads();
    }
  }

  /// Import data from JSON content (same logic as Data Management tabs)
  Future<void> _importDataFromJson(String content) async {
    final decoded = json.decode(content) as Map<String, dynamic>;
    
    // Import I Am definitions first
    if (decoded.containsKey('iAmDefinitions')) {
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      final iAmDefs = decoded['iAmDefinitions'] as List<dynamic>?;
      if (iAmDefs != null) {
        await iAmBox.clear();
        for (final defJson in iAmDefs) {
          final def = IAmDefinition(
            id: defJson['id'] as String,
            name: defJson['name'] as String,
            reasonToExist: defJson['reasonToExist'] as String?,
          );
          await iAmBox.add(def);
        }
      }
    }

    // Import entries
    if (decoded.containsKey('entries')) {
      final entriesBox = Hive.box<InventoryEntry>('entries');
      final entries = decoded['entries'] as List<dynamic>;
      await entriesBox.clear();
      for (final item in entries) {
        if (item is Map<String, dynamic>) {
          final entry = InventoryEntry.fromJson(item);
          await entriesBox.add(entry);
        }
      }
      await InventoryService.migrateOrderValues();
    }

    // Import people (8th step)
    if (decoded.containsKey('people')) {
      final peopleBox = Hive.box<Person>('people_box');
      final peopleList = decoded['people'] as List;
      await peopleBox.clear();
      for (final personJson in peopleList) {
        final person = Person.fromJson(personJson as Map<String, dynamic>);
        await peopleBox.put(person.internalId, person);
      }
    }

    // Import reflections (evening ritual)
    if (decoded.containsKey('reflections')) {
      final reflectionsBox = Hive.box<ReflectionEntry>('reflections_box');
      final reflectionsList = decoded['reflections'] as List;
      await reflectionsBox.clear();
      for (final reflectionJson in reflectionsList) {
        final reflection = ReflectionEntry.fromJson(reflectionJson as Map<String, dynamic>);
        await reflectionsBox.put(reflection.internalId, reflection);
      }
    }

    // Import gratitude entries
    if (decoded.containsKey('gratitude') || decoded.containsKey('gratitudeEntries')) {
      final gratitudeBox = Hive.box<GratitudeEntry>('gratitude_box');
      final gratitudeList = (decoded['gratitude'] ?? decoded['gratitudeEntries']) as List;
      await gratitudeBox.clear();
      for (final gratitudeJson in gratitudeList) {
        final gratitude = GratitudeEntry.fromJson(gratitudeJson as Map<String, dynamic>);
        await gratitudeBox.add(gratitude);
      }
    }

    // Import agnosticism pairs
    if (decoded.containsKey('agnosticism') || decoded.containsKey('agnosticismPapers')) {
      final agnosticismBox = Hive.box<BarrierPowerPair>('agnosticism_pairs');
      final pairsList = (decoded['agnosticism'] ?? decoded['agnosticismPapers']) as List;
      await agnosticismBox.clear();
      for (final pairJson in pairsList) {
        final pair = BarrierPowerPair.fromJson(pairJson as Map<String, dynamic>);
        await agnosticismBox.put(pair.id, pair);
      }
    }

    // Import morning ritual items
    if (decoded.containsKey('morningRitualItems')) {
      final morningRitualItemsBox = Hive.box<RitualItem>('morning_ritual_items');
      final itemsList = decoded['morningRitualItems'] as List;
      await morningRitualItemsBox.clear();
      for (final itemJson in itemsList) {
        final item = RitualItem.fromJson(itemJson as Map<String, dynamic>);
        await morningRitualItemsBox.put(item.id, item);
      }
    }

    // Import morning ritual entries
    if (decoded.containsKey('morningRitualEntries')) {
      final morningRitualEntriesBox = Hive.box<MorningRitualEntry>('morning_ritual_entries');
      final entriesList = decoded['morningRitualEntries'] as List;
      await morningRitualEntriesBox.clear();
      for (final entryJson in entriesList) {
        final entry = MorningRitualEntry.fromJson(entryJson as Map<String, dynamic>);
        await morningRitualEntriesBox.put(entry.id, entry);
      }
    }

    // Import app settings
    if (decoded.containsKey('appSettings')) {
      AppSettingsService.importFromSync(decoded['appSettings'] as Map<String, dynamic>);
    }

    // Save the remote lastModified timestamp locally
    if (decoded.containsKey('lastModified')) {
      final remoteLastModified = DateTime.parse(decoded['lastModified'] as String);
      await Hive.box('settings').put('lastModified', remoteLastModified.toIso8601String());
    }
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