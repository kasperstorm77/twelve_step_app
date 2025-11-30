import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/person.dart';
import '../services/person_service.dart';
import '../../shared/localizations.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/pages/data_management_page.dart';
import '../../shared/services/locale_provider.dart';
import 'eighth_step_view_person_tab.dart';
import 'eighth_step_settings_tab.dart' as settings;

class EighthStepHome extends StatefulWidget {
  final VoidCallback? onAppSwitched;

  const EighthStepHome({super.key, this.onAppSwitched});

  @override
  State<EighthStepHome> createState() => _EighthStepHomeState();
}

class _EighthStepHomeState extends State<EighthStepHome> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _lastViewedPersonId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB based on tab
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onViewPerson(String internalId) {
    setState(() {
      _lastViewedPersonId = internalId;
    });
    _tabController.animateTo(1);
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
                color: isSelected ? Theme.of(dialogContext).colorScheme.primary : null,
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
                      content: Text(t(context, 'switched_to_app').replaceFirst('%s', app.name)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'eighth_step_title')),
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
                AvailableApps.eighthStepAmends,
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
            itemBuilder: (context) => [
              PopupMenuItem(value: 'en', child: Text(t(context, 'lang_english'))),
              PopupMenuItem(value: 'da', child: Text(t(context, 'lang_danish'))),
            ],
            icon: const Icon(Icons.language),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t(context, 'eighth_step_main_tab')),
            Tab(text: t(context, 'eighth_step_view_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          EighthStepMainTab(onViewPerson: _onViewPerson),
          EighthStepViewPersonTab(
            lastViewedPersonId: _lastViewedPersonId,
            onBackToList: () => _tabController.animateTo(0),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showAddPersonDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => settings.PersonEditDialog(
        onSave: (name, amends, column, amendsDone) {
          final newPerson = Person.create(
            name: name,
            amends: amends,
            column: column,
          );
          PersonService.addPerson(newPerson);
        },
      ),
    );
  }
}

class EighthStepMainTab extends StatelessWidget {
  final Function(String) onViewPerson;

  const EighthStepMainTab({super.key, required this.onViewPerson});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Person>>(
      valueListenable: Hive.box<Person>('people_box').listenable(),
      builder: (context, box, widget) {
        final people = box.values.toList();
        final yesPeople = people.where((p) => p.column == ColumnType.yes).toList();
        final noPeople = people.where((p) => p.column == ColumnType.no).toList();
        final maybePeople = people.where((p) => p.column == ColumnType.maybe).toList();

        Widget buildColumn(String label, List<Person> items, ColumnType columnType) {
          return Expanded(
            child: Column(
              children: [
                // Styled header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Count
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${items.length}', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: DragTarget<Person>(
                    onWillAcceptWithDetails: (details) => details.data.column != columnType,
                    onAcceptWithDetails: (details) async {
                      final person = details.data;
                      final updated = person.copyWith(column: columnType);
                      updated.lastModified = DateTime.now();
                      await PersonService.updatePerson(updated);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          children: items.map((person) => Draggable<Person>(
                            data: person,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width / 3 - 40,
                                child: PersonCard(person: person, onViewPerson: onViewPerson, isDragging: true),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.3, child: PersonCard(person: person, onViewPerson: onViewPerson)),
                            child: PersonCard(person: person, onViewPerson: onViewPerson),
                          )).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildColumn(t(context, 'eighth_step_yes'), yesPeople, ColumnType.yes),
              const SizedBox(width: 16),
              buildColumn(t(context, 'eighth_step_no'), noPeople, ColumnType.no),
              const SizedBox(width: 16),
              buildColumn(t(context, 'eighth_step_maybe'), maybePeople, ColumnType.maybe),
            ],
          ),
        );
      },
    );
  }
}

class PersonCard extends StatelessWidget {
  final Person person;
  final Function(String) onViewPerson;
  final bool isDragging;

  const PersonCard({super.key, required this.person, required this.onViewPerson, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: isDragging ? 8 : 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View icon
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  onPressed: () => onViewPerson(person.internalId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                const SizedBox(width: 4),
                // Done/Not Done toggle
                GestureDetector(
                  onTap: () {
                    PersonService.toggleAmendsDone(person.internalId);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: person.amendsDone ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      person.amendsDone ? Icons.check : Icons.remove,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
