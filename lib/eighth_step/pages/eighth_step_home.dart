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
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(app.name),
              selected: isSelected,
              onTap: () async {
                if (app.id != currentAppId) {
                  await AppSwitcherService.setSelectedAppId(app.id);
                  if (!mounted) return;
                  
                  // Trigger callback
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'eighth_step_title')),
        actions: [
          // App Switcher Icon
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: t(context, 'switch_app'),
            onPressed: _showAppSwitcher,
          ),
          // Help Icon
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: t(context, 'help'),
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

        Widget buildColumnHeader(String label, int count, {bool isFirst = false, bool isLast = false}) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                  bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                  left: isFirst 
                      ? BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3))
                      : BorderSide.none,
                  right: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildColumnContent(List<Person> items, ColumnType columnType) {
          return Expanded(
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
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04) 
                        : null,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    children: [
                      ...items.map((person) => Draggable<Person>(
                        data: person,
                        feedback: Material(
                          elevation: 8,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width / 3 - 24,
                            child: PersonCard(person: person, onViewPerson: onViewPerson, isDragging: true),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: PersonCard(person: person, onViewPerson: onViewPerson)),
                        child: PersonCard(person: person, onViewPerson: onViewPerson),
                      )),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                );
              },
            ),
          );
        }

        return Column(
          children: [
            // Headers row - connected with straight corners
            Row(
              children: [
                buildColumnHeader(t(context, 'eighth_step_yes'), yesPeople.length, isFirst: true),
                buildColumnHeader(t(context, 'eighth_step_no'), noPeople.length),
                buildColumnHeader(t(context, 'eighth_step_maybe'), maybePeople.length, isLast: true),
              ],
            ),
            // Content columns
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildColumnContent(yesPeople, ColumnType.yes),
                  buildColumnContent(noPeople, ColumnType.no),
                  buildColumnContent(maybePeople, ColumnType.maybe),
                ],
              ),
            ),
          ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                person.name,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // View icon
            GestureDetector(
              onTap: () => onViewPerson(person.internalId),
              child: Icon(
                Icons.visibility,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            // Done/Not Done toggle
            GestureDetector(
              onTap: () {
                PersonService.toggleAmendsDone(person.internalId);
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: person.amendsDone ? Colors.green : Colors.red,
                ),
                child: Icon(
                  person.amendsDone ? Icons.check : Icons.remove,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
