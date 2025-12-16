import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/services/i_am_service.dart';
import '../../shared/localizations.dart';

class FormTab extends StatefulWidget {
  final Box<InventoryEntry> box;
  final TextEditingController resentmentController;
  final TextEditingController reasonController;
  final TextEditingController affectController;
  final TextEditingController partController;
  final TextEditingController defectController;
  final int? editingIndex;
  final String? selectedIAmId;
  final InventoryCategory selectedCategory;
  final ValueChanged<String?>? onIAmChanged;
  final ValueChanged<InventoryCategory>? onCategoryChanged;
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
    this.selectedCategory = InventoryCategory.resentment,
    this.onIAmChanged,
    this.onCategoryChanged,
    this.onSave,
    this.onCancel,
  });

  bool get isEditing => editingIndex != null;

  @override
  State<FormTab> createState() => _FormTabState();
}

class _FormTabState extends State<FormTab> {
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
    final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    final iAmService = IAmService();
    final selectedIAm = iAmService.findById(iAmBox, widget.selectedIAmId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category selector
            _buildCategorySelector(context),
            const SizedBox(height: 16),
            
            // Field 1: Resentment / Fear / Who did I hurt
            _buildTextField(
              context, 
              widget.resentmentController, 
              _getField1LabelKey(widget.selectedCategory),
            ),
            
            // I Am + Field 2 (Reason/Cause/What did I do)
            _buildIAmWithReasonField(
              context, 
              iAmBox, 
              selectedIAm, 
              widget.reasonController,
              _getField2LabelKey(widget.selectedCategory),
            ),
            
            // Field 3: Affects my (same for all categories)
            _buildTextField(context, widget.affectController, 'affects_my'),
            
            // Field 4: My part (same for all categories)
            _buildTextField(context, widget.partController, 'my_part', showTooltip: true),
            
            // Field 5: Shortcoming(s) (same for all categories)
            _buildTextField(context, widget.defectController, 'shortcoming_field'),
            
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(widget.isEditing ? Icons.save : Icons.add),
              onPressed: widget.onSave,
              label: Text(
                widget.isEditing ? t(context, 'save_changes') : t(context, 'add_entry'),
              ),
            ),
            if (widget.isEditing && widget.onCancel != null)
              TextButton.icon(
                icon: const Icon(Icons.cancel),
                onPressed: widget.onCancel,
                label: Text(t(context, 'cancel_edit')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: DropdownButtonFormField<InventoryCategory>(
          initialValue: widget.selectedCategory,
          decoration: InputDecoration(
            labelText: t(context, 'category'),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: InventoryCategory.values.map((category) {
            return DropdownMenuItem<InventoryCategory>(
              value: category,
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(t(context, _getCategoryLabelKey(category))),
                ],
              ),
            );
          }).toList(),
          onChanged: (category) {
            if (category != null) {
              widget.onCategoryChanged?.call(category);
            }
          },
        ),
      ),
    );
  }

  Widget _buildIAmWithReasonField(
    BuildContext context, 
    Box<IAmDefinition> iAmBox, 
    IAmDefinition? selectedIAm, 
    TextEditingController reasonController,
    String labelKey,
  ) {
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
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                    onPressed: () => widget.onIAmChanged?.call(null),
                  ),
                ],
              ),
            ),
          
          // Reason field with person icon
          TextField(
            controller: reasonController,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: t(context, labelKey),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              prefixIcon: IconButton(
                icon: Icon(
                  selectedIAm == null ? Icons.person_add_outlined : Icons.person,
                  color: selectedIAm == null 
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
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
                      itemCount: filteredDefinitions.length + 2, // +2 for "None" and "Add new" options
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // "Add new I Am" option
                          return Card(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            child: ListTile(
                              leading: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                              title: Text(
                                t(context, 'add_i_am'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                _showAddIAmDialog(context, iAmBox);
                              },
                            ),
                          );
                        }
                        
                        if (index == 1) {
                          // "None" option
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.clear, color: Theme.of(context).colorScheme.error),
                              title: Text(
                                t(context, 'no_i_am_selected'),
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                              onTap: () {
                                widget.onIAmChanged?.call(null);
                                Navigator.of(dialogContext).pop();
                              },
                            ),
                          );
                        }

                        final definition = filteredDefinitions[index - 2];
                        final isSelected = widget.selectedIAmId == definition.id;
                        
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
                              widget.onIAmChanged?.call(definition.id);
                              Navigator.of(dialogContext).pop();
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(t(context, 'close')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddIAmDialog(BuildContext context, Box<IAmDefinition> iAmBox) {
    final nameController = TextEditingController();
    final reasonController = TextEditingController();
    final iAmService = IAmService();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(context, 'add_i_am')),
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t(context, 'i_am_name_required'))),
                );
                return;
              }

              final newId = iAmService.generateId();
              final newDefinition = IAmDefinition(
                id: newId,
                name: name,
                reasonToExist: reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim(),
              );

              await iAmService.addDefinition(iAmBox, newDefinition);
              
              // Auto-select the newly created I Am
              widget.onIAmChanged?.call(newId);
              
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(t(context, 'save_changes')),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context, TextEditingController controller, String key, {bool showTooltip = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 5,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          labelText: t(context, key),
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
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
