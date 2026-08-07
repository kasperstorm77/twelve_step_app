import 'package:flutter/material.dart';
import '../models/person.dart';
import '../../shared/localizations.dart';

/// Add/edit dialog for a [Person] on the 8th Step board.
///
/// This used to live in `eighth_step_settings_tab.dart` alongside a list UI
/// that was never routed; `EighthStepHome` imported that whole file just to
/// reach this dialog. The list view is gone (historic Phase 21) and the dialog now
/// stands on its own.
class PersonEditDialog extends StatefulWidget {
  final Person? person;
  final Function(
    String name,
    String? amends,
    ColumnType column,
    bool amendsDone,
  )
  onSave;
  final VoidCallback? onDelete;

  const PersonEditDialog({
    super.key,
    this.person,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<PersonEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String? _amends;
  late ColumnType _column;
  late bool _amendsDone;

  @override
  void initState() {
    super.initState();
    _name = widget.person?.name ?? '';
    _amends = widget.person?.amends ?? '';
    _column = widget.person?.column ?? ColumnType.yes;
    _amendsDone = widget.person?.amendsDone ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.person == null
            ? t(context, 'add_person')
            : t(context, 'edit_person'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(
                    labelText: t(context, 'person_name'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t(context, 'person_name_required');
                    }
                    return null;
                  },
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _amends,
                  decoration: InputDecoration(
                    labelText: t(context, 'amends_needed'),
                    hintText: t(context, 'optional'),
                    border: const OutlineInputBorder(),
                  ),
                  onSaved: (value) => _amends = value,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ColumnType>(
                  initialValue: _column,
                  decoration: InputDecoration(
                    labelText: t(context, 'column'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ColumnType.values.map((column) {
                    String label;
                    switch (column) {
                      case ColumnType.yes:
                        label = t(context, 'eighth_step_yes');
                        break;
                      case ColumnType.no:
                        label = t(context, 'eighth_step_no');
                        break;
                      case ColumnType.maybe:
                        label = t(context, 'eighth_step_maybe');
                        break;
                    }
                    return DropdownMenuItem<ColumnType>(
                      value: column,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _column = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  t(context, 'amends_done_question'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ChoiceChip(
                      label: Text(t(context, 'eighth_step_yes')),
                      selected: _amendsDone,
                      onSelected: (selected) {
                        setState(() {
                          _amendsDone = true;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(t(context, 'eighth_step_no')),
                      selected: !_amendsDone,
                      onSelected: (selected) {
                        setState(() {
                          _amendsDone = false;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.person != null && widget.onDelete != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteConfirmation(context);
            },
            child: Text(
              t(context, 'delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (widget.person != null && widget.onDelete != null)
          const SizedBox(width: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(context, 'cancel')),
        ),
        TextButton(
          onPressed: _saveForm,
          child: Text(t(context, 'save_changes')),
        ),
      ],
    );
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onSave(_name, _amends, _column, _amendsDone);
      Navigator.of(context).pop();
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(context, 'delete_person')),
        content: Text(t(context, 'confirm_delete_person')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete?.call();
              Navigator.of(dialogContext).pop();
            },
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );
  }
}
