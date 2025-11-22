import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/reflection_service.dart';
import '../../shared/localizations.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/pages/data_management_page.dart';
import '../../shared/services/locale_provider.dart';
import 'evening_ritual_form_tab.dart';
import 'evening_ritual_list_tab.dart';

class EveningRitualHome extends StatefulWidget {
  final VoidCallback? onAppSwitched;

  const EveningRitualHome({super.key, this.onAppSwitched});

  @override
  State<EveningRitualHome> createState() => _EveningRitualHomeState();
}

class _EveningRitualHomeState extends State<EveningRitualHome> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

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
      _selectedDay = date;
    });
    _tabController.animateTo(0); // Go to form tab
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
                  
                  // Trigger callback
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'evening_ritual_title')),
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
                AvailableApps.eveningRitual,
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
            Tab(text: t(context, 'evening_ritual_form_tab')),
            Tab(text: t(context, 'evening_ritual_list_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Form Tab with Calendar at top
          Column(
            children: [
              Card(
                margin: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.week,
                  availableCalendarFormats: const {
                    CalendarFormat.week: 'Week',
                    CalendarFormat.month: 'Month',
                  },
                  eventLoader: (day) {
                    return ReflectionService.hasReflectionsForDate(day) ? [true] : [];
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: EveningRitualFormTab(
                  selectedDate: _selectedDay,
                ),
              ),
            ],
          ),
          // List Tab
          EveningRitualListTab(
            onDateSelected: _onDateSelected,
          ),
        ],
      ),
    );
  }
}
