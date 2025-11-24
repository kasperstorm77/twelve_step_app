import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/person.dart';
import '../services/person_service.dart';
import '../../shared/localizations.dart';

class EighthStepViewPersonTab extends StatefulWidget {
  final String? lastViewedPersonId;
  final VoidCallback onBackToList;
  
  const EighthStepViewPersonTab({
    super.key,
    this.lastViewedPersonId,
    required this.onBackToList,
  });

  @override
  State<EighthStepViewPersonTab> createState() => _EighthStepViewPersonTabState();
}

class _EighthStepViewPersonTabState extends State<EighthStepViewPersonTab> {
  @override
  void didUpdateWidget(EighthStepViewPersonTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No need to track expanded state anymore - we show person directly
  }

  void _showDeleteConfirmation(BuildContext context, Person person) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'delete_person')),
        content: Text(t(context, 'confirm_delete_person')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              PersonService.deletePerson(person.internalId);
              Navigator.of(context).pop();
              // Go back to main tab after deletion
              widget.onBackToList();
            },
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Person>>(
      valueListenable: Hive.box<Person>('people_box').listenable(),
      builder: (context, box, widget) {
        final people = box.values.toList();

        // If a person is selected, show edit view directly
        if (this.widget.lastViewedPersonId != null) {
          final person = people.cast<Person?>().firstWhere(
            (p) => p?.internalId == this.widget.lastViewedPersonId,
            orElse: () => null,
          );
          
          if (person != null) {
            return PersonEditView(
              person: person,
              onBack: this.widget.onBackToList,
              onDelete: () => _showDeleteConfirmation(context, person),
            );
          }
        }

        // If no person selected, show message to select from Main tab
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                t(context, 'select_person_prompt'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PersonEditView extends StatefulWidget {
  final Person person;
  final VoidCallback onBack;
  final VoidCallback onDelete;

  const PersonEditView({
    super.key,
    required this.person,
    required this.onBack,
    required this.onDelete,
  });

  @override
  State<PersonEditView> createState() => _PersonEditViewState();
}

class _PersonEditViewState extends State<PersonEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _amendsController;
  late ColumnType _column;
  late bool _amendsDone;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person.name);
    _amendsController = TextEditingController(text: widget.person.amends ?? '');
    _column = widget.person.column;
    _amendsDone = widget.person.amendsDone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amendsController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final updatedPerson = widget.person.copyWith(
      name: _nameController.text,
      amends: _amendsController.text,
      column: _column,
      amendsDone: _amendsDone,
    );
    PersonService.updatePerson(updatedPerson);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with back button and delete
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Back to list',
              ),
              Expanded(
                child: Text(
                  widget.person.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onDelete,
                tooltip: t(context, 'delete'),
              ),
            ],
          ),
        ),
        // Form content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: t(context, 'person_name')),
                  onChanged: (value) => _saveChanges(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amendsController,
                  decoration: InputDecoration(
                    labelText: t(context, 'amends_needed'),
                    hintText: t(context, 'optional'),
                  ),
                  maxLines: 5,
                  onChanged: (value) => _saveChanges(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ColumnType>(
                  initialValue: _column,
                  decoration: InputDecoration(labelText: t(context, 'column')),
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
                    _saveChanges();
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  t(context, 'amends_done_question'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check,
                              color: _amendsDone ? Colors.white : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(t(context, 'eighth_step_yes')),
                          ],
                        ),
                        selected: _amendsDone,
                        selectedColor: Colors.green,
                        onSelected: (selected) {
                          setState(() {
                            _amendsDone = true;
                          });
                          _saveChanges();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.remove,
                              color: !_amendsDone ? Colors.white : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(t(context, 'eighth_step_no')),
                          ],
                        ),
                        selected: !_amendsDone,
                        selectedColor: Colors.red,
                        onSelected: (selected) {
                          setState(() {
                            _amendsDone = false;
                          });
                          _saveChanges();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PersonEditDialog extends StatefulWidget {
  final Person? person;
  final Function(String name, String? amends, ColumnType column, bool amendsDone) onSave;

  const PersonEditDialog({
    super.key,
    this.person,
    required this.onSave,
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
      title: Text(widget.person == null ? t(context, 'add_person') : t(context, 'edit_person')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(labelText: t(context, 'person_name')),
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
                ),
                onSaved: (value) => _amends = value,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ColumnType>(
                initialValue: _column,
                decoration: InputDecoration(labelText: t(context, 'column')),
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
                style: Theme.of(context).textTheme.titleSmall,
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
      actions: [
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
}
