import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import '../models/i_am_definition.dart';
import '../localizations.dart';

class FormTab extends StatelessWidget {
  final Box<InventoryEntry> box;
  final TextEditingController resentmentController;
  final TextEditingController reasonController;
  final TextEditingController affectController;
  final TextEditingController partController;
  final TextEditingController defectController;
  final int? editingIndex;
  final String? selectedIAmId;
  final ValueChanged<String?>? onIAmChanged;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  const FormTab({
    super.key,
    required this.box,
    required this.resentmentController,
    required this.reasonController,
    required this.affectController,
    required this.partController,
    required this.defectController,
    this.editingIndex,
    this.selectedIAmId,
    this.onIAmChanged,
    this.onSave,
    this.onCancel,
  });

  bool get isEditing => editingIndex != null;

  @override
  Widget build(BuildContext context) {
    final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    final selectedIAm = selectedIAmId != null
        ? iAmBox.values.firstWhere(
            (def) => def.id == selectedIAmId,
            orElse: () => IAmDefinition(id: '', name: ''),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(context, resentmentController, 'resentment'),
            
            // I Am + Reason (Cause) section
            _buildIAmWithReasonField(context, iAmBox, selectedIAm, reasonController),
            
            _buildTextField(context, affectController, 'affect_my'),
            _buildTextField(context, partController, 'my_take', showTooltip: true),
            _buildTextField(context, defectController, 'shortcomings'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(isEditing ? Icons.save : Icons.add),
              onPressed: onSave,
              label: Text(
                isEditing ? t(context, 'save_changes') : t(context, 'add_entry'),
              ),
            ),
            if (isEditing && onCancel != null)
              TextButton.icon(
                icon: const Icon(Icons.cancel),
                onPressed: onCancel,
                label: Text(t(context, 'cancel_edit')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIAmWithReasonField(BuildContext context, Box<IAmDefinition> iAmBox, 
      IAmDefinition? selectedIAm, TextEditingController reasonController) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected I Am display above the field
          if (selectedIAm != null && selectedIAm.name.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${t(context, 'i_am')}: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      selectedIAm.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (selectedIAm.reasonToExist != null && selectedIAm.reasonToExist!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 18),
                      tooltip: selectedIAm.reasonToExist,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(selectedIAm.name),
                            content: Text(selectedIAm.reasonToExist!),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(t(context, 'close')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: t(context, 'no_i_am_selected'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onIAmChanged?.call(null),
                  ),
                ],
              ),
            ),
          
          // Reason field with person icon
          TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: t(context, 'reason'),
              border: const OutlineInputBorder(),
              prefixIcon: IconButton(
                icon: Icon(
                  selectedIAm == null ? Icons.person_add_outlined : Icons.person,
                  color: selectedIAm == null 
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
                    : Theme.of(context).colorScheme.primary,
                ),
                tooltip: t(context, 'select_i_am'),
                onPressed: () => _showIAmSelection(context, iAmBox),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIAmSelection(BuildContext context, Box<IAmDefinition> iAmBox) {
    final definitions = iAmBox.values.toList();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filteredDefinitions = definitions.where((def) {
            if (searchQuery.isEmpty) return true;
            return def.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (def.reasonToExist?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
          }).toList();

          return AlertDialog(
            title: Text(t(context, 'select_i_am')),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  // Search field
                  TextField(
                    decoration: InputDecoration(
                      labelText: t(context, 'search'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // List of I Am definitions
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredDefinitions.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // "None" option
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.clear, color: Theme.of(context).colorScheme.error),
                              title: Text(
                                t(context, 'no_i_am_selected'),
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                              onTap: () {
                                onIAmChanged?.call(null);
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        }

                        final definition = filteredDefinitions[index - 1];
                        final isSelected = selectedIAmId == definition.id;
                        
                        return Card(
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primaryContainer 
                            : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.person,
                              color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                            ),
                            title: Text(
                              definition.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                            subtitle: definition.reasonToExist != null &&
                                    definition.reasonToExist!.isNotEmpty
                                ? Text(
                                    definition.reasonToExist!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: isSelected 
                              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                              : null,
                            onTap: () {
                              onIAmChanged?.call(definition.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(context, 'close')),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildTextField(
      BuildContext context, TextEditingController controller, String key, {bool showTooltip = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: t(context, key),
          border: const OutlineInputBorder(),
          suffixIcon: showTooltip
            ? GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(t(context, key)),
                      content: Text(t(context, 'part_tooltip')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(t(context, 'close')),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(
                  Icons.help_outline,
                  size: 20,
                  color: Colors.grey,
                ),
              )
            : null,
        ),
      ),
    );
  }
}
