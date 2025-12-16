import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/services/i_am_service.dart';
import '../../shared/localizations.dart';

class ListTab extends StatefulWidget {
  final Box<InventoryEntry> box;
  final void Function(int index) onEdit;
  final void Function(int index)? onDelete;
  final bool isProcessing;
  final ScrollController? scrollController;

  const ListTab({
    super.key,
    required this.box,
    required this.onEdit,
    this.onDelete,
    this.isProcessing = false,
    this.scrollController,
  });

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  late final Box<IAmDefinition> _iAmBox;
  final _iAmService = IAmService();

  @override
  void initState() {
    super.initState();
    _iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    // Listen to I Am box changes to rebuild the list
    _iAmBox.listenable().addListener(_onIAmChanged);
  }

  @override
  void dispose() {
    _iAmBox.listenable().removeListener(_onIAmChanged);
    super.dispose();
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

    return Padding(
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

              final entries = box.values.toList().reversed.toList();

              return ListView.builder(
                  key: const PageStorageKey<String>('fourth_step_list'),
                  controller: widget.scrollController,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final reversedIndex = box.length - 1 - index;
                    final iAmNames = _getIAmNames(e.effectiveIAmIds);
                    final category = e.effectiveCategory;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category chip
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Chip(
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
                            ),
                            Text("${t(context, _getField1LabelKey(category))}: ${e.safeResentment}"),
                            // Display all I Am names (stacked if multiple)
                            if (iAmNames.isNotEmpty)
                              ...iAmNames.map((name) => Text(
                                "${t(context, 'i_am')}: $name",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                            Text("${t(context, _getField2LabelKey(category))}: ${e.safeReason}"),
                            Text("${t(context, 'affects_my')}: ${e.safeAffect}"),
                            Text("${t(context, 'my_part')}: ${e.myTake ?? ''}"),
                            Text("${t(context, 'shortcoming_field')}: ${e.shortcomings ?? ''}"),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: t(context, 'edit_entry'),
                                  onPressed: () => widget.onEdit(reversedIndex),
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
                                      if (reversedIndex >= 0 &&
                                          reversedIndex < box.length) {
                                        await box.deleteAt(reversedIndex);
                                        widget.onDelete?.call(reversedIndex);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  t(context, 'entry_deleted'))),
                                        );
                                      }
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
    );
  }
}