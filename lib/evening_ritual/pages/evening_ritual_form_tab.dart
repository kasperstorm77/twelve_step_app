import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/reflection_entry.dart';
import '../services/reflection_service.dart';
import '../../shared/localizations.dart';

class EveningRitualFormTab extends StatefulWidget {
  final DateTime selectedDate;

  const EveningRitualFormTab({
    super.key,
    required this.selectedDate,
  });

  @override
  State<EveningRitualFormTab> createState() => _EveningRitualFormTabState();
}

class _EveningRitualFormTabState extends State<EveningRitualFormTab> {
  ReflectionEntry? _editingEntry;
  final _detailController = TextEditingController();
  ReflectionType? _selectedType;
  double _thinkingFocusValue = 0.5;

  @override
  void initState() {
    super.initState();
    _loadThinkingFocus();
  }

  @override
  void didUpdateWidget(EveningRitualFormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadThinkingFocus();
    }
  }

  void _loadThinkingFocus() {
    final entries = ReflectionService.getReflectionsByDate(widget.selectedDate);
    final thinkingEntry = entries.where((e) => e.thinkingFocus != null).firstOrNull;
    
    if (thinkingEntry != null) {
      setState(() {
        _thinkingFocusValue = thinkingEntry.thinkingFocus! / 10.0;
      });
    } else {
      // Reset to default when no saved value exists
      setState(() {
        _thinkingFocusValue = 0.5;
      });
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    return today == selected;
  }

  void _editEntry(ReflectionEntry entry) {
    if (!_isToday) return;
    setState(() {
      _editingEntry = entry;
      _selectedType = entry.type;
      _detailController.text = entry.safeDetail;
      // Don't modify slider value when editing regular reflection entries
    });
  }

  void _resetForm() {
    setState(() {
      _editingEntry = null;
      _selectedType = null;
      _detailController.clear();
      // Don't reset _thinkingFocusValue here - it's independent of reflection entries
    });
  }

  Future<void> _saveEntry() async {
    if (_selectedType == null) return;

    if (_editingEntry != null) {
      // Update existing entry
      _editingEntry!.type = _selectedType!;
      _editingEntry!.detail = _detailController.text.isEmpty ? null : _detailController.text;
      await ReflectionService.updateReflection(_editingEntry!);
    } else {
      // Create new entry
      final entry = ReflectionEntry(
        date: widget.selectedDate,
        type: _selectedType!,
        detail: _detailController.text.isEmpty ? null : _detailController.text,
        thinkingFocus: null,
      );
      await ReflectionService.addReflection(entry);
    }
    
    _resetForm();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'reflection_saved')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteEntry(ReflectionEntry entry) async {
    if (!_isToday) return;
    await ReflectionService.deleteReflection(entry.internalId);
    if (_editingEntry?.internalId == entry.internalId) {
      _resetForm();
    }
  }

  Future<void> _saveThinkingFocus() async {
    final entries = ReflectionService.getReflectionsByDate(widget.selectedDate);
    var thinkingEntry = entries.where((e) => e.thinkingFocus != null).firstOrNull;

    if (thinkingEntry == null) {
      thinkingEntry = ReflectionEntry(
        date: widget.selectedDate,
        type: ReflectionType.godsForgiveness,
        detail: null,
        thinkingFocus: (_thinkingFocusValue * 10).round(),
      );
      await ReflectionService.addReflection(thinkingEntry);
    } else {
      thinkingEntry.thinkingFocus = (_thinkingFocusValue * 10).round();
      await ReflectionService.updateReflection(thinkingEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditable = _isToday;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.yMMMMd().format(widget.selectedDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!isEditable) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.lock,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ],
            ),
          ),
        ),

        if (!isEditable)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(context, 'past_date_read_only'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ValueListenableBuilder(
            valueListenable: ReflectionService.getBox().listenable(),
            builder: (context, Box<ReflectionEntry> box, _) {
              final entries = ReflectionService.getReflectionsByDate(widget.selectedDate);
              final regularEntries = entries.where((e) => e.thinkingFocus == null).toList();

              // Slider value is managed separately in state and loaded via initState/didUpdateWidget
              // This prevents the slider from jumping back when the user is dragging it
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildThinkingSlider(context, isEditable),

                    const SizedBox(height: 16),

                    if (isEditable && _editingEntry == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_selectedType == null)
                                DropdownButtonFormField<ReflectionType>(
                                  initialValue: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: t(context, 'select_reflection_type'),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  isExpanded: true,
                                  selectedItemBuilder: (BuildContext context) {
                                    return ReflectionType.values.map((type) {
                                      return Container(
                                        alignment: Alignment.centerLeft,
                                        constraints: const BoxConstraints(maxWidth: 280),
                                        child: Text(
                                          t(context, type.labelKey()),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList();
                                  },
                                  items: ReflectionType.values.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        t(context, type.labelKey()),
                                        overflow: TextOverflow.visible,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value;
                                    });
                                  },
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _detailController,
                                      decoration: InputDecoration(
                                        labelText: t(context, _selectedType!.labelKey()),
                                        border: const OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                      autofocus: true,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: Icon(_editingEntry != null ? Icons.save : Icons.add),
                                            onPressed: _saveEntry,
                                            label: Text(
                                              _editingEntry != null
                                                  ? t(context, 'save_changes')
                                                  : t(context, 'add_reflection'),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _resetForm,
                                          child: Text(t(context, 'cancel')),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    if (regularEntries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          t(context, 'no_reflections_hint'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...regularEntries.map((entry) {
                        final isEditingThis = _editingEntry?.internalId == entry.internalId;
                        
                        if (isEditingThis) {
                          // Show inline editing mode
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    t(context, entry.type.labelKey()),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _detailController,
                                    decoration: InputDecoration(
                                      labelText: t(context, 'reflection_detail'),
                                      border: const OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                    autofocus: true,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.save),
                                          onPressed: _saveEntry,
                                          label: Text(t(context, 'save_changes')),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: _resetForm,
                                        child: Text(t(context, 'cancel')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        // Show normal view mode
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(t(context, entry.type.labelKey())),
                            subtitle: entry.detail != null && entry.detail!.isNotEmpty
                                ? Text(
                                    entry.detail!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: isEditable
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editEntry(entry),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _confirmDelete(entry),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThinkingSlider(BuildContext context, bool isEditable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(context, 'thinking_focus_question'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'thinking_self'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Slider(
                    value: _thinkingFocusValue,
                    onChanged: isEditable
                        ? (value) {
                            setState(() {
                              _thinkingFocusValue = value;
                            });
                          }
                        : null,
                    onChangeEnd: isEditable
                        ? (value) {
                            _saveThinkingFocus();
                          }
                        : null,
                    divisions: 10,
                    label: _getSliderLabel(_thinkingFocusValue),
                  ),
                ),
                Expanded(
                  child: Text(
                    t(context, 'thinking_others'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            Center(
              child: Text(
                _getSliderLabel(_thinkingFocusValue),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSliderLabel(double value) {
    if (value == 0.0) return t(context, 'slider_completely_self');
    if (value <= 0.2) return t(context, 'slider_mostly_self');
    if (value < 0.5) return t(context, 'slider_leaning_self');
    if (value == 0.5) return t(context, 'slider_balanced');
    if (value < 0.8) return t(context, 'slider_leaning_others');
    if (value < 1.0) return t(context, 'slider_mostly_others');
    return t(context, 'slider_completely_others');
  }

  void _confirmDelete(ReflectionEntry entry) {
    if (!_isToday) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'delete_reflection')),
        content: Text(t(context, 'delete_reflection_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteEntry(entry);
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
