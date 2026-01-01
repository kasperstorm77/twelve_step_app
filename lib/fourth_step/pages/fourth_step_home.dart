import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../../shared/models/app_entry.dart';
import 'form_tab.dart';
import 'list_tab.dart';
import 'settings_tab.dart';
import '../../shared/localizations.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../services/inventory_service.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/services/locale_provider.dart';
import '../../shared/pages/data_management_page.dart';

class ModularInventoryHome extends StatefulWidget {
  const ModularInventoryHome({super.key});

  @override
  State<ModularInventoryHome> createState() => _ModularInventoryHomeState();
}

class _ModularInventoryHomeState extends State<ModularInventoryHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final InventoryService _inventoryService;

  // Text controllers for form
  final _resentmentController = TextEditingController();
  final _reasonController = TextEditingController();
  final _affectController = TextEditingController();
  final _partController = TextEditingController();
  final _defectController = TextEditingController();

  // Filter controller for entries list (persistent across tab switches)
  final _filterController = TextEditingController();

  // Scroll controller for list tab to preserve scroll position
  final _listScrollController = ScrollController();
  double? _savedScrollPosition;

  dynamic editingKey;  // Hive key of entry being edited (null if adding new)
  List<String> selectedIAmIds = [];  // Selected I Am definition IDs (multiple)
  InventoryCategory selectedCategory = InventoryCategory.resentment;  // Selected category
  bool get isEditing => editingKey != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inventoryService = InventoryService();
    
    AllAppsDriveService.instance.loadSyncState();
    
    // Note: No longer listening to all upload events to avoid showing notifications
    // for background sync. User-initiated actions in Settings show their own notifications.
    // Sync is handled automatically via timestamp comparison in main.dart
  }

  @override
  void dispose() {
    // No upload subscription to cancel anymore
    _resentmentController.dispose();
    _reasonController.dispose();
    _affectController.dispose();
    _partController.dispose();
    _defectController.dispose();
    _filterController.dispose();
    _tabController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _editEntry(dynamic key) {
    final entry = _inventoryService.getEntryByKey(key);
    if (entry != null) {
      // Save scroll position before switching to form tab
      if (_listScrollController.hasClients) {
        _savedScrollPosition = _listScrollController.offset;
      }
      setState(() {
        editingKey = key;
        selectedIAmIds = List<String>.from(entry.effectiveIAmIds);
        selectedCategory = entry.effectiveCategory;
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
    final savedPosition = _savedScrollPosition;
    setState(() {
      editingKey = null;
      selectedIAmIds = [];
      selectedCategory = InventoryCategory.resentment;
      _resentmentController.clear();
      _reasonController.clear();
      _affectController.clear();
      _partController.clear();
      _defectController.clear();
      _savedScrollPosition = null;
    });
    _tabController.animateTo(1); // Switch to list tab
    
    // Restore scroll position after switching to list tab
    // Use Future.delayed to wait for tab animation and list rebuild
    if (savedPosition != null) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _listScrollController.hasClients) {
          _listScrollController.animateTo(
            savedPosition,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _saveEntry() async {
    // When editing, preserve the existing entry's ID and order
    final existingEntry = editingKey != null ? _inventoryService.getEntryByKey(editingKey) : null;
    
    final entry = InventoryEntry(
      _resentmentController.text,
      _reasonController.text,
      _affectController.text,
      _partController.text,
      _defectController.text,
      iAmIds: selectedIAmIds.isNotEmpty ? selectedIAmIds : null,
      category: selectedCategory,
      id: existingEntry?.id,  // Preserve ID when editing
      order: existingEntry?.order,  // Preserve order when editing
    );
    
    if (isEditing && editingKey != null) {
      await _inventoryService.updateEntryByKey(editingKey, entry);
    } else {
      await _inventoryService.addEntry(entry);
    }

    _resetForm();
  }

  Future<void> _deleteEntry(dynamic key) async {
    await _inventoryService.deleteEntryByKey(key);
  }

  void _changeLanguage(String langCode) {
    final localeProvider = Modular.get<LocaleProvider>();
    localeProvider.changeLocale(Locale(langCode));
  }

  void _openDataManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DataManagementPage(),
      ),
    );
    // Force rebuild after returning from Data Management
    // to ensure restored data is displayed
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAppSwitcher() async {
    final apps = AvailableApps.getAll(context);
    final currentAppId = AppSwitcherService.getSelectedAppId();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t(context, 'select_app'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: apps.map((app) {
              final isSelected = app.id == currentAppId;
              return InkWell(
                onTap: () async {
                  if (app.id != currentAppId) {
                    await AppSwitcherService.setSelectedAppId(app.id);
                    if (!mounted) return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : null,
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'cancel')),
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
        title: Text(t(context, 'app_title'), style: const TextStyle(fontSize: 18)),
        actions: [
          // App Switcher Icon
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: t(context, 'switch_app'),
            onPressed: _showAppSwitcher,
            visualDensity: VisualDensity.compact,
          ),
          // Help Icon
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: t(context, 'help'),
            onPressed: () {
              AppHelpService.showHelpDialog(
                context,
                AvailableApps.fourthStepInventory,
              );
            },
            visualDensity: VisualDensity.compact,
          ),
          // Settings Icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _openDataManagement();
            },
            visualDensity: VisualDensity.compact,
          ),
          // Language Selector
          PopupMenuButton<String>(
            onSelected: _changeLanguage,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'en', child: Text(t(context, 'lang_english'))),
              PopupMenuItem(value: 'da', child: Text(t(context, 'lang_danish'))),
            ],
            icon: const Icon(Icons.language),
            padding: EdgeInsets.zero,
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
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            FormTab(
              box: Hive.box<InventoryEntry>('entries'),
              resentmentController: _resentmentController,
              reasonController: _reasonController,
              affectController: _affectController,
              partController: _partController,
              defectController: _defectController,
              isEditing: isEditing,
              selectedIAmIds: selectedIAmIds,
              selectedCategory: selectedCategory,
              onIAmIdsChanged: (List<String> ids) {
                setState(() {
                  selectedIAmIds = ids;
                });
              },
              onCategoryChanged: (InventoryCategory category) {
                setState(() {
                  selectedCategory = category;
                });
              },
              onSave: _saveEntry,
              onCancel: _resetForm,
            ),
            ListTab(
              box: Hive.box<InventoryEntry>('entries'),
              onEdit: _editEntry,
              onDelete: _deleteEntry,
              scrollController: _listScrollController,
              filterController: _filterController,
            ),
            SettingsTab(box: Hive.box<InventoryEntry>('entries')),
          ],
        ),
      ),
    );
  }
}