// ignore_for_file: use_build_context_synchronously
// The above ignore is intentional - this file uses Modular's navigator context
// which is freshly fetched from Modular.routerDelegate.navigatorKey.currentContext,
// not the widget's stale context. The analyzer cannot distinguish this case.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/services/locale_provider.dart';
import '../shared/services/app_settings_service.dart';
import '../shared/services/app_switcher_service.dart';
import '../shared/services/all_apps_drive_service_impl.dart';
import '../shared/services/backup_restore_service.dart';
import '../shared/models/app_entry.dart';
import '../shared/localizations.dart';

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

  /// Import data from JSON content using centralized BackupRestoreService
  /// This is called during auto-sync when remote data is newer
  /// Note: No safety backup is created for auto-sync to avoid backup loops
  Future<void> _importDataFromJson(String content) async {
    // Use BackupRestoreService for consistent restore behavior
    // createSafetyBackup is false for auto-sync to avoid backup loops
    await BackupRestoreService.restoreFromJsonString(
      content,
      createSafetyBackup: false,
    );
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