import 'package:flutter/material.dart';

import '../localizations.dart';
import '../services/backup_restore_service.dart';

/// Confirmation for importing another product's backup file.
///
/// A foreign import is a full replace of the datasets the file carries and a
/// no-op for everything else, so the dialog names both halves explicitly
/// before anything is written. Shown only on the manual JSON path — the
/// automatic Drive path never accepts a foreign file.
Future<bool> confirmForeignImport(
  BuildContext context,
  ForeignImportSummary summary,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        t(context, 'import_foreign_title'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'import_foreign_message')),
            const SizedBox(height: 12),
            Text(
              t(context, 'import_foreign_replaced'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final entry in summary.sectionCounts.entries)
              Text(
                '• ${t(context, foreignDatasetLabelKey(entry.key))}: '
                '${entry.value}',
              ),
            if (summary.ignoredSections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t(context, 'import_foreign_ignored'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final section in summary.ignoredSections)
                Text('• ${t(context, foreignDatasetLabelKey(section))}'),
            ],
            const SizedBox(height: 12),
            Text(t(context, 'import_foreign_kept')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t(context, 'cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text(t(context, 'import')),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Localization key naming a dataset in the confirmation dialog. Unknown
/// sections fall back to their raw key rather than showing nothing.
String foreignDatasetLabelKey(String sectionKey) => switch (sectionKey) {
  'iAmDefinitions' => 'dataset_i_am_definitions',
  'entries' => 'dataset_entries',
  'agnosticism' => 'dataset_agnosticism',
  'morningRitualItems' => 'dataset_morning_ritual_items',
  'morningRitualEntries' => 'dataset_morning_ritual_entries',
  'workshopProgress' => 'dataset_workshop_progress',
  'morningRitualDraft' => 'dataset_morning_ritual_draft',
  'emotionalSobrietySettings' => 'dataset_emotional_sobriety_settings',
  _ => sectionKey,
};
