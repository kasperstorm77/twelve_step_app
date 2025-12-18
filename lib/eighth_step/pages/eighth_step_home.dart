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
import 'eighth_step_settings_tab.dart' as settings;

class EighthStepHome extends StatefulWidget {
  final VoidCallback? onAppSwitched;

  const EighthStepHome({super.key, this.onAppSwitched});

  @override
  State<EighthStepHome> createState() => _EighthStepHomeState();
}

class _EighthStepHomeState extends State<EighthStepHome> {

  void _showEditPersonDialog(String internalId) {
    final box = Hive.box<Person>('people_box');
    final person = box.values.cast<Person?>().firstWhere(
      (p) => p?.internalId == internalId,
      orElse: () => null,
    );
    
    if (person == null) return;
    
    showDialog(
      context: context,
      builder: (context) => settings.PersonEditDialog(
        person: person,
        onSave: (name, amends, column, amendsDone) {
          final updatedPerson = person.copyWith(
            name: name,
            amends: amends,
            column: column,
            amendsDone: amendsDone,
          );
          PersonService.updatePerson(updatedPerson);
        },
        onDelete: () {
          PersonService.deletePerson(person.internalId);
        },
      ),
    );
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
                    
                    // Trigger callback
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
        title: Text(t(context, 'eighth_step_title'), style: const TextStyle(fontSize: 18)),
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
                AvailableApps.eighthStepAmends,
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
      ),
      body: EighthStepMainTab(onViewPerson: _showEditPersonDialog),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonDialog(context),
        child: const Icon(Icons.add),
      ),
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
        
        // Sort by sortOrder within each column
        final yesPeople = people.where((p) => p.column == ColumnType.yes).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final noPeople = people.where((p) => p.column == ColumnType.no).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final maybePeople = people.where((p) => p.column == ColumnType.maybe).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

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
            child: _DroppableColumn(
              items: items,
              columnType: columnType,
              onViewPerson: onViewPerson,
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

/// A column that supports dropping items at specific positions
class _DroppableColumn extends StatefulWidget {
  final List<Person> items;
  final ColumnType columnType;
  final Function(String) onViewPerson;

  const _DroppableColumn({
    required this.items,
    required this.columnType,
    required this.onViewPerson,
  });

  @override
  State<_DroppableColumn> createState() => _DroppableColumnState();
}

class _DroppableColumnState extends State<_DroppableColumn> {
  int? _hoverIndex;
  final Map<int, GlobalKey> _itemKeys = {};
  final GlobalKey _listKey = GlobalKey();

  @override
  void didUpdateWidget(_DroppableColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear keys when items change
    if (oldWidget.items.length != widget.items.length) {
      _itemKeys.clear();
    }
  }

  GlobalKey _getKeyForIndex(int index) {
    return _itemKeys.putIfAbsent(index, () => GlobalKey());
  }

  int _calculateDropIndex(Offset globalPosition) {
    final listRenderBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listRenderBox == null) return widget.items.length;

    final localY = listRenderBox.globalToLocal(globalPosition).dy;

    // Find the item we're hovering over by checking actual rendered positions
    for (int i = 0; i < widget.items.length; i++) {
      final key = _itemKeys[i];
      if (key?.currentContext == null) continue;

      final itemRenderBox = key!.currentContext!.findRenderObject() as RenderBox?;
      if (itemRenderBox == null) continue;

      final itemPosition = itemRenderBox.localToGlobal(Offset.zero);
      final itemLocalY = listRenderBox.globalToLocal(itemPosition).dy;
      final itemHeight = itemRenderBox.size.height;
      final itemCenter = itemLocalY + itemHeight / 2;

      // If drag position is above the center of this item, insert before it
      if (localY < itemCenter) {
        return i;
      }
    }

    // If we're past all items, insert at the end
    return widget.items.length;
  }

  Future<void> _handleDrop(Person person, int insertIndex) async {
    // When dropping from a different column, the visual index maps directly
    // to the target column's items (since dragged item isn't in this column).
    // When dropping within the same column, we need to account for the fact
    // that the dragged item is still visually present but will be "moved".
    
    // For calculating sort order, we need the list WITHOUT the dragged person
    final columnPeopleWithoutDragged = widget.items
        .where((p) => p.internalId != person.internalId)
        .toList();
    
    // For same-column drags, we need to think in terms of the filtered list
    // The insertIndex is based on visual position including the dragged item
    int targetIndex = insertIndex;
    
    if (person.column == widget.columnType) {
      // Find original position in the visual list (which includes the dragged item)
      final originalIndex = widget.items.indexWhere((p) => p.internalId == person.internalId);
      
      // When dragging down (insertIndex > originalIndex), the visual indicator 
      // is below where we'll actually insert in the filtered list
      // When dragging up (insertIndex < originalIndex), no adjustment needed
      if (originalIndex != -1 && insertIndex > originalIndex) {
        targetIndex = insertIndex - 1;
      }
    }
    
    // Clamp target index to valid range for the filtered list
    targetIndex = targetIndex.clamp(0, columnPeopleWithoutDragged.length);

    // Calculate new sort order based on position in filtered list
    int newSortOrder;
    bool needsRebalance = false;
    
    if (columnPeopleWithoutDragged.isEmpty) {
      newSortOrder = 1000;
    } else if (targetIndex == 0) {
      // Insert at beginning - get sortOrder less than first item
      newSortOrder = columnPeopleWithoutDragged.first.sortOrder - 1000;
    } else if (targetIndex == columnPeopleWithoutDragged.length) {
      // Insert at end - get sortOrder greater than last item
      newSortOrder = columnPeopleWithoutDragged.last.sortOrder + 1000;
    } else {
      // Insert between two items - get sortOrder between them
      final before = columnPeopleWithoutDragged[targetIndex - 1].sortOrder;
      final after = columnPeopleWithoutDragged[targetIndex].sortOrder;
      final gap = after - before;
      
      if (gap <= 1) {
        // Gap is too small - need to rebalance after insertion
        needsRebalance = true;
        newSortOrder = before; // Temporary, will be fixed by rebalance
      } else {
        newSortOrder = before + (gap ~/ 2);
      }
    }

    // Update the dropped person
    final updated = person.copyWith(
      column: widget.columnType,
      sortOrder: newSortOrder,
    );
    updated.lastModified = DateTime.now();
    await PersonService.updatePerson(updated);
    
    // Rebalance if needed - reassign evenly-spaced sortOrders to all items in column
    if (needsRebalance) {
      await _rebalanceColumn();
    }
  }
  
  Future<void> _rebalanceColumn() async {
    // Get all people in this column, sorted by current sortOrder
    final box = Hive.box<Person>('people_box');
    final columnPeople = box.values
        .where((p) => p.column == widget.columnType)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    
    // Reassign sortOrders with large gaps (1000 apart)
    for (int i = 0; i < columnPeople.length; i++) {
      final newOrder = (i + 1) * 1000;
      if (columnPeople[i].sortOrder != newOrder) {
        final updated = columnPeople[i].copyWith(sortOrder: newOrder);
        updated.lastModified = DateTime.now();
        await PersonService.updatePerson(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Person>(
      onWillAcceptWithDetails: (details) => true,
      onLeave: (data) {
        setState(() => _hoverIndex = null);
      },
      onMove: (details) {
        final newIndex = _calculateDropIndex(details.offset);
        if (_hoverIndex != newIndex) {
          setState(() => _hoverIndex = newIndex);
        }
      },
      onAcceptWithDetails: (details) async {
        final insertIndex = _hoverIndex ?? widget.items.length;
        await _handleDrop(details.data, insertIndex);
        setState(() => _hoverIndex = null);
      },
      builder: (context, candidateData, rejectedData) {
        final isDraggingOver = candidateData.isNotEmpty;
        
        return Container(
          decoration: BoxDecoration(
            color: isDraggingOver 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04) 
                : null,
          ),
          child: ListView(
            key: _listKey,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            children: [
              // Build items with drop indicators
              for (int i = 0; i <= widget.items.length; i++) ...[
                // Drop indicator before this position
                if (isDraggingOver && _hoverIndex == i)
                  _DropIndicator(),
                // The actual item (if not past the end)
                if (i < widget.items.length)
                  Draggable<Person>(
                    data: widget.items[i],
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 3 - 24,
                        child: PersonCard(
                          person: widget.items[i],
                          onViewPerson: widget.onViewPerson,
                          isDragging: true,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: PersonCard(
                        key: _getKeyForIndex(i),
                        person: widget.items[i],
                        onViewPerson: widget.onViewPerson,
                      ),
                    ),
                    child: PersonCard(
                      key: _getKeyForIndex(i),
                      person: widget.items[i],
                      onViewPerson: widget.onViewPerson,
                    ),
                  ),
              ],
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }
}

/// Visual indicator showing where an item will be dropped
class _DropIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
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
      margin: const EdgeInsets.symmetric(vertical: 3),
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
