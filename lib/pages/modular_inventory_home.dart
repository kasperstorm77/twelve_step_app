import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../pages/form_tab.dart';
import '../pages/list_tab.dart';
import '../pages/settings_tab.dart';
import '../localizations.dart';
import '../services/drive_service.dart';
import '../services/inventory_service.dart';
import '../services/app_version_service.dart';
import 'data_management_page.dart';

class ModularInventoryHome extends StatefulWidget {
  final Locale? currentLocale;
  final void Function(Locale)? setLocale;

  const ModularInventoryHome({super.key, this.currentLocale, this.setLocale});

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
  bool get isEditing => editingIndex != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inventoryService = Modular.get<InventoryService>();
    _driveService = Modular.get<DriveService>();
    
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
      print('Error checking for new install/update: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _openDataManagement();
            },
          ),
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