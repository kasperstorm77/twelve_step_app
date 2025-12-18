import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/services/i_am_service.dart';
import '../../fourth_step/services/inventory_service.dart';
import '../../shared/localizations.dart';

class ListTab extends StatefulWidget {
  final Box<InventoryEntry> box;
  final void Function(dynamic key) onEdit;  // Now uses Hive key instead of index
  final void Function(dynamic key)? onDelete;  // Now uses Hive key instead of index
  final bool isProcessing;
  final ScrollController? scrollController;
  final TextEditingController? filterController;  // Filter controller from parent (persistent)

  const ListTab({
    super.key,
    required this.box,
    required this.onEdit,
    this.onDelete,
    this.isProcessing = false,
    this.scrollController,
    this.filterController,
  });

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  late final Box<IAmDefinition> _iAmBox;
  final _iAmService = IAmService();
  final _inventoryService = InventoryService();
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    // Listen to I Am box changes to rebuild the list
    _iAmBox.listenable().addListener(_onIAmChanged);
    // Listen to filter changes from parent controller
    widget.filterController?.addListener(_onFilterChanged);
    _filterText = widget.filterController?.text ?? '';
  }

  /// Builds a heading + value pair where the heading uses the same blue,
  /// bold styling used for I Am names and the value is on a new line.
  /// Returns an empty SizedBox if value is empty to avoid wasted space.
  Widget _buildHeadingValue(BuildContext context, String headingKey, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, headingKey),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _iAmBox.listenable().removeListener(_onIAmChanged);
    widget.filterController?.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) {
      setState(() {
        _filterText = widget.filterController?.text ?? '';
      });
    }
  }

  void _onIAmChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Get all I Am names for display (for multiple I Ams)
  /// Returns list of names, filtering out any not found
  List<String> _getIAmNames(List<String> iAmIds) {
    return iAmIds
        .map((id) => _iAmService.getNameById(_iAmBox, id))
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }

  /// Get the localization key for field 1 based on category
  String _getField1LabelKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'resentment_field1';
      case InventoryCategory.fear:
        return 'fear_field1';
      case InventoryCategory.harms:
        return 'harms_field1';
      case InventoryCategory.sexualHarms:
        return 'sexual_harms_field1';
    }
  }

  /// Get the localization key for field 2 based on category
  String _getField2LabelKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'resentment_field2';
      case InventoryCategory.fear:
        return 'fear_field2';
      case InventoryCategory.harms:
        return 'harms_field2';
      case InventoryCategory.sexualHarms:
        return 'sexual_harms_field2';
    }
  }

  /// Get the localization key for category name
  String _getCategoryLabelKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'category_resentment';
      case InventoryCategory.fear:
        return 'category_fear';
      case InventoryCategory.harms:
        return 'category_harms';
      case InventoryCategory.sexualHarms:
        return 'category_sexual_harms';
    }
  }

  /// Get icon for category
  IconData _getCategoryIcon(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return Icons.sentiment_very_dissatisfied;
      case InventoryCategory.fear:
        return Icons.warning_amber;
      case InventoryCategory.harms:
        return Icons.heart_broken;
      case InventoryCategory.sexualHarms:
        return Icons.privacy_tip;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filter field (only shown on this tab, but text persists via parent controller)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: widget.filterController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: t(context, 'filter_entries'),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.outline),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                suffixIcon: _filterText.isNotEmpty
                    ? GestureDetector(
                        onTap: () => widget.filterController?.clear(),
                        child: Icon(Icons.clear, size: 18, color: theme.colorScheme.outline),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 36),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                isDense: true,
              ),
            ),
          ),
        ),
        // List content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ValueListenableBuilder(
              valueListenable: widget.box.listenable(),
              builder: (context, Box<InventoryEntry> box, _) {
                // Also listen to I Am box changes for name lookups
                return ValueListenableBuilder(
                  valueListenable: _iAmBox.listenable(),
                  builder: (context, Box<IAmDefinition> iAmBox, _) {
                    if (box.isEmpty) {
                      return Center(child: Text(t(context, 'no_entries')));
                    }

                    // Get entries sorted by order (highest first)
                    var entries = _inventoryService.getAllEntries();
                    
                    // Apply filter if 2+ characters entered (wildcard on resentment field)
                    if (_filterText.length >= 2) {
                      final filterLower = _filterText.toLowerCase();
                      entries = entries.where((e) => 
                        e.safeResentment.toLowerCase().contains(filterLower)
                      ).toList();
                    }
                    
                    if (entries.isEmpty) {
                      return Center(child: Text(t(context, 'no_matching_entries')));
                    }

                    return ReorderableListView.builder(
                      key: const PageStorageKey<String>('fourth_step_list'),
                      scrollController: widget.scrollController,
                      buildDefaultDragHandles: false,
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
                      itemCount: entries.length,
                      onReorder: (oldIndex, newIndex) {
                        // Adjust newIndex for the removal
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        _inventoryService.reorderEntries(oldIndex, newIndex);
                      },
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
                            return Material(
                              elevation: elevation,
                              borderRadius: BorderRadius.circular(12),
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                itemBuilder: (context, index) {
                  final e = entries[index];
                  final iAmNames = _getIAmNames(e.effectiveIAmIds);
                  final category = e.effectiveCategory;

                  return Card(
                    key: ValueKey(e.id), // Use unique ID as key for reordering
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category chip and drag handle row
                          Row(
                            children: [
                              Chip(
                                avatar: Icon(
                                  _getCategoryIcon(category),
                                  size: 16,
                                ),
                                label: Text(
                                  t(context, _getCategoryLabelKey(category)),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              const Spacer(),
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _buildHeadingValue(context, _getField1LabelKey(category), e.safeResentment),
                          // Display all I Am names (stacked if multiple)
                          if (iAmNames.isNotEmpty)
                            ...iAmNames.map((name) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t(context, 'i_am'),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(name, style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            )),
                          _buildHeadingValue(context, _getField2LabelKey(category), e.safeReason),
                          _buildHeadingValue(context, 'affects_my', e.safeAffect),
                          _buildHeadingValue(context, 'my_part', e.myTake ?? ''),
                          _buildHeadingValue(context, 'shortcoming_field', e.shortcomings ?? ''),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: t(context, 'edit_entry'),
                                onPressed: () => widget.onEdit(e.key),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: t(context, 'delete_entry'),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text(t(context, 'delete_entry')),
                                      content: Text(t(context, 'delete_confirm')),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(t(context, 'cancel')),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(
                                            t(context, 'delete'),
                                            style: TextStyle(
                                                color:
                                                    theme.colorScheme.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm ?? false) {
                                    await _inventoryService.deleteEntryByKey(e.key);
                                    widget.onDelete?.call(e.key);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              t(context, 'entry_deleted'))),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}