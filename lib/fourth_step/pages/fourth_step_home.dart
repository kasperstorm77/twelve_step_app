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
  final VoidCallback? onAppSwitched;

  const ModularInventoryHome({super.key, this.onAppSwitched});

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

  // Scroll controller for list tab to preserve scroll position
  final _listScrollController = ScrollController();
  double? _savedScrollPosition;

  int? editingIndex;
  String? selectedIAmId;  // Selected I Am definition ID
  InventoryCategory selectedCategory = InventoryCategory.resentment;  // Selected category
  bool get isEditing => editingIndex != null;

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
    _tabController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _editEntry(int index) {
    final entry = _inventoryService.getEntryAt(index);
    if (entry != null) {
      // Save scroll position before switching to form tab
      if (_listScrollController.hasClients) {
        _savedScrollPosition = _listScrollController.offset;
      }
      setState(() {
        editingIndex = index;
        selectedIAmId = entry.iAmId;
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
      editingIndex = null;
      selectedIAmId = null;
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
    final entry = InventoryEntry(
      _resentmentController.text,
      _reasonController.text,
      _affectController.text,
      _partController.text,
      _defectController.text,
      iAmId: selectedIAmId,
      category: selectedCategory,
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

  void _changeLanguage(String langCode) {
    final localeProvider = Modular.get<LocaleProvider>();
    localeProvider.changeLocale(Locale(langCode));
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
    final apps = AvailableApps.getAll(context);
    final currentAppId = AppSwitcherService.getSelectedAppId();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(context, 'select_app')),
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
              selected: isSelected,
              onTap: () async {
                if (app.id != currentAppId) {
                  await AppSwitcherService.setSelectedAppId(app.id);
                  if (!mounted) return;
                  
                  // Trigger callback to refresh parent AppRouter
                  if (widget.onAppSwitched != null) {
                    widget.onAppSwitched!();
                  }
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
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
            editingIndex: editingIndex,
            selectedIAmId: selectedIAmId,
            selectedCategory: selectedCategory,
            onIAmChanged: (String? id) {
              setState(() {
                selectedIAmId = id;
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
          ),
            SettingsTab(box: Hive.box<InventoryEntry>('entries')),
          ],
        ),
      ),
    );
  }
}