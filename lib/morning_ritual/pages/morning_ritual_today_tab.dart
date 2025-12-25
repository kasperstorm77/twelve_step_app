import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/ritual_item.dart';
import '../models/morning_ritual_entry.dart';
import '../services/morning_ritual_service.dart';
import '../../shared/localizations.dart';

class MorningRitualTodayTab extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback? onRitualCompleted;
  final ValueChanged<bool>? onRitualStartedChanged;

  const MorningRitualTodayTab({
    super.key,
    required this.selectedDate,
    this.onRitualCompleted,
    this.onRitualStartedChanged,
  });

  @override
  State<MorningRitualTodayTab> createState() => _MorningRitualTodayTabState();
}

class _MorningRitualTodayTabState extends State<MorningRitualTodayTab> {
  // Ritual state
  bool _ritualStarted = false;
  int _currentItemIndex = 0;
  List<RitualItem> _ritualItems = [];
  List<RitualItemRecord> _completedRecords = [];
  DateTime? _ritualStartedAt;

  // Timer state
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timerRunning = false;
  bool _timerPaused = false;

  @override
  void initState() {
    super.initState();
    _loadRitualItems();
    // Listen to ritual items box for changes (e.g., after sync)
    MorningRitualService.ritualItemsBox.listenable().addListener(_onRitualItemsChanged);
  }

  @override
  void didUpdateWidget(MorningRitualTodayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _resetRitual();
      _loadRitualItems();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    FlutterRingtonePlayer().stop();
    // Ensure wake lock is disabled when leaving the page
    WakelockPlus.disable();
    MorningRitualService.ritualItemsBox.listenable().removeListener(_onRitualItemsChanged);
    super.dispose();
  }

  void _onRitualItemsChanged() {
    // Only reload if ritual hasn't started yet (don't interrupt ongoing ritual)
    if (!_ritualStarted && mounted) {
      _loadRitualItems();
    }
  }

  void _loadRitualItems() {
    setState(() {
      _ritualItems = MorningRitualService.getActiveRitualItems();
    });
  }

