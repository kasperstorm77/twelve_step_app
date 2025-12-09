import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/reflection_entry.dart';
import '../services/reflection_service.dart';
import '../../shared/localizations.dart';

class EveningRitualListTab extends StatefulWidget {
  final Function(DateTime) onDateSelected;

  const EveningRitualListTab({
    super.key,
    required this.onDateSelected,
  });

  @override
  State<EveningRitualListTab> createState() => _EveningRitualListTabState();
}

class _EveningRitualListTabState extends State<EveningRitualListTab> {
  final Set<DateTime> _expandedDates = {};

  String _getSliderLabel(BuildContext context, int value) {
    final normalized = value / 10.0;
    if (normalized == 0.0) return t(context, 'slider_completely_self');
    if (normalized <= 0.2) return t(context, 'slider_mostly_self');
    if (normalized < 0.5) return t(context, 'slider_leaning_self');
    if (normalized == 0.5) return t(context, 'slider_balanced');
    if (normalized < 0.8) return t(context, 'slider_leaning_others');
    if (normalized < 1.0) return t(context, 'slider_mostly_others');
    return t(context, 'slider_completely_others');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ReflectionService.getBox().listenable(),
      builder: (context, Box<ReflectionEntry> box, _) {
        final allEntries = ReflectionService.getAllReflections();
        
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
                  t(context, 'no_reflections'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'no_reflections_hint'),
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
        final Map<DateTime, List<ReflectionEntry>> groupedByDate = {};
        for (final entry in allEntries) {
          final dateOnly = DateTime(entry.date.year, entry.date.month, entry.date.day);
          groupedByDate.putIfAbsent(dateOnly, () => []).add(entry);
        }

        final sortedDates = groupedByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 32),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final date = sortedDates[index];
            final entriesForDate = groupedByDate[date]!;
            final isExpanded = _expandedDates.contains(date);
            return _buildDateCard(context, date, entriesForDate, isExpanded);
          },
        );
      },
    );
  }

  Widget _buildDateCard(BuildContext context, DateTime date, List<ReflectionEntry> entries, bool isExpanded) {
    final regularEntries = entries.where((e) => e.thinkingFocus == null).toList();
    final thinkingEntry = entries.where((e) => e.thinkingFocus != null).firstOrNull;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => widget.onDateSelected(date),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date indicator
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.MMM().format(date),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat.d().format(date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  // Content summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat.EEEE().format(date),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${regularEntries.length}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Show thinking focus first (slider heading + label text only)
                        if (thinkingEntry != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(context, 'thinking_focus_question'),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _getSliderLabel(context, thinkingEntry.thinkingFocus!),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        // Show reflection entries - limited when collapsed
                        if (regularEntries.isNotEmpty) ...[
                          if (isExpanded)
                            // Show all entries when expanded
                            ...regularEntries.map((entry) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t(context, entry.type.labelKey()),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (entry.detail != null && entry.detail!.isNotEmpty)
                                    Text(
                                      entry.detail!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                ],
                              ),
                            ))
                          else
                            // Show limited entries when collapsed (first entry only, 1 line)
                            ...regularEntries.take(1).map((entry) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t(context, entry.type.labelKey()),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (entry.detail != null && entry.detail!.isNotEmpty)
                                    Text(
                                      entry.detail!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            )),
                          // Always show more/less button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedDates.remove(date);
                                } else {
                                  _expandedDates.add(date);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                isExpanded 
                                    ? t(context, 'show_less')
                                    : t(context, 'show_more'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Delete button in top right corner
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _confirmDeleteDay(context, date, entries),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
            // Chevron in bottom right corner
            Positioned(
              bottom: 8,
              right: 8,
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDay(BuildContext context, DateTime date, List<ReflectionEntry> entries) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'delete_day')),
        content: Text(t(context, 'confirm_delete_day')
            .replaceAll('{date}', DateFormat.yMMMMd().format(date))
            .replaceAll('{count}', '${entries.length}')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              // Delete all entries for this day
              for (final entry in entries) {
                await ReflectionService.deleteReflection(entry.internalId);
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t(context, 'day_deleted')),
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
