import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/barrier_power_pair.dart';
import '../services/agnosticism_service.dart';
import '../../shared/localizations.dart';

class PairFormPage extends StatefulWidget {
  final Box<BarrierPowerPair> box;
  final BarrierPowerPair? editingPair;

  const PairFormPage({
    super.key,
    required this.box,
    this.editingPair,
  });

  @override
  State<PairFormPage> createState() => _PairFormPageState();
}

class _PairFormPageState extends State<PairFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _barrierController = TextEditingController();
  final _powerController = TextEditingController();
  final _service = AgnosticismService();

  bool get isEditing => widget.editingPair != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _barrierController.text = widget.editingPair!.barrier;
      _powerController.text = widget.editingPair!.power;
    }
  }

  @override
  void dispose() {
    _barrierController.dispose();
    _powerController.dispose();
    super.dispose();
  }

  Future<void> _savePair() async {
    if (!_formKey.currentState!.validate()) return;

    final barrier = _barrierController.text.trim();
    final power = _powerController.text.trim();

    if (isEditing) {
      await _service.updatePair(
        widget.box,
        widget.editingPair!.id,
        barrier,
        power,
      );
    } else {
      await _service.addPair(widget.box, barrier, power);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _archivePair() async {
    if (!isEditing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(context, 'agnosticism_archive_title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(t(context, 'agnosticism_archive_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(context, 'agnosticism_archive')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.archivePair(widget.box, widget.editingPair!.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'agnosticism_pair_archived')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing 
            ? t(context, 'agnosticism_edit_pair')
            : t(context, 'agnosticism_add_pair'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: [
            // Barrier field
            Text(
              t(context, 'agnosticism_barrier'),
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _barrierController,
              decoration: InputDecoration(
                hintText: t(context, 'agnosticism_barrier_hint'),
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.block, color: colorScheme.error),
              ),
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'agnosticism_barrier_required');
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Power field
            Text(
              t(context, 'agnosticism_power'),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _powerController,
              decoration: InputDecoration(
                hintText: t(context, 'agnosticism_power_hint'),
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.bolt, color: colorScheme.primary),
              ),
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'agnosticism_power_required');
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            
            // Save button
            FilledButton.icon(
              onPressed: _savePair,
              icon: Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing 
                  ? t(context, 'agnosticism_update')
                  : t(context, 'agnosticism_add'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            // Archive button (only when editing)
            if (isEditing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _archivePair,
                icon: const Icon(Icons.archive),
                label: Text(t(context, 'agnosticism_archive')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
