import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../shared/localizations.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/pages/data_management_page.dart';
import '../../shared/services/locale_provider.dart';
import 'gratitude_today_tab.dart';
import 'gratitude_list_tab.dart';

class GratitudeHome extends StatefulWidget {
  final VoidCallback? onAppSwitched;

  const GratitudeHome({super.key, this.onAppSwitched});

  @override
  State<GratitudeHome> createState() => _GratitudeHomeState();
}

class _GratitudeHomeState extends State<GratitudeHome> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      // Switch to today tab when date selected from history
    });
    _tabController.animateTo(0);
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
                  
                  if (widget.onAppSwitched != null) {
                    widget.onAppSwitched!();
                  }
                  
                  if (!context.mounted) return;
                  
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'gratitude_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: 'Switch App',
            onPressed: _showAppSwitcher,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openDataManagement,
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
            Tab(text: t(context, 'gratitude_today_tab')),
            Tab(text: t(context, 'gratitude_view_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const GratitudeTodayTab(),
          GratitudeListTab(
            onDateSelected: _onDateSelected,
          ),
        ],
      ),
    );
  }
}
