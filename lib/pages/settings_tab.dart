import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../models/i_am_definition.dart';
import '../services/i_am_service.dart';
import '../localizations.dart';

class SettingsTab extends StatefulWidget {
  final Box<InventoryEntry> box;

  const SettingsTab({super.key, required this.box});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _iAmService = IAmService();

  @override
  Widget build(BuildContext context) {
    final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');

    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: iAmBox.listenable(),
        builder: (context, Box<IAmDefinition> box, _) {
          final definitions = box.values.toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t(context, 'i_am_definitions'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(context, box),
                      icon: const Icon(Icons.add),
                      label: Text(t(context, 'add_i_am')),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: definitions.isEmpty
                    ? Center(
                        child: Text(
                          t(context, 'no_entries'),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: definitions.length,
                        itemBuilder: (context, index) {
                          final definition = definitions[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              title: Text(
                                definition.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: definition.reasonToExist != null &&
                                      definition.reasonToExist!.isNotEmpty
                                  ? Text(definition.reasonToExist!)
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showAddEditDialog(
                                      context,
                                      box,
                                      index: index,
                                      definition: definition,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        _confirmDelete(context, box, index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    Box<IAmDefinition> box, {
    int? index,
    IAmDefinition? definition,
  }) {
    final nameController = TextEditingController(text: definition?.name ?? '');
    final reasonController =
        TextEditingController(text: definition?.reasonToExist ?? '');
    final isEdit = definition != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, isEdit ? 'edit_i_am' : 'add_i_am')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: t(context, 'i_am_name'),
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: t(context, 'reason_to_exist_optional'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t(context, 'i_am_name_required'))),
                );
                return;
              }

              final newDefinition = IAmDefinition(
                id: definition?.id ?? _iAmService.generateId(),
                name: name,
                reasonToExist: reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim(),
              );

              if (isEdit && index != null) {
                _iAmService.updateDefinition(box, index, newDefinition);
              } else {
                _iAmService.addDefinition(box, newDefinition);
              }

              Navigator.of(context).pop();
            },
            child: Text(t(context, 'save_changes')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Box<IAmDefinition> box, int index) {
    final definition = box.getAt(index);
    if (definition == null) return;

    // Check if this I Am is being used by any entries
    final entriesBox = widget.box;
    final usageCount = entriesBox.values.where((entry) => entry.iAmId == definition.id).length;

    if (usageCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t(context, 'delete_i_am')),
          content: Text(
            'Cannot delete "${definition.name}" because it is used by $usageCount ${usageCount == 1 ? 'entry' : 'entries'}.\n\n'
            'Please remove or change the I Am for those entries first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'close')),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'delete_i_am')),
        content: Text(t(context, 'confirm_delete_i_am')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              _iAmService.deleteDefinition(box, index);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(t(context, 'delete_i_am')),
          ),
        ],
      ),
    );
  }
}
