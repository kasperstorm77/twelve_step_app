import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/barrier_power_pair.dart';
import '../services/agnosticism_service.dart';
import '../../shared/localizations.dart';

class ArchiveTab extends StatefulWidget {
  const ArchiveTab({super.key, this.onSwipeToBack});

  final VoidCallback? onSwipeToBack;

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final _service = AgnosticismService();
  double _dragDeltaX = 0;

  void _restorePair(
    BuildContext context,
    Box<BarrierPowerPair> box,
    BarrierPowerPair pair,
  ) async {
    if (!_service.canAddPair(box)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'agnosticism_max_pairs_error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    await _service.restorePair(box, pair.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'agnosticism_pair_restored'))),
    );
  }

  void _deletePair(
    BuildContext context,
    Box<BarrierPowerPair> box,
    BarrierPowerPair pair,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'agnosticism_delete_title')),
        content: Text(t(context, 'agnosticism_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deletePair(box, pair.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'agnosticism_pair_deleted'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<BarrierPowerPair>('agnosticism_pairs');

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        _dragDeltaX += details.delta.dx;
      },
      onHorizontalDragEnd: (_) {
        const threshold = 40.0;
        final delta = _dragDeltaX;
        _dragDeltaX = 0;
        if (delta.abs() > threshold) {
          widget.onSwipeToBack?.call();
        }
      },
      child: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<BarrierPowerPair> box, _) {
          final archivedPairs = _service.getArchivedPairs(box);
          final canRestore = _service.canAddPair(box);

          if (archivedPairs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t(context, 'agnosticism_empty_archive'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: archivedPairs.length,
            itemBuilder: (context, index) {
              final pair = archivedPairs[index];
              return _buildArchivedPairCard(context, box, pair, canRestore);
            },
          );
        },
      ),
    );
  }

  Widget _buildArchivedPairCard(
    BuildContext context,
    Box<BarrierPowerPair> box,
    BarrierPowerPair pair,
    bool canRestore,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final archivedDate = pair.archivedAt != null
        ? '${pair.archivedAt!.day}/${pair.archivedAt!.month}/${pair.archivedAt!.year}'
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Archived date
            Text(
              '${t(context, 'agnosticism_archived_on')}: $archivedDate',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 12),

            // Barrier section
            Text(
              t(context, 'agnosticism_barrier'),
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(pair.barrier, style: Theme.of(context).textTheme.bodyMedium),

            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Power section
                  Text(
                    t(context, 'agnosticism_power'),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    pair.power,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Restore button
                TextButton.icon(
                  onPressed: canRestore
                      ? () => _restorePair(context, box, pair)
                      : null,
                  icon: const Icon(Icons.restore),
                  label: Text(t(context, 'agnosticism_restore')),
                ),
                const SizedBox(width: 8),
                // Delete button
                IconButton(
                  onPressed: () => _deletePair(context, box, pair),
                  icon: const Icon(Icons.delete_forever),
                  color: colorScheme.error,
                  tooltip: t(context, 'delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
