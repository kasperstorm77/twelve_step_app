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

  const ListTab({
    super.key,
    required this.box,
    required this.onEdit,
    this.onDelete,
    this.isProcessing = false,
  });

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  bool showTable = false;
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

  /// Get the I Am name for display, using the centralized service
  /// Returns null if iAmId is null/empty or if the I Am definition is not found
  String? _getIAmName(String? iAmId) {
    return _iAmService.getNameById(_iAmBox, iAmId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(showTable ? Icons.list : Icons.table_chart),
                tooltip: showTable
                    ? t(context, 'switch_list_view')
                    : t(context, 'switch_table_view'),
                onPressed: () => setState(() => showTable = !showTable),
              ),
            ],
          ),
          Expanded(
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

                if (showTable) {
                  final headerColor =
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.8);
                  final rowBaseColor =
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columnWidth = constraints.maxWidth / 6;

                      return Column(
                        children: [
                          Container(
                            color: headerColor,
                            child: Row(
                              children: [
                                for (final header in [
                                  t(context, 'resentment'),
                                  t(context, 'i_am'),
                                  t(context, 'reason'),
                                  t(context, 'affect_my'),
                                  t(context, 'my_take'),
                                  t(context, 'shortcomings'),
                                ])
                                  Container(
                                    width: columnWidth,
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      header,
                                      softWrap: true,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: List.generate(entries.length, (i) {
                                  final e = entries[i];
                                  final rowColor = (i % 2 == 0)
                                      ? rowBaseColor.withValues(alpha: 0.7)
                                      : rowBaseColor.withValues(alpha: 0.4);
                                  final iAmName = _getIAmName(e.iAmId) ?? '-';

                                  return Container(
                                    color: rowColor,
                                    child: Row(
                                      children: [
                                        for (final text in [
                                          e.safeResentment,
                                          iAmName,
                                          e.safeReason,
                                          e.safeAffect,
                                          e.myTake ?? '',
                                          e.shortcomings ?? ''
                                        ])
                                          Container(
                                            width: columnWidth,
                                            padding: const EdgeInsets.all(8),
                                            child: Text(text, softWrap: true),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final reversedIndex = box.length - 1 - index;
                    final iAmName = _getIAmName(e.iAmId);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${t(context, 'resentment')}: ${e.safeResentment}"),
                            if (iAmName != null)
                              Text("${t(context, 'i_am')}: $iAmName",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text("${t(context, 'reason')}: ${e.safeReason}"),
                            Text("${t(context, 'affect_my')}: ${e.safeAffect}"),
                            Text("${t(context, 'my_take')}: ${e.myTake ?? ''}"),
                            Text("${t(context, 'shortcomings')}: ${e.shortcomings ?? ''}"),
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
          ),
        ],
      ),
    );
  }
}
