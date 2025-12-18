import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../shared/localizations.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/pages/data_management_page.dart';
import '../../shared/services/locale_provider.dart';
import 'paper_tab.dart';
import 'archive_tab.dart';

class AgnosticismHome extends StatefulWidget {
  final VoidCallback? onAppSwitched;

  const AgnosticismHome({super.key, this.onAppSwitched});

  @override
  State<AgnosticismHome> createState() => _AgnosticismHomeState();
}

class _AgnosticismHomeState extends State<AgnosticismHome> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _paperController = PaperTabController();
  final _forceShowBack = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // When animation completes and we're on paper tab (index 0) with forceShowBack set
    if (!_tabController.indexIsChanging && _tabController.index == 0 && _forceShowBack.value) {
      _paperController.showBackInstant();
      _forceShowBack.value = false;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _forceShowBack.dispose();
    super.dispose();
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
                    
                    if (widget.onAppSwitched != null) {
                      widget.onAppSwitched!();
                    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'agnosticism_title'), style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: t(context, 'switch_app'),
            onPressed: _showAppSwitcher,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: t(context, 'help'),
            onPressed: () {
              AppHelpService.showHelpDialog(
                context,
                AvailableApps.agnosticism,
              );
            },
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openDataManagement,
            visualDensity: VisualDensity.compact,
          ),
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
            Tab(text: t(context, 'agnosticism_paper_tab')),
            Tab(text: t(context, 'agnosticism_archive_tab')),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            PaperTab(
              controller: _paperController,
              onNavigateToArchive: () => _tabController.animateTo(1),
              forceShowBack: _forceShowBack,
            ),
            ArchiveTab(
              onSwipeToBack: () {
                _forceShowBack.value = true;
                _tabController.animateTo(0);
              },
            ),
          ],
        ),
      ),
    );
  }
}
