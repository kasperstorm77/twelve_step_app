import 'package:flutter/material.dart';
import '../models/agnosticism_paper.dart';
import '../../shared/localizations.dart';

class PaperDetailPage extends StatelessWidget {
  final AgnosticismPaper paper;
  final VoidCallback onClose;
  final bool showNewPaperButton;

  const PaperDetailPage({
    super.key,
    required this.paper,
    required this.onClose,
    this.showNewPaperButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'agnosticism_contemplation')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ),
      body: Stack(
        children: [
          // Background layer: Side A (strikethrough)
          Positioned.fill(
            child: Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'agnosticism_side_a_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...paper.sideA.map((barrier) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $barrier',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),

          // Foreground layer: Side B (bold and clear)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'agnosticism_side_b_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...paper.sideB.map((attribute) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  attribute,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: showNewPaperButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.add),
                  label: Text(t(context, 'agnosticism_start_new')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
