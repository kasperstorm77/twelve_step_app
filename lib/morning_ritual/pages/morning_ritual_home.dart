import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/morning_ritual_service.dart';
import '../../shared/localizations.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/pages/data_management_page.dart';
import '../../shared/services/locale_provider.dart';
import 'morning_ritual_today_tab.dart';
import 'morning_ritual_history_tab.dart';
import 'morning_ritual_settings_tab.dart';

class MorningRitualHome extends StatefulWidget {
  const MorningRitualHome({super.key});

  @override
  State<MorningRitualHome> createState() => _MorningRitualHomeState();
}

class _MorningRitualHomeState extends State<MorningRitualHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final GlobalKey<MorningRitualSettingsTabState> _settingsKey = GlobalKey();
  bool _ritualInProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    setState(() {}); // Rebuild to show/hide FAB
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    // Ensure wake lock is disabled when leaving Morning Ritual app
    WakelockPlus.disable();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDay = date;
      _focusedDay = date;
    });
    _tabController.animateTo(0); // Go to Today tab
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'morning_ritual_title'), style: const TextStyle(fontSize: 18)),
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
                AvailableApps.morningRitual,
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
              PopupMenuItem(
                  value: 'en', child: Text(t(context, 'lang_english'))),
              PopupMenuItem(
                  value: 'da', child: Text(t(context, 'lang_danish'))),
            ],
            icon: const Icon(Icons.language),
            padding: EdgeInsets.zero,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t(context, 'morning_ritual_today_tab')),
            Tab(text: t(context, 'morning_ritual_history_tab')),
            Tab(text: t(context, 'settings_title')),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Today Tab with Calendar at top (hidden during ritual)
            Column(
              children: [
                // Hide calendar when ritual is in progress
                if (!_ritualInProgress)
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
                        return MorningRitualService.hasEntryForDate(day)
                            ? [true]
                            : [];
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
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5),
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
                  child: MorningRitualTodayTab(
                    selectedDate: _selectedDay,
                    onRitualStartedChanged: (started) {
                      setState(() {
                        _ritualInProgress = started;
                      });
                    },
                    onRitualCompleted: () {
                      setState(() {}); // Refresh to show completed state
                    },
                  ),
                ),
              ],
            ),
            // History Tab
            MorningRitualHistoryTab(
              onDateSelected: _onDateSelected,
            ),
            // Settings Tab
            MorningRitualSettingsTab(key: _settingsKey),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton(
              onPressed: () {
                _settingsKey.currentState?.showAddItemDialog();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
