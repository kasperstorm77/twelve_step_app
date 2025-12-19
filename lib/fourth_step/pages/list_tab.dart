import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../../fourth_step/models/i_am_definition.dart';
import '../../fourth_step/services/i_am_service.dart';
import '../../fourth_step/services/inventory_service.dart';
import '../../shared/localizations.dart';
import '../../shared/services/app_settings_service.dart';

class ListTab extends StatefulWidget {
  final Box<InventoryEntry> box;
  final void Function(dynamic key) onEdit;  // Now uses Hive key instead of index
  final void Function(dynamic key)? onDelete;  // Now uses Hive key instead of index
  final bool isProcessing;
  final ScrollController? scrollController;
  final TextEditingController? filterController;  // Filter controller from parent (persistent)

  const ListTab({
    super.key,
    required this.box,
    required this.onEdit,
    this.onDelete,
    this.isProcessing = false,
    this.scrollController,
    this.filterController,
  });

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  late final Box<IAmDefinition> _iAmBox;
  final _iAmService = IAmService();
  final _inventoryService = InventoryService();
  String _filterText = '';

  final Set<String> _expandedEntryIds = {};
  
  // Category filter - all enabled by default
  final Set<InventoryCategory> _selectedCategories = {
    InventoryCategory.resentment,
    InventoryCategory.fear,
    InventoryCategory.harms,
    InventoryCategory.sexualHarms,
  };

  @override
  void initState() {
    super.initState();
    _iAmBox = Hive.box<IAmDefinition>('i_am_definitions');
    // Listen to I Am box changes to rebuild the list
    _iAmBox.listenable().addListener(_onIAmChanged);
    // Listen to filter changes from parent controller
    widget.filterController?.addListener(_onFilterChanged);
    _filterText = widget.filterController?.text ?? '';
  }

