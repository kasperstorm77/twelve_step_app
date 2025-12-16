import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/person.dart';
import '../services/person_service.dart';
import '../../shared/localizations.dart';

class EighthStepSettingsTab extends StatelessWidget {
  const EighthStepSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Box<Person>>(
        valueListenable: Hive.box<Person>('people_box').listenable(),
        builder: (context, box, widget) {
          final people = box.values.toList();
          people.sort((a, b) => a.name.compareTo(b.name));

          return ListView.builder(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return PersonListItem(
                person: person,
                onEdit: () => _showEditPersonDialog(context, person),
                onDelete: () => _showDeleteConfirmation(context, person),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PersonEditDialog(
        onSave: (name, amends, column, amendsDone) {
          final newPerson = Person.create(
            name: name,
            amends: amends,
            column: column,
          );
          PersonService.addPerson(newPerson);
        },
      ),
    );
  }

  void _showEditPersonDialog(BuildContext context, Person person) {
    showDialog(
      context: context,
      builder: (context) => PersonEditDialog(
        person: person,
        onSave: (name, amends, column, amendsDone) {
          final updatedPerson = person.copyWith(
            name: name,
            amends: amends,
            column: column,
            amendsDone: amendsDone,
          );
          PersonService.updatePerson(updatedPerson);
        },
      ),
    );
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
            },
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );
  }
}

class PersonListItem extends StatelessWidget {
  final Person person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PersonListItem({
    super.key,
    required this.person,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String columnLabel;
    switch (person.column) {
      case ColumnType.yes:
        columnLabel = t(context, 'eighth_step_yes');
        break;
      case ColumnType.no:
        columnLabel = t(context, 'eighth_step_no');
        break;
      case ColumnType.maybe:
        columnLabel = t(context, 'eighth_step_maybe');
        break;
    }

    return ListTile(
      title: Text(person.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t(context, 'amends')}: ${person.amends}'),
          Text('${t(context, 'column')}: $columnLabel'),
          Text('${t(context, 'amends_done')}: ${person.amendsDone ? t(context, 'eighth_step_yes') : t(context, 'eighth_step_no')}'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class PersonEditDialog extends StatefulWidget {
  final Person? person;
  final Function(String name, String? amends, ColumnType column, bool amendsDone) onSave;
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
      title: Text(widget.person == null ? t(context, 'add_person') : t(context, 'edit_person')),
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
      ),
      actions: [
        if (widget.person != null && widget.onDelete != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteConfirmation(context);
            },
            child: Text(t(context, 'delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
