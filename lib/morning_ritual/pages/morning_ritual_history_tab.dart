import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/morning_ritual_entry.dart';
import '../services/morning_ritual_service.dart';
import '../../shared/localizations.dart';

class MorningRitualHistoryTab extends StatelessWidget {
  final Function(DateTime)? onDateSelected;

  const MorningRitualHistoryTab({super.key, this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: MorningRitualService.entriesBox.listenable(),
      builder: (context, Box<MorningRitualEntry> box, _) {
        final allEntries = MorningRitualService.getAllEntries();

        if (allEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  t(context, 'morning_ritual_no_history'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'morning_ritual_no_history_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Sort entries by date descending
        final sortedEntries = allEntries.toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 32),
          itemCount: sortedEntries.length,
          itemBuilder: (context, index) {
            final entry = sortedEntries[index];
            return _buildDateCard(context, entry);
          },
        );
      },
    );
  }

  Widget _buildDateCard(BuildContext context, MorningRitualEntry entry) {
    final date = entry.date;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => onDateSelected?.call(date),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Date indicator
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.MMM().format(date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat.d().format(date),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat.y().format(date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat.EEEE().format(date),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: entry.isFullyCompleted
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : entry.completedCount > 0
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    entry.isFullyCompleted
                                        ? Icons.check_circle
                                        : entry.completedCount > 0
                                            ? Icons.info
                                            : Icons.cancel,
                                    size: 14,
                                    color: entry.isFullyCompleted
                                        ? Colors.green
                                        : entry.completedCount > 0
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.completedCount}/${entry.items.length}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: entry.isFullyCompleted
                                          ? Colors.green
                                          : entry.completedCount > 0
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Show first few items
                        ...entry.items.take(2).map((record) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                record.status == RitualItemStatus.completed
                                    ? Icons.check
                                    : Icons.close,
                                size: 14,
                                color: record.status == RitualItemStatus.completed
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  record.originalDurationSeconds != null
                                      ? '${record.ritualItemName} (${record.formattedDuration})'
                                      : record.ritualItemName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                        if (entry.items.length > 2)
                          Text(
                            '+${entry.items.length - 2} ${t(context, 'more')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            // Delete button in top right corner
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _confirmDeleteEntry(context, entry),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.delete,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEntry(BuildContext context, MorningRitualEntry entry) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(context, 'morning_ritual_delete_entry')),
        content: Text(t(context, 'morning_ritual_delete_entry_confirm')
            .replaceAll('{date}', DateFormat.yMMMMd().format(entry.date))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              await MorningRitualService.deleteEntry(entry.id);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t(context, 'morning_ritual_entry_deleted')),
                  duration: const Duration(seconds: 2),
                ),
              );
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
