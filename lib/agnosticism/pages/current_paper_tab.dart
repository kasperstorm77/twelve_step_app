import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/agnosticism_paper.dart';
import '../services/agnosticism_service.dart';
import '../../shared/localizations.dart';
import 'paper_detail_page.dart';

class CurrentPaperTab extends StatefulWidget {
  const CurrentPaperTab({super.key});

  @override
  State<CurrentPaperTab> createState() => _CurrentPaperTabState();
}

class _CurrentPaperTabState extends State<CurrentPaperTab> {
  final AgnosticismService _service = AgnosticismService();
  final TextEditingController _controller = TextEditingController();
  
  // Track which side we're on: true = Side A (Barriers), false = Side B (Attributes)
  bool _isSideA = true;
  bool _showingPeek = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addItem(Box<AgnosticismPaper> box, AgnosticismPaper paper) async {
    if (_controller.text.trim().isEmpty) return;

    if (_isSideA) {
      await _service.addBarrier(box, paper.id, _controller.text.trim());
    } else {
      await _service.addAttribute(box, paper.id, _controller.text.trim());
    }

    _controller.clear();
  }

  Future<void> _removeItem(Box<AgnosticismPaper> box, AgnosticismPaper paper, int index) async {
    if (_isSideA) {
      await _service.removeBarrier(box, paper.id, index);
    } else {
      await _service.removeAttribute(box, paper.id, index);
    }
  }

  void _turnPage() {
    setState(() {
      _isSideA = false;
    });
  }

  Future<void> _finalizePaper(Box<AgnosticismPaper> box, AgnosticismPaper paper) async {
    await _service.finalizePaper(box, paper.id);
    setState(() {
      _isSideA = true; // Reset for next paper
    });
  }

  void _startNewPaper(Box<AgnosticismPaper> box) {
    setState(() {
      _isSideA = true;
    });
    // The service will create a new paper automatically
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AgnosticismPaper>('agnosticism_papers').listenable(),
      builder: (context, Box<AgnosticismPaper> box, _) {
        final paper = _service.getOrCreateActivePaper(box);
        
        // Check if paper has been finalized (contemplation state)
        if (paper.isArchived) {
          return _buildContemplationState(box, paper);
        }

        // Show Side A or Side B based on state
        return _isSideA
            ? _buildSideA(box, paper)
            : _buildSideB(box, paper);
      },
    );
  }

  Widget _buildSideA(Box<AgnosticismPaper> box, AgnosticismPaper paper) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Column(
            children: [
              Text(
                t(context, 'agnosticism_side_a_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                t(context, 'agnosticism_side_a_subtitle'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),

        // List of barriers
        Expanded(
          child: paper.sideA.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      t(context, 'agnosticism_side_a_empty'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: paper.sideA.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text(paper.sideA[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeItem(box, paper, index),
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Input footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: t(context, 'agnosticism_add_barrier_hint'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => _addItem(box, paper),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _addItem(box, paper),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: paper.sideA.isNotEmpty ? _turnPage : null,
                    icon: const Icon(Icons.flip),
                    label: Text(t(context, 'agnosticism_turn_page')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideB(Box<AgnosticismPaper> box, AgnosticismPaper paper) {
    return Column(
      children: [
        // Header with peek button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'agnosticism_side_b_title'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(context, 'agnosticism_side_b_subtitle'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onLongPressStart: (_) => setState(() => _showingPeek = true),
                    onLongPressEnd: (_) => setState(() => _showingPeek = false),
                    child: Tooltip(
                      message: t(context, 'agnosticism_peek_tooltip'),
                      child: Icon(
                        _showingPeek ? Icons.visibility : Icons.visibility_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Show peek overlay if active
        if (_showingPeek)
          Expanded(
            child: Container(
              color: Colors.black.withValues(alpha: 0.9),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'agnosticism_side_a_title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: paper.sideA.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• ${paper.sideA[index]}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // List of attributes
          Expanded(
            child: paper.sideB.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        t(context, 'agnosticism_side_b_empty'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: paper.sideB.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.star, color: Colors.amber),
                          title: Text(paper.sideB[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeItem(box, paper, index),
                            color: Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),

        // Input footer
        if (!_showingPeek)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: t(context, 'agnosticism_add_attribute_hint'),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () => _addItem(box, paper),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addItem(box, paper),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: paper.sideB.isNotEmpty
                          ? () => _finalizePaper(box, paper)
                          : null,
                      icon: const Icon(Icons.check_circle),
                      label: Text(t(context, 'agnosticism_finalize')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContemplationState(Box<AgnosticismPaper> box, AgnosticismPaper paper) {
    // This shouldn't happen as finalized papers should trigger new paper creation
    // But show it anyway for safety
    return PaperDetailPage(
      paper: paper,
      onClose: () => _startNewPaper(box),
      showNewPaperButton: true,
    );
  }
}