  /// Builds a heading + value pair where the heading uses the same blue,
  /// bold styling used for I Am names and the value is on a new line.
  /// Always shows the heading, but only adds spacing when there's data.
  Widget _buildHeadingValue(BuildContext context, String headingKey, String value) {
    final theme = Theme.of(context);
    final hasValue = value.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(top: hasValue ? 4 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, headingKey),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasValue)
            Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _iAmBox.listenable().removeListener(_onIAmChanged);
    widget.filterController?.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) {
      setState(() {
        _filterText = widget.filterController?.text ?? '';
      });
    }
  }

  void _onIAmChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Get all I Am names for display (for multiple I Ams)
  /// Returns list of names, filtering out any not found
  List<String> _getIAmNames(List<String> iAmIds) {
    return iAmIds
        .map((id) => _iAmService.getNameById(_iAmBox, id))
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }

  String _getCompactField1PrefixKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'compact_prefix_resentment';
      case InventoryCategory.fear:
        return 'compact_prefix_fear';
      case InventoryCategory.harms:
        return 'compact_prefix_harms';
      case InventoryCategory.sexualHarms:
        return 'compact_prefix_sexual_harms';
    }
  }

  String _getCompactField2PrefixKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'compact_prefix_cause';
      case InventoryCategory.fear:
        return 'compact_prefix_why';
      case InventoryCategory.harms:
        return 'compact_prefix_what';
      case InventoryCategory.sexualHarms:
        return 'compact_prefix_what';
    }
  }

  /// Get the localization key for field 1 based on category
  String _getField1LabelKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'resentment_field1';
      case InventoryCategory.fear:
        return 'fear_field1';
      case InventoryCategory.harms:
        return 'harms_field1';
      case InventoryCategory.sexualHarms:
        return 'sexual_harms_field1';
    }
  }

  /// Get the localization key for field 2 based on category
  String _getField2LabelKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'resentment_field2';
      case InventoryCategory.fear:
        return 'fear_field2';
      case InventoryCategory.harms:
        return 'harms_field2';
      case InventoryCategory.sexualHarms:
        return 'sexual_harms_field2';
    }
  }

  /// Get the localization key for category name
  String _getCategoryLabelKey(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return 'category_resentment';
      case InventoryCategory.fear:
        return 'category_fear';
      case InventoryCategory.harms:
        return 'category_harms';
      case InventoryCategory.sexualHarms:
        return 'category_sexual_harms';
    }
  }

  /// Get icon for category
  IconData _getCategoryIcon(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.resentment:
        return Icons.sentiment_very_dissatisfied;
      case InventoryCategory.fear:
        return Icons.warning_amber;
      case InventoryCategory.harms:
        return Icons.heart_broken;
      case InventoryCategory.sexualHarms:
        return Icons.privacy_tip;
    }
  }

  Widget _buildCompactLine(
    BuildContext context, {
    required String headingKey,
    required String value,
    required bool faded,
  }) {
    final theme = Theme.of(context);
    final v = value.trim();

    if (v.isEmpty) return const SizedBox.shrink();

    final header = t(context, headingKey).trim();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: faded
                ? _FadedOverflowText(v, style: theme.textTheme.bodyMedium)
                : Text(
                    v,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsBox = Hive.box('settings');

    return Column(
      children: [
        // Filter field (only shown on this tab, but text persists via parent controller)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: widget.filterController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: t(context, 'filter_entries'),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filterText.isNotEmpty
                    ? GestureDetector(
                        onTap: () => widget.filterController?.clear(),
                        child: const Icon(Icons.clear, size: 20),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ),
        // Category filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            height: 40,
            child: Row(
              children: InventoryCategory.values.map((category) {
                final isSelected = _selectedCategories.contains(category);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(category);
                          } else {
                            _selectedCategories.add(category);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(category),
                            size: 20,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // List content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ValueListenableBuilder(
              valueListenable: settingsBox.listenable(),
              builder: (context, _, __) {
                final compactViewEnabled =
                    AppSettingsService.getFourthStepCompactViewEnabled();

                return ValueListenableBuilder(
                  valueListenable: widget.box.listenable(),
                  builder: (context, Box<InventoryEntry> box, _) {
                    // Also listen to I Am box changes for name lookups
                    return ValueListenableBuilder(
                      valueListenable: _iAmBox.listenable(),
                      builder: (context, Box<IAmDefinition> iAmBox, _) {
                        if (box.isEmpty) {
                          return Center(child: Text(t(context, 'no_entries')));
                        }

                        // Get entries sorted by order (highest first)
                        var entries = _inventoryService.getAllEntries();

                        // Apply category filter
                        entries = entries
                            .where((e) =>
                                _selectedCategories.contains(e.effectiveCategory))
                            .toList();

                        // Apply text filter if 2+ characters entered (wildcard on resentment field)
                        if (_filterText.length >= 2) {
                          final filterLower = _filterText.toLowerCase();
                          entries = entries
                              .where((e) =>
                                  e.safeResentment.toLowerCase().contains(filterLower))
                              .toList();
                        }

                        if (entries.isEmpty) {
                          return Center(
                              child: Text(t(context, 'no_matching_entries')));
                        }

                        return ReorderableListView.builder(
                          key: const PageStorageKey<String>('fourth_step_list'),
                          scrollController: widget.scrollController,
                          buildDefaultDragHandles: false,
                          padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).padding.bottom + 16),
                          itemCount: entries.length,
                          onReorder: (oldIndex, newIndex) async {
                            // Adjust newIndex for the removal
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            await _inventoryService.reorderEntries(oldIndex, newIndex);
                          },
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                final elevation = Tween<double>(begin: 0, end: 6)
                                    .evaluate(animation);
                                return Material(
                                  elevation: elevation,
                                  borderRadius: BorderRadius.circular(12),
                                  child: child,
                                );
                              },
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final e = entries[index];
                            final category = e.effectiveCategory;

                            if (!compactViewEnabled) {
                              final iAmNames = _getIAmNames(e.effectiveIAmIds);
                              // Existing layout (default)
                              return Card(
                                key: ValueKey(e.id),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Chip(
                                            avatar: Icon(
                                              _getCategoryIcon(category),
                                              size: 16,
                                            ),
                                            label: Text(
                                              t(context, _getCategoryLabelKey(category)),
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                          const Spacer(),
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Icon(
                                                Icons.drag_handle,
                                                color: theme.colorScheme.outline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      _buildHeadingValue(
                                        context,
                                        _getField1LabelKey(category),
                                        e.safeResentment,
                                      ),
                                      if (iAmNames.isNotEmpty)
                                        ...iAmNames.map(
                                          (name) => Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '${t(context, 'i_am')}: ',
                                                    style: TextStyle(
                                                      color: theme.colorScheme.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: name,
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      _buildHeadingValue(
                                        context,
                                        _getField2LabelKey(category),
                                        e.safeReason,
                                      ),
                                      _buildHeadingValue(
                                          context, 'affects_my', e.safeAffect),
                                      _buildHeadingValue(
                                          context, 'my_part', e.myTake ?? ''),
                                      _buildHeadingValue(
                                        context,
                                        'shortcoming_field',
                                        e.shortcomings ?? '',
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            tooltip: t(context, 'edit_entry'),
                                            onPressed: () => widget.onEdit(e.key),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            tooltip: t(context, 'delete_entry'),
                                            onPressed: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title:
                                                      Text(t(context, 'delete_entry')),
                                                  content: Text(
                                                      t(context, 'delete_confirm')),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(context, false),
                                                      child: Text(t(context, 'cancel')),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(context, true),
                                                      child: Text(
                                                        t(context, 'delete'),
                                                        style: TextStyle(
                                                            color: theme
                                                                .colorScheme.error),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm ?? false) {
                                                await _inventoryService
                                                    .deleteEntryByKey(e.key);
                                                widget.onDelete?.call(e.key);
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          t(context, 'entry_deleted'))),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Compact layout
                            final entryId = e.id;
                            final isExpanded = _expandedEntryIds.contains(entryId);
                            final iAmNames = isExpanded
                              ? _getIAmNames(e.effectiveIAmIds)
                              : const <String>[];
                            final iAmJoined = iAmNames.join(', ');

                            return Card(
                              key: ValueKey(e.id),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _getCategoryIcon(category),
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const Spacer(),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.drag_handle,
                                              color: theme.colorScheme.outline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!isExpanded) ...[
                                      _buildCompactLine(
                                        context,
                                                headingKey: _getCompactField1PrefixKey(category),
                                        value: e.safeResentment,
                                        faded: true,
                                      ),
                                      _buildCompactLine(
                                        context,
                                                headingKey: _getCompactField2PrefixKey(category),
                                        value: e.safeReason,
                                        faded: true,
                                      ),
                                    ] else ...[
                                      _buildHeadingValue(
                                        context,
                                        _getField1LabelKey(category),
                                        e.safeResentment,
                                      ),
                                      _buildHeadingValue(
                                        context,
                                        _getField2LabelKey(category),
                                        e.safeReason,
                                      ),
                                      if (iAmNames.isNotEmpty)
                                        _buildHeadingValue(
                                          context,
                                          'i_am',
                                          iAmJoined,
                                        ),
                                      _buildHeadingValue(
                                        context,
                                        'affects_my',
                                        e.safeAffect,
                                      ),
                                      _buildHeadingValue(
                                        context,
                                        'my_part',
                                        e.myTake ?? '',
                                      ),
                                      _buildHeadingValue(
                                        context,
                                        'shortcoming_field',
                                        e.shortcomings ?? '',
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        // Always show more/less (even if only to remove fade + show full headings)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedEntryIds.remove(entryId);
                                              } else {
                                                _expandedEntryIds.add(entryId);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              isExpanded
                                                  ? t(context, 'show_less')
                                                  : t(context, 'show_more'),
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontStyle: FontStyle.italic,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: t(context, 'edit_entry'),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => widget.onEdit(e.key),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          tooltip: t(context, 'delete_entry'),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: Text(t(context, 'delete_entry')),
                                                content: Text(t(context, 'delete_confirm')),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context, false),
                                                    child: Text(t(context, 'cancel')),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context, true),
                                                    child: Text(
                                                      t(context, 'delete'),
                                                      style: TextStyle(
                                                        color: theme.colorScheme.error,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm ?? false) {
                                              await _inventoryService.deleteEntryByKey(e.key);
                                              widget.onDelete?.call(e.key);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(t(context, 'entry_deleted')),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FadedOverflowText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _FadedOverflowText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    // Fade out the last part of the line (instead of ellipsis) to match the spec.
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          // Start fading earlier to keep the visible portion shorter.
          stops: [0.0, 0.55, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
      ),
    );
  }
}
