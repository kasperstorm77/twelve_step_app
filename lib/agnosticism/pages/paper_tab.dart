import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import '../models/barrier_power_pair.dart';
import '../services/agnosticism_service.dart';
import '../../shared/localizations.dart';
import 'pair_form_page.dart';

/// Controller for programmatically changing the visible paper side.
class PaperTabController {
  VoidCallback? _showFront;
  VoidCallback? _showBack;
  VoidCallback? _showBackInstant;

  void attach({required VoidCallback showFront, required VoidCallback showBack, required VoidCallback showBackInstant}) {
    _showFront = showFront;
    _showBack = showBack;
    _showBackInstant = showBackInstant;
  }

  void detach() {
    _showFront = null;
    _showBack = null;
    _showBackInstant = null;
  }

  void showFront() => _showFront?.call();

  void showBack() => _showBack?.call();

  void showBackInstant() => _showBackInstant?.call();
}

class PaperTab extends StatefulWidget {
  final PaperTabController? controller;
  final VoidCallback? onNavigateToArchive;
  final ValueNotifier<bool>? forceShowBack;

  const PaperTab({super.key, this.controller, this.onNavigateToArchive, this.forceShowBack});

  @override
  State<PaperTab> createState() => _PaperTabState();
}

class _PaperTabState extends State<PaperTab> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late final ScrollController _frontScrollController;
  late final ScrollController _backScrollController;
  bool _showingFront = true;
  double _dragDeltaX = 0;
  double _pendingScrollOffset = 0; // Offset to apply after flip
  bool _hasPendingOffset = false;
  final _service = AgnosticismService();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _frontScrollController = ScrollController();
    _backScrollController = ScrollController();
    
    // Listen for animation to apply pending scroll offset after flip midpoint
    _flipController.addListener(_onFlipAnimationUpdate);
    
    _attachController();
    widget.forceShowBack?.addListener(_onForceShowBack);
  }

  void _onForceShowBack() {
    if (widget.forceShowBack?.value == true) {
      _flipController.value = 1;
      setState(() {
        _showingFront = false;
      });
      widget.forceShowBack?.value = false;
    }
  }

  void _onFlipAnimationUpdate() {
    // When animation crosses midpoint (0.5), the other side becomes visible
    // Apply pending scroll offset after a frame to let the ListView build
    if (_hasPendingOffset) {
      final value = _flipController.value;
      final targetController = _showingFront ? _frontScrollController : _backScrollController;
      
      // Check if we're past midpoint in the right direction
      final pastMidpoint = _showingFront ? value < 0.5 : value > 0.5;
      
      if (pastMidpoint) {
        _hasPendingOffset = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && targetController.hasClients) {
            final maxOffset = targetController.position.maxScrollExtent;
            targetController.jumpTo(_pendingScrollOffset.clamp(0.0, maxOffset));
          }
        });
      }
    }
  }

  @override
  void dispose() {
    widget.forceShowBack?.removeListener(_onForceShowBack);
    widget.controller?.detach();
    _frontScrollController.dispose();
    _backScrollController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaperTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      _attachController();
    }
  }

  void _attachController() {
    widget.controller?.attach(
      showFront: _showFrontSide,
      showBack: _showBackSide,
      showBackInstant: _showBackInstant,
    );
  }

  void _flipPaper() {
    if (_showingFront) {
      _showBackSide();
    } else {
      _showFrontSide();
    }
  }

  void _showFrontSide() {
    if (_showingFront) return;
    // Store scroll position to apply after flip
    if (_backScrollController.hasClients) {
      _pendingScrollOffset = _backScrollController.offset;
      _hasPendingOffset = true;
    }
    _flipController.reverse();
    setState(() {
      _showingFront = true;
    });
  }

  void _showBackSide() {
    if (!_showingFront) return;
    // Store scroll position to apply after flip
    if (_frontScrollController.hasClients) {
      _pendingScrollOffset = _frontScrollController.offset;
      _hasPendingOffset = true;
    }
    _flipController.forward();
    setState(() {
      _showingFront = false;
    });
  }

  void _showBackInstant() {
    _flipController.value = 1;
    if (_showingFront) {
      setState(() {
        _showingFront = false;
      });
    }
  }

  void _openAddForm(Box<BarrierPowerPair> box) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PairFormPage(box: box),
      ),
    );
  }

  void _openEditForm(Box<BarrierPowerPair> box, BarrierPowerPair pair) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PairFormPage(box: box, editingPair: pair),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<BarrierPowerPair>('agnosticism_pairs');

    // Check forceShowBack at the start of build
    if (widget.forceShowBack?.value == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _flipController.value = 1;
          setState(() {
            _showingFront = false;
          });
          widget.forceShowBack?.value = false;
        }
      });
    }

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<BarrierPowerPair> box, _) {
        final activePairs = _service.getActivePairs(box);
        final canAdd = _service.canAddPair(box);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            _dragDeltaX += details.delta.dx;
          },
          onHorizontalDragEnd: (_) => _handleHorizontalSwipe(activePairs.isNotEmpty),
          child: Column(
            children: [
              // Paper title showing which side
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _showingFront 
                      ? t(context, 'agnosticism_barriers_title')
                      : t(context, 'agnosticism_powers_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // The flippable paper
              Expanded(
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value * math.pi;
                    final isFrontVisible = angle < math.pi / 2;
                    
                    // Build the visible side with flip transform
                    final visibleSide = isFrontVisible
                        ? _buildPaperSide(context, box, activePairs, true, _frontScrollController)
                        : _buildPaperSide(context, box, activePairs, false, _backScrollController);
                    
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateY(angle),
                      child: isFrontVisible
                          ? visibleSide
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: visibleSide,
                            ),
                    );
                  },
                ),
              ),

              // Flip button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: activePairs.isNotEmpty ? _flipPaper : null,
                  icon: Icon(_showingFront ? Icons.flip_to_back : Icons.flip_to_front),
                  label: Text(t(context, 'agnosticism_flip')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ),

              // Add button (only when less than 5 pairs)
              if (canAdd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddForm(box),
                    icon: const Icon(Icons.add),
                    label: Text(t(context, 'agnosticism_add_pair')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleHorizontalSwipe(bool hasPairs) {
    const threshold = 40.0;
    final delta = _dragDeltaX;
    _dragDeltaX = 0;

    if (delta < -threshold) {
      // Swipe left: front -> back -> archive
      if (_showingFront && hasPairs) {
        _showBackSide();
      } else if (!_showingFront) {
        widget.onNavigateToArchive?.call();
      }
    } else if (delta > threshold) {
      // Swipe right: archive/back -> back/front
      if (!_showingFront && hasPairs) {
        _showFrontSide();
      }
    }
  }

  Widget _buildPaperSide(BuildContext context, Box<BarrierPowerPair> box, 
      List<BarrierPowerPair> pairs, bool isFront, ScrollController scrollController) {
    if (pairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              t(context, 'agnosticism_empty_paper'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).padding.bottom + 16),
      controller: scrollController,
      itemCount: pairs.length,
      itemBuilder: (context, index) {
        final pair = pairs[index];
        return _buildPairBox(context, box, pair, isFront);
      },
    );
  }

  Widget _buildPairBox(BuildContext context, Box<BarrierPowerPair> box, 
      BarrierPowerPair pair, bool isFront) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 32 - 48; // padding + icon space
        final barrierHeight = _measureTextHeight(pair.barrier, availableWidth, textStyle);
        final powerHeight = _measureTextHeight(pair.power, availableWidth, textStyle);
        final maxContentHeight = math.max(barrierHeight, powerHeight);
        const verticalPadding = 24.0; // symmetric 12 top/bottom

        final backgroundColor = isFront 
            ? colorScheme.errorContainer.withValues(alpha: 0.3)
            : colorScheme.primaryContainer.withValues(alpha: 0.3);
        final borderColor = isFront 
            ? colorScheme.error.withValues(alpha: 0.5)
            : colorScheme.primary.withValues(alpha: 0.5);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxContentHeight + verticalPadding),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      isFront ? pair.barrier : pair.power,
                      style: textStyle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: t(context, 'edit'),
                    onPressed: () => _openEditForm(box, pair),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _measureTextHeight(String text, double maxWidth, TextStyle? style) {
    if (style == null) return 0;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return painter.size.height;
  }
}
