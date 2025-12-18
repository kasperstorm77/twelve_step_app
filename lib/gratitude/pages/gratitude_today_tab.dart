import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/gratitude_entry.dart';
import '../services/gratitude_service.dart';
import '../../shared/localizations.dart';

class GratitudeTodayTab extends StatefulWidget {
  const GratitudeTodayTab({super.key});

  @override
  State<GratitudeTodayTab> createState() => _GratitudeTodayTabState();
}

class _GratitudeTodayTabState extends State<GratitudeTodayTab> {
  final GratitudeService _service = GratitudeService();
  final TextEditingController _towardsController = TextEditingController();
  final TextEditingController _forController = TextEditingController();
  final FocusNode _towardsFocus = FocusNode();
  final FocusNode _forFocus = FocusNode();
  GratitudeEntry? _editingEntry;
  bool _isFormExpanded = false;

  void _expandFormAndFocus(FocusNode focusNode) {
    if (!_isFormExpanded) {
      setState(() {
        _isFormExpanded = true;
      });
    }
    // Request focus after the frame to ensure the widget tree is stable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  void _collapseForm() {
    _towardsFocus.unfocus();
    _forFocus.unfocus();
    setState(() {
      _isFormExpanded = false;
    });
  }

  @override
  void dispose() {
    _towardsFocus.dispose();
    _forFocus.dispose();
    _towardsController.dispose();
    _forController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_towardsController.text.trim().isEmpty || _forController.text.trim().isEmpty) return;

    final box = Hive.box<GratitudeEntry>('gratitude_box');
    
    if (_editingEntry != null) {
      // Update existing entry
      final index = box.values.toList().indexOf(_editingEntry!);
      if (index >= 0) {
        final updatedEntry = GratitudeEntry(
          date: _editingEntry!.date,
          gratitudeTowards: _towardsController.text.trim(),
          createdAt: _editingEntry!.createdAt,
          gratefulFor: _forController.text.trim(),
        );
        await _service.updateEntry(box, index, updatedEntry);
      }
    } else {
      // Create new entry
      final entry = GratitudeEntry(
        date: DateTime.now(),
        gratitudeTowards: _towardsController.text.trim(),
        createdAt: DateTime.now(),
        gratefulFor: _forController.text.trim(),
      );
      await _service.addEntry(box, entry);
    }

    _towardsController.clear();
    _forController.clear();
    _collapseForm();
    setState(() {
      _editingEntry = null;
    });
  }

  void _editEntry(GratitudeEntry entry) {
    if (!entry.canEdit) return;
    
    setState(() {
      _editingEntry = entry;
      _isFormExpanded = true;
      _towardsController.text = entry.gratitudeTowards;
      _forController.text = entry.gratefulFor;
    });
  }

  Future<void> _deleteEntry(GratitudeEntry entry) async {
    if (!entry.canDelete) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(context, 'gratitude_delete_title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
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
        await _service.deleteEntry(box, index);
        if (_editingEntry == entry) {
          setState(() {
            _editingEntry = null;
            _towardsController.clear();
            _forController.clear();
          });
        }
      }
    }
  }

  void _cancelEdit() {
    _collapseForm();
    setState(() {
      _editingEntry = null;
      _towardsController.clear();
      _forController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isEditingExisting = _editingEntry != null;
    final hideExtras = _isFormExpanded;
    
    return Column(
      children: [
        // Date header - hide when form is focused to make room
        if (!hideExtras)
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMMd().format(today),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t(context, 'gratitude_today_subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Input form
        Card(
          margin: EdgeInsets.fromLTRB(8.0, hideExtras ? 8.0 : 0, 8.0, 0),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (isEditingExisting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      t(context, 'gratitude_edit_entry'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                MouseRegion(
                  cursor: SystemMouseCursors.text,
                  child: GestureDetector(
                    onTap: () => _expandFormAndFocus(_towardsFocus),
                    child: AbsorbPointer(
                      absorbing: !_isFormExpanded,
                      child: TextField(
                        controller: _towardsController,
                        focusNode: _towardsFocus,
                        decoration: InputDecoration(
                          labelText: t(context, 'gratitude_towards_label'),
                          hintText: t(context, 'gratitude_towards_hint'),
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.text,
                  child: GestureDetector(
                    onTap: () => _expandFormAndFocus(_forFocus),
                    child: AbsorbPointer(
                      absorbing: !_isFormExpanded,
                      child: TextField(
                        controller: _forController,
                        focusNode: _forFocus,
                        decoration: InputDecoration(
                          labelText: t(context, 'gratitude_for_label'),
                          hintText: t(context, 'gratitude_for_hint'),
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _saveEntry(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_isFormExpanded)
                      TextButton(
                        onPressed: _cancelEdit,
                        child: Text(t(context, 'cancel')),
                      ),
                    ElevatedButton(
                      onPressed: _saveEntry,
                      child: Text(
                        _editingEntry != null
                            ? t(context, 'update')
                            : t(context, 'add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

        // Today's entries list - hide when form is focused to make room
        if (!hideExtras) ...[
          const SizedBox(height: 8),

          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<GratitudeEntry>('gratitude_box').listenable(),
              builder: (context, Box<GratitudeEntry> box, _) {
                final entries = _service.getEntriesForDate(box, today);

                if (entries.isEmpty) {
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
                          t(context, 'gratitude_no_entries_today'),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).padding.bottom + 32),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () => _editEntry(entry),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.favorite, color: Colors.pink),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.gratitudeTowards,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (entry.gratefulFor.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        entry.gratefulFor,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat.jm().format(entry.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteEntry(entry),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
