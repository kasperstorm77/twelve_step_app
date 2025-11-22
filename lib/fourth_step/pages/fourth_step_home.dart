import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../../shared/models/app_entry.dart';
import 'form_tab.dart';
import 'list_tab.dart';
import 'settings_tab.dart';
import '../../shared/localizations.dart';
import '../../shared/services/legacy_drive_service.dart';
import '../services/inventory_service.dart';
import '../../shared/services/app_version_service.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/utils/platform_helper.dart';
import '../../shared/pages/data_management_page.dart';

class ModularInventoryHome extends StatefulWidget {
  final Locale? currentLocale;
  final void Function(Locale)? setLocale;
  final VoidCallback? onAppSwitched;

  const ModularInventoryHome({super.key, this.currentLocale, this.setLocale, this.onAppSwitched});

  @override
  State<ModularInventoryHome> createState() => _ModularInventoryHomeState();
}

class _ModularInventoryHomeState extends State<ModularInventoryHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final InventoryService _inventoryService;
  late final DriveService _driveService;

  // Text controllers for form
  final _resentmentController = TextEditingController();
  final _reasonController = TextEditingController();
  final _affectController = TextEditingController();
  final _partController = TextEditingController();
  final _defectController = TextEditingController();

  int? editingIndex;
  String? selectedIAmId;  // Selected I Am definition ID
  bool get isEditing => editingIndex != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inventoryService = InventoryService();
    _driveService = DriveService.instance;
    
    _driveService.loadSyncState();
    
    // Note: No longer listening to all upload events to avoid showing notifications
    // for background sync. User-initiated actions in Settings show their own notifications.

    // Check for new installation or update and potentially prompt for Google fetch
    _checkForNewInstallOrUpdate();
  }

  @override
  void dispose() {
    // No upload subscription to cancel anymore
    _resentmentController.dispose();
    _reasonController.dispose();
    _affectController.dispose();
    _partController.dispose();
    _defectController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _editEntry(int index) {
    final entry = _inventoryService.getEntryAt(index);
    if (entry != null) {
      setState(() {
        editingIndex = index;
        selectedIAmId = entry.iAmId;
        _resentmentController.text = entry.safeResentment;
        _reasonController.text = entry.safeReason;
        _affectController.text = entry.safeAffect;
        _partController.text = entry.safePart;
        _defectController.text = entry.safeDefect;
      });
      _tabController.animateTo(0); // Switch to form tab
    }
  }

  void _resetForm() {
    setState(() {
      editingIndex = null;
      selectedIAmId = null;
      _resentmentController.clear();
      _reasonController.clear();
      _affectController.clear();
      _partController.clear();
      _defectController.clear();
    });
    _tabController.animateTo(1); // Switch to list tab
  }

  Future<void> _saveEntry() async {
    final entry = InventoryEntry(
      _resentmentController.text,
      _reasonController.text,
      _affectController.text,
      _partController.text,
      _defectController.text,
      iAmId: selectedIAmId,
    );
    
    if (isEditing && editingIndex != null) {
      await _inventoryService.updateEntry(editingIndex!, entry);
    } else {
      await _inventoryService.addEntry(entry);
    }

    _resetForm();
  }

  Future<void> _deleteEntry(int index) async {
    await _inventoryService.deleteEntry(index);
  }

  Future<void> _checkForNewInstallOrUpdate() async {
    // Only check for Google fetch on mobile platforms
    // Desktop uses manual Drive sync buttons instead
    if (!PlatformHelper.isMobile) return;
    
    // Give some time for the app to fully initialize and for Google Sign-In to complete
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    try {
      final shouldPrompt = await AppVersionService.shouldPromptGoogleFetch();
      if (shouldPrompt && mounted) {
        // Wait a bit more to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await AppVersionService.showGoogleFetchDialog(context);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error checking for new install/update: $e');
    }
  }

  void _changeLanguage(String langCode) {
    widget.setLocale?.call(Locale(langCode));
  }

  void _openDataManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DataManagementPage(),
      ),
    );
  }

  Future<void> _showAppSwitcher() async {
    final apps = AvailableApps.getAll();
    final currentAppId = AppSwitcherService.getSelectedAppId();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: apps.map((app) {
            final isSelected = app.id == currentAppId;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(app.name),
              subtitle: Text(app.description),
              selected: isSelected,
              onTap: () async {
                if (app.id != currentAppId) {
                  await AppSwitcherService.setSelectedAppId(app.id);
                  if (!mounted) return;
                  
                  // Trigger callback to refresh parent AppRouter
                  if (widget.onAppSwitched != null) {
                    widget.onAppSwitched!();
                  }
                  
                  if (!context.mounted) return;
                  
                  // Show snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${app.name}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget now only displays the 4th Step app
    // Routing to other apps is handled by AppRouter
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'app_title')),
        actions: [
          // App Switcher Icon
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: 'Switch App',
            onPressed: _showAppSwitcher,
          ),
          // Help Icon
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              AppHelpService.showHelpDialog(
                context,
                AvailableApps.fourthStepInventory,
              );
            },
          ),
          // Settings Icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _openDataManagement();
            },
          ),
          // Language Selector
          PopupMenuButton<String>(
            onSelected: _changeLanguage,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'da', child: Text('Dansk')),
            ],
            icon: const Icon(Icons.language),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t(context, 'form_title')),
            Tab(text: t(context, 'entries_title')),
            Tab(text: t(context, 'settings_title')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FormTab(
            box: Hive.box<InventoryEntry>('entries'),
            resentmentController: _resentmentController,
            reasonController: _reasonController,
            affectController: _affectController,
            partController: _partController,
            defectController: _defectController,
            editingIndex: editingIndex,
            selectedIAmId: selectedIAmId,
            onIAmChanged: (String? id) {
              setState(() {
                selectedIAmId = id;
              });
            },
            onSave: _saveEntry,
            onCancel: _resetForm,
          ),
          ListTab(
            box: Hive.box<InventoryEntry>('entries'),
            onEdit: _editEntry,
            onDelete: _deleteEntry,
          ),
          SettingsTab(box: Hive.box<InventoryEntry>('entries')),
        ],
      ),
    );
  }
}