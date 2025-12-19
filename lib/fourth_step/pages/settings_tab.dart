import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../services/i_am_service.dart';
import '../../shared/localizations.dart';
import '../../shared/utils/platform_helper.dart';
import '../../shared/services/app_settings_service.dart';
import '../../shared/services/all_apps_drive_service.dart';

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
    final theme = Theme.of(context);
    final compactViewEnabled = AppSettingsService.getFourthStepCompactViewEnabled();

    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: iAmBox.listenable(),
        builder: (context, Box<IAmDefinition> box, _) {
          final definitions = box.values.toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _exportCsv(context),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(t(context, 'export_csv')),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t(context, 'fourth_step_compact_view'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t(context, 'fourth_step_compact_view_desc'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: compactViewEnabled,
                          onChanged: (value) async {
                            await AppSettingsService.setFourthStepCompactViewEnabled(value);
                            AllAppsDriveService.instance.scheduleUploadFromBox(widget.box);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(context, box),
                    icon: const Icon(Icons.add),
                    label: Text(t(context, 'add_i_am')),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t(context, 'i_am_definitions'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: definitions.length,
                        itemBuilder: (context, index) {
                          final definition = definitions[index];
                          final theme = Theme.of(context);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t(context, 'i_am_name'),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          definition.name,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        if (definition.reasonToExist != null &&
                                            definition.reasonToExist!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  t(context, 'reason_to_exist_optional'),
                                                  style: TextStyle(
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  definition.reasonToExist!,
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
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
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
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

    // Use the centralized service to check if I Am is in use
    final entriesBox = widget.box;
    final usageCount = _iAmService.getUsageCount(entriesBox, definition.id);

    if (usageCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t(context, 'delete_i_am')),
          content: Text(
            t(context, 'cannot_delete_i_am_in_use')
                .replaceAll('%name%', definition.name)
                .replaceAll('%count%', usageCount.toString()),
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

  /// Escape a value for CSV (handle commas, quotes, newlines)
  String _escapeCsvValue(String? value) {
    if (value == null || value.isEmpty) return '';
    // If value contains comma, quote, or newline, wrap in quotes and escape quotes
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Get category display name
  String _getCategoryName(BuildContext context, InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return t(context, 'category_resentment');
      case InventoryCategory.fear:
        return t(context, 'category_fear');
      case InventoryCategory.harms:
        return t(context, 'category_harms');
      case InventoryCategory.sexualHarms:
        return t(context, 'category_sexual_harms');
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final entries = widget.box.values.toList();
      final iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
      
      if (entries.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(t(context, 'no_entries'))));
        return;
      }

      // Build CSV content
      final buffer = StringBuffer();
      
      // Header row
      buffer.writeln([
        _escapeCsvValue(t(context, 'order')),
        _escapeCsvValue(t(context, 'category')),
        _escapeCsvValue(t(context, 'field1_header')),
        _escapeCsvValue(t(context, 'i_am')),
        _escapeCsvValue(t(context, 'field2_header')),
        _escapeCsvValue(t(context, 'affect_my')),
        _escapeCsvValue(t(context, 'my_take')),
        _escapeCsvValue(t(context, 'shortcomings')),
      ].join(','));

      // Data rows
      for (final entry in entries) {
        final category = entry.effectiveCategory;
        // Get all I Am names, joined with semicolons for CSV compatibility
        final iAmNames = entry.effectiveIAmIds
            .map((id) => _iAmService.getNameById(iAmBox, id))
            .where((name) => name != null)
            .join('; ');
        
        buffer.writeln([
          _escapeCsvValue(entry.order?.toString() ?? ''),
          _escapeCsvValue(_getCategoryName(context, category)),
          _escapeCsvValue(entry.resentment),
          _escapeCsvValue(iAmNames),
          _escapeCsvValue(entry.reason),
          _escapeCsvValue(entry.affect),
          _escapeCsvValue(entry.part),
          _escapeCsvValue(entry.defect),
        ].join(','));
      }

      final csvString = buffer.toString();
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final fileName = 'fourth_step_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      String? savedPath;

      if (PlatformHelper.isMobile) {
        // Mobile: Use flutter_file_dialog
        final params = SaveFileDialogParams(
          data: bytes,
          fileName: fileName,
        );
        savedPath = await FlutterFileDialog.saveFile(params: params);
      } else if (PlatformHelper.isDesktop) {
        // Desktop: Use file_picker
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: t(context, 'export_csv'),
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (savedPath != null) {
          await File(savedPath).writeAsBytes(bytes);
        }
      }

      if (savedPath != null) {
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('${t(context, 'csv_saved')}: $savedPath')));
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${t(context, 'export_failed')}: $e')));
    }
  }
}
