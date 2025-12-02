import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ritual_item.dart';
import '../services/morning_ritual_service.dart';
import '../../shared/localizations.dart';

class MorningRitualSettingsTab extends StatefulWidget {
  const MorningRitualSettingsTab({super.key});

  @override
  State<MorningRitualSettingsTab> createState() => MorningRitualSettingsTabState();
}

class MorningRitualSettingsTabState extends State<MorningRitualSettingsTab> {
  /// Public method to show the add item dialog (called from parent via GlobalKey)
  void showAddItemDialog() {
    _showItemDialog();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: MorningRitualService.ritualItemsBox.listenable(),
      builder: (context, Box<RitualItem> box, _) {
        final items = MorningRitualService.getActiveRitualItems();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t(context, 'morning_ritual_settings_desc'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.playlist_add,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t(context, 'morning_ritual_no_items'),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        MediaQuery.of(context).padding.bottom + 80,
                      ),
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) {
                        MorningRitualService.reorderRitualItems(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          key: ValueKey(item.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              item.type == RitualItemType.timer
                                  ? Icons.timer
                                  : Icons.menu_book,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              item.type == RitualItemType.timer
                                  ? '${t(context, 'morning_ritual_type_timer')} - ${item.formattedDuration}'
                                  : t(context, 'morning_ritual_type_prayer'),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showItemDialog(item: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _confirmDelete(item),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
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
    );
  }

  void _showItemDialog({RitualItem? item}) {
    final isEdit = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final prayerTextController = TextEditingController(text: item?.prayerText ?? '');
    final minutesController = TextEditingController(
      text: ((item?.durationSeconds ?? 300) ~/ 60).toString(),
    );
    final secondsController = TextEditingController(
      text: ((item?.durationSeconds ?? 0) % 60).toString().padLeft(2, '0'),
    );
    RitualItemType selectedType = item?.type ?? RitualItemType.timer;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t(context, isEdit ? 'morning_ritual_edit_item' : 'morning_ritual_add_item')),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: t(context, 'morning_ritual_item_name'),
                      hintText: t(context, 'morning_ritual_item_name_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RitualItemType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: t(context, 'morning_ritual_item_type'),
                      border: const OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: RitualItemType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(
                              type == RitualItemType.timer ? Icons.timer : Icons.menu_book,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(t(context, type.labelKey())),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && value != selectedType) {
                        setDialogState(() {
                          selectedType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Timer fields (duration)
                  AnimatedCrossFade(
                    firstChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'morning_ritual_duration'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minutesController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: t(context, 'morning_ritual_minutes'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(':'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: secondsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: t(context, 'morning_ritual_seconds'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    secondChild: TextField(
                      controller: prayerTextController,
                      decoration: InputDecoration(
                        labelText: t(context, 'morning_ritual_prayer_text'),
                        hintText: t(context, 'morning_ritual_prayer_text_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                    crossFadeState: selectedType == RitualItemType.timer
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t(context, 'morning_ritual_name_required'))),
                  );
                  return;
                }

                final durationMinutes = int.tryParse(minutesController.text) ?? 0;
                final durationSeconds = int.tryParse(secondsController.text) ?? 0;
                final totalSeconds = (durationMinutes * 60) + durationSeconds;

                if (isEdit) {
                  final updated = item.copyWith(
                    name: nameController.text.trim(),
                    type: selectedType,
                    durationSeconds: selectedType == RitualItemType.timer ? totalSeconds : null,
                    prayerText: selectedType == RitualItemType.prayer ? prayerTextController.text : null,
                  );
                  await MorningRitualService.updateRitualItem(updated);
                } else {
                  final newItem = RitualItem(
                    name: nameController.text.trim(),
                    type: selectedType,
                    durationSeconds: selectedType == RitualItemType.timer ? totalSeconds : null,
                    prayerText: selectedType == RitualItemType.prayer ? prayerTextController.text : null,
                  );
                  await MorningRitualService.addRitualItem(newItem);
                }

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: Text(t(context, isEdit ? 'update' : 'add')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(RitualItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(context, 'morning_ritual_delete_item')),
        content: Text(t(context, 'morning_ritual_delete_confirm').replaceAll('%name%', item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              await MorningRitualService.deleteRitualItem(item.id);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              t(context, 'delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