  void _resetRitual() {
    _timer?.cancel();
    setState(() {
      _ritualStarted = false;
      _currentItemIndex = 0;
      _completedRecords = [];
      _ritualStartedAt = null;
      _remainingSeconds = 0;
      _timerRunning = false;
      _timerPaused = false;
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    return today == selected;
  }

  RitualItem? get _currentItem {
    if (_currentItemIndex < _ritualItems.length) {
      return _ritualItems[_currentItemIndex];
    }
    return null;
  }

  void _startRitual() {
    if (_ritualItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'morning_ritual_no_items_to_start'))),
      );
      return;
    }

    setState(() {
      _ritualStarted = true;
      _ritualStartedAt = DateTime.now();
      _currentItemIndex = 0;
      _completedRecords = [];
    });

    // Notify parent that ritual has started
    widget.onRitualStartedChanged?.call(true);

    _setupCurrentItem();
  }

  void _setupCurrentItem() {
    final item = _currentItem;
    if (item == null) return;

    if (item.type == RitualItemType.timer) {
      setState(() {
        _remainingSeconds = item.durationSeconds ?? 0;
        _timerRunning = false;
        _timerPaused = false;
      });
    }
  }

  void _startTimer() {
    // Enable wake lock to keep screen on during timer
    WakelockPlus.enable();
    
    setState(() {
      _timerRunning = true;
      _timerPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _playAlarm();
        setState(() {
          _timerRunning = false;
        });
        // Disable wake lock when timer completes
        WakelockPlus.disable();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    // Keep wake lock enabled while paused (timer still active)
    setState(() {
      _timerRunning = false;
      _timerPaused = true;
    });
  }

  void _resumeTimer() {
    _startTimer();
  }

  void _stopTimer() {
    _timer?.cancel();
    // Disable wake lock when timer is stopped
    WakelockPlus.disable();
    setState(() {
      _timerRunning = false;
      _timerPaused = false;
    });
  }

  Future<void> _playAlarm() async {
    final item = _currentItem;
    final vibrateEnabled = item?.vibrateEnabled ?? true;
    final soundEnabled = item?.soundEnabled ?? true;

    if (soundEnabled) {
      try {
        // Use flutter_ringtone_player to play the system alarm sound
        // This works reliably on both Android and iOS
        await FlutterRingtonePlayer().play(
          android: AndroidSounds.alarm,
          ios: IosSounds.alarm,
          looping: false,
          volume: 1.0,
          asAlarm: true,  // Uses alarm audio stream for proper volume control
        );
        
        // Stop after 2 seconds (alarm sound can be long)
        Future.delayed(const Duration(seconds: 2), () {
          FlutterRingtonePlayer().stop();
        });
      } catch (e) {
        // Fallback to system sound if ringtone player fails
        debugPrint('FlutterRingtonePlayer failed: $e');
        SystemSound.play(SystemSoundType.alert);
      }
    }

    if (!vibrateEnabled) return;

    // Check if device has vibrator and use strong pattern
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // Vibrate with pattern: vibrate 500ms, pause 200ms, repeat 3 times
      final hasAmplitude = await Vibration.hasAmplitudeControl();
      if (hasAmplitude == true) {
        // Use maximum amplitude for clear feedback
        await Vibration.vibrate(duration: 500, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 500, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 500, amplitude: 255);
      } else {
        // Fallback for devices without amplitude control
        await Vibration.vibrate(duration: 500);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 500);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 500);
      }
    } else {
      // Fallback to haptic feedback if no vibrator
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _completeCurrentItem() async {
    final item = _currentItem;
    if (item == null) return;

    final wasRunningBeforeConfirm = _timerRunning;
    final wasPausedBeforeConfirm = _timerPaused;

    var status = RitualItemStatus.completed;
    if (item.type == RitualItemType.timer && _remainingSeconds > 0) {
      // Pause while asking for confirmation. If the user cancels, resume.
      if (_timerRunning) {
        _pauseTimer();
      } else {
        // Ensure we treat this as paused while the dialog is open.
        setState(() {
          _timerPaused = true;
          _timerRunning = false;
        });
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t(context, 'morning_ritual_timer_early_complete_title')),
          content: Text(t(context, 'morning_ritual_timer_early_complete_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t(context, 'no')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(t(context, 'yes')),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        // Resume exactly where we left off.
        if (!mounted) return;
        if (wasRunningBeforeConfirm) {
          _resumeTimer();
        } else {
          // Restore prior paused/not-started state.
          setState(() {
            _timerPaused = wasPausedBeforeConfirm;
            _timerRunning = false;
          });
        }
        return;
      }

      status = RitualItemStatus.skipped;
    }

    _timer?.cancel();

    final record = RitualItemRecord(
      ritualItemId: item.id,
      ritualItemName: item.name,
      status: status,
      actualDurationSeconds: item.type == RitualItemType.timer
          ? (item.durationSeconds ?? 0) - _remainingSeconds
          : null,
      originalDurationSeconds: item.type == RitualItemType.timer
          ? item.durationSeconds
          : null,
    );

    setState(() {
      _completedRecords.add(record);
      _currentItemIndex++;
      _timerRunning = false;
      _timerPaused = false;
      _remainingSeconds = 0;
    });

    if (_currentItemIndex >= _ritualItems.length) {
      _finishRitual();
    } else {
      _setupCurrentItem();
    }
  }

  void _skipCurrentItem() {
    final item = _currentItem;
    if (item == null) return;

    _timer?.cancel();

    final record = RitualItemRecord(
      ritualItemId: item.id,
      ritualItemName: item.name,
      status: RitualItemStatus.skipped,
      originalDurationSeconds: item.type == RitualItemType.timer
          ? item.durationSeconds
          : null,
    );

    setState(() {
      _completedRecords.add(record);
      _currentItemIndex++;
      _timerRunning = false;
      _timerPaused = false;
      _remainingSeconds = 0;
    });

    if (_currentItemIndex >= _ritualItems.length) {
      _finishRitual();
    } else {
      _setupCurrentItem();
    }
  }

  void _goToPreviousItem() {
    if (_currentItemIndex <= 0) return;

    _timer?.cancel();

    setState(() {
      // Remove the last completed record (we're going back)
      if (_completedRecords.isNotEmpty) {
        _completedRecords.removeLast();
      }
      _currentItemIndex--;
      _timerRunning = false;
      _timerPaused = false;
      _remainingSeconds = 0;
    });

    _setupCurrentItem();
  }

  Future<void> _startOver() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'morning_ritual_start_over')),
        content: Text(t(context, 'morning_ritual_start_over_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(t(context, 'morning_ritual_start_over')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _timer?.cancel();
      setState(() {
        _currentItemIndex = 0;
        _completedRecords = [];
        _ritualStartedAt = DateTime.now();
        _timerRunning = false;
        _timerPaused = false;
        _remainingSeconds = 0;
      });
      _setupCurrentItem();
    }
  }

  Future<void> _finishRitual() async {
    final entry = MorningRitualEntry(
      date: widget.selectedDate,
      items: _completedRecords,
      startedAt: _ritualStartedAt,
      completedAt: DateTime.now(),
    );

    await MorningRitualService.saveEntry(entry);

    setState(() {
      _ritualStarted = false;
    });

    // Notify parent that ritual has ended
    widget.onRitualStartedChanged?.call(false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'morning_ritual_completed'))),
      );
      widget.onRitualCompleted?.call();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Check if there's already an entry for this date
    final existingEntry = MorningRitualService.getEntryByDate(widget.selectedDate);

    if (existingEntry != null) {
      return _buildCompletedView(existingEntry);
    }

    if (!_isToday) {
      return _buildPastDateView();
    }

    if (!_ritualStarted) {
      return _buildStartView();
    }

    return _buildRitualView();
  }

  Widget _buildStartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              t(context, 'morning_ritual_ready'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'morning_ritual_items_count').replaceAll('%count%', _ritualItems.length.toString()),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _ritualItems.isNotEmpty ? _startRitual : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(t(context, 'morning_ritual_start')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            if (_ritualItems.isEmpty) ...[
              const SizedBox(height: 16),
              Text(
                t(context, 'morning_ritual_add_items_hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRitualView() {
    final item = _currentItem;
    if (item == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: _currentItemIndex / _ritualItems.length,
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentItemIndex + 1} / ${_ritualItems.length}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          // Current item card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    item.type == RitualItemType.timer ? Icons.timer : Icons.menu_book,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  if (item.type == RitualItemType.timer) ...[
                    // Timer display
                    Text(
                      _formatTime(_remainingSeconds),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                    ),
                    const SizedBox(height: 24),
                    // Timer controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_timerRunning && !_timerPaused)
                          ElevatedButton.icon(
                            onPressed: _startTimer,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t(context, 'morning_ritual_timer_start')),
                          )
                        else if (_timerRunning)
                          ElevatedButton.icon(
                            onPressed: _pauseTimer,
                            icon: const Icon(Icons.pause),
                            label: Text(t(context, 'morning_ritual_timer_pause')),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _resumeTimer,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t(context, 'morning_ritual_timer_resume')),
                          ),
                        const SizedBox(width: 8),
                        if (_timerRunning || _timerPaused)
                          OutlinedButton.icon(
                            onPressed: _stopTimer,
                            icon: const Icon(Icons.stop),
                            label: Text(t(context, 'morning_ritual_timer_stop')),
                          ),
                      ],
                    ),
                  ] else ...[
                    // Prayer text
                    if (item.prayerText != null && item.prayerText!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.prayerText!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _skipCurrentItem,
                  icon: const Icon(Icons.skip_next),
                  label: Text(t(context, 'morning_ritual_skip')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _completeCurrentItem(),
                  icon: const Icon(Icons.check),
                  label: Text(t(context, 'morning_ritual_complete')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Previous and Start Over buttons
          Row(
            children: [
              // Previous button (only show if not on first item)
              if (_currentItemIndex > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _goToPreviousItem,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(t(context, 'morning_ritual_previous')),
                  ),
                ),
              if (_currentItemIndex > 0)
                const SizedBox(width: 16),
              // Start Over button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startOver,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(t(context, 'morning_ritual_start_over')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(MorningRitualEntry entry) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: entry.isFullyCompleted
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    entry.isFullyCompleted ? Icons.check_circle : Icons.info,
                    size: 48,
                    color: entry.isFullyCompleted ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.isFullyCompleted
                        ? t(context, 'morning_ritual_fully_completed')
                        : t(context, 'morning_ritual_partially_completed'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.completedCount} ${t(context, 'morning_ritual_completed_label')}, ${entry.skippedCount} ${t(context, 'morning_ritual_skipped_label')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...entry.items.map((record) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    record.status == RitualItemStatus.completed
                        ? Icons.check_circle
                        : record.status == RitualItemStatus.skipped
                            ? Icons.cancel
                            : Icons.remove_circle,
                    color: record.status == RitualItemStatus.completed
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Text(
                    record.originalDurationSeconds != null
                        ? '${record.ritualItemName} (${record.formattedDuration})'
                        : record.ritualItemName,
                  ),
                  subtitle: Text(t(context, record.status.labelKey())),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPastDateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              t(context, 'morning_ritual_no_entry'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
