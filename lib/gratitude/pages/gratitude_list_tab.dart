import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/gratitude_entry.dart';
import '../services/gratitude_service.dart';
import '../../shared/localizations.dart';

class GratitudeListTab extends StatelessWidget {
  final Function(DateTime) onDateSelected;

  const GratitudeListTab({
    super.key,
    required this.onDateSelected,
  });

  Future<void> _deleteEntry(BuildContext context, GratitudeEntry entry) async {
    if (!entry.canDelete) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'gratitude_delete_title')),
        content: Text(t(context, 'gratitude_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final box = Hive.box<GratitudeEntry>('gratitude_box');
      final index = box.values.toList().indexOf(entry);
      if (index >= 0) {
        final service = GratitudeService();
        await service.deleteEntry(box, index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<GratitudeEntry>('gratitude_box').listenable(),
      builder: (context, Box<GratitudeEntry> box, _) {
        final service = GratitudeService();
        final allEntries = service.getAllEntries(box);
        
        if (allEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  t(context, 'gratitude_no_entries'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'gratitude_no_entries_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Group by date
        final groupedByDate = service.getEntriesGroupedByDate(box);
        final sortedDates = groupedByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final date = sortedDates[index];
            final entriesForDate = groupedByDate[date]!;
            return _buildDateCard(context, date, entriesForDate);
          },
        );
      },
    );
  }

  Widget _buildDateCard(BuildContext context, DateTime date, List<GratitudeEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final isToday = dateOnly.isAtSameMomentAs(today);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isToday 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat.MMM().format(date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isToday 
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        DateFormat.d().format(date),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isToday 
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        DateFormat.E().format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday 
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMMd().format(date),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(context, 'gratitude_entries_count').replaceAll('%d', entries.length.toString()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 16),
            
            // Entries for this date
            ...entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, color: Colors.pink, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.gratitudeTowards,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          DateFormat.jm().format(entry.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteEntry(context, entry),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
