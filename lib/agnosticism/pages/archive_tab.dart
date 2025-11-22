import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/agnosticism_paper.dart';
import '../services/agnosticism_service.dart';
import '../../shared/localizations.dart';
import 'paper_detail_page.dart';

class ArchiveTab extends StatelessWidget {
  const ArchiveTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AgnosticismPaper>('agnosticism_papers').listenable(),
      builder: (context, Box<AgnosticismPaper> box, _) {
        final service = AgnosticismService();
        final archivedPapers = service.getArchivedPapers(box);

        if (archivedPapers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.archive_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  t(context, 'agnosticism_archive_empty'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    t(context, 'agnosticism_archive_empty_hint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: archivedPapers.length,
          itemBuilder: (context, index) {
            final paper = archivedPapers[index];
            return _buildPaperCard(context, paper);
          },
        );
      },
    );
  }

  Widget _buildPaperCard(BuildContext context, AgnosticismPaper paper) {
    final dateStr = DateFormat.yMMMMd().format(paper.finalizedAt ?? paper.createdAt);
    final preview = paper.preview.isEmpty 
        ? t(context, 'agnosticism_no_attributes')
        : paper.preview;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.description,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          dateStr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaperDetailPage(
                paper: paper,
                onClose: () => Navigator.pop(context),
              ),
            ),
          );
        },
      ),
    );
  }
}
