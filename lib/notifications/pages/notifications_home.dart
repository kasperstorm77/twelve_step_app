import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/localizations.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/pages/data_management_page.dart';
import '../../shared/services/app_help_service.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../shared/services/locale_provider.dart';
import '../services/notifications_service.dart';
import '../models/app_notification.dart';

class _NotificationFormResult {
  final String title;
  final String body;
  final NotificationScheduleType scheduleType;
  final TimeOfDay time;
  final Set<int> weekdays;
  final bool enabled;
  final bool vibrateEnabled;
  final bool soundEnabled;

  const _NotificationFormResult({
    required this.title,
    required this.body,
    required this.scheduleType,
    required this.time,
    required this.weekdays,
    required this.enabled,
    required this.vibrateEnabled,
    required this.soundEnabled,
  });
}

class NotificationsHome extends StatefulWidget {
  const NotificationsHome({super.key});

  @override
  State<NotificationsHome> createState() => _NotificationsHomeState();
}

class _NotificationsHomeState extends State<NotificationsHome> {
  @override
  void initState() {
    super.initState();
    // Ensure box is opened so the page can render existing notifications.
    NotificationsService.openBox();
    // Check and log permission status for debugging
    NotificationsService.checkPermissionStatus();
  }

  void _changeLanguage(String langCode) {
    final localeProvider = Modular.get<LocaleProvider>();
    localeProvider.changeLocale(Locale(langCode));
  }

  void _openDataManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DataManagementPage(),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAppSwitcher() async {
    final apps = AvailableApps.getAll(context);
    final currentAppId = AppSwitcherService.getSelectedAppId();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t(context, 'select_app'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: apps.map((app) {
              final isSelected = app.id == currentAppId;
              return InkWell(
                onTap: () async {
                  if (app.id != currentAppId) {
                    await AppSwitcherService.setSelectedAppId(app.id);
                    if (!mounted) return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app.name,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : null,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t(context, 'close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelp() async {
    AppHelpService.showHelpDialog(context, AvailableApps.notifications);
  }

  Future<void> _createNotification() async {
    final result = await _openNotificationEditor();
    if (result == null) return;

    final timeMinutes = result.time.hour * 60 + result.time.minute;
    final notification = AppNotification(
      notificationId: NotificationsService.generateNotificationId(),
      title: result.title.trim(),
      body: result.body.trim(),
      enabled: result.enabled,
      scheduleType: result.scheduleType,
      timeMinutes: timeMinutes,
      weekdays: result.weekdays.toList()..sort(),
      vibrateEnabled: result.vibrateEnabled,
      soundEnabled: result.soundEnabled,
    );

    await NotificationsService.upsert(notification);
  }

  Future<void> _editNotification(AppNotification existing) async {
    final initialTime = TimeOfDay(
      hour: existing.timeMinutes ~/ 60,
      minute: existing.timeMinutes % 60,
    );

    final result = await _openNotificationEditor(
      initial: _NotificationFormResult(
        title: existing.title,
        body: existing.body,
        scheduleType: existing.scheduleType,
        time: initialTime,
        weekdays: existing.weekdays.toSet(),
        enabled: existing.enabled,
        vibrateEnabled: existing.vibrateEnabled,
        soundEnabled: existing.soundEnabled,
      ),
    );
    if (result == null) return;

    final timeMinutes = result.time.hour * 60 + result.time.minute;
    final updated = existing.copyWith(
      title: result.title.trim(),
      body: result.body.trim(),
      enabled: result.enabled,
      scheduleType: result.scheduleType,
      timeMinutes: timeMinutes,
      weekdays: result.weekdays.toList()..sort(),
      vibrateEnabled: result.vibrateEnabled,
      soundEnabled: result.soundEnabled,
    );

    await NotificationsService.upsert(updated);
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t(context, 'notifications_delete_title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        content: Text(t(context, 'notifications_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              t(context, 'delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await NotificationsService.delete(notification);
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return t(context, 'weekday_mon');
      case DateTime.tuesday:
        return t(context, 'weekday_tue');
      case DateTime.wednesday:
        return t(context, 'weekday_wed');
      case DateTime.thursday:
        return t(context, 'weekday_thu');
      case DateTime.friday:
        return t(context, 'weekday_fri');
      case DateTime.saturday:
        return t(context, 'weekday_sat');
      case DateTime.sunday:
        return t(context, 'weekday_sun');
      default:
        return weekday.toString();
    }
  }

  Future<_NotificationFormResult?> _openNotificationEditor({
    _NotificationFormResult? initial,
  }) async {
    return showDialog<_NotificationFormResult>(
      context: context,
      builder: (dialogContext) {
        return _NotificationEditorDialog(
          initial: initial,
          parentContext: context,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'notifications_title'), style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: t(context, 'switch_app'),
            onPressed: _showAppSwitcher,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: t(context, 'help'),
            onPressed: _showHelp,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: t(context, 'data_management'),
            onPressed: _openDataManagement,
            visualDensity: VisualDensity.compact,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: _changeLanguage,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'en',
                child: Text(t(context, 'lang_english')),
              ),
              PopupMenuItem(
                value: 'da',
                child: Text(t(context, 'lang_danish')),
              ),
            ],
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNotification,
        tooltip: t(context, 'notifications_add'),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: NotificationsService.openBox(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return ValueListenableBuilder(
            valueListenable: NotificationsService.box.listenable(),
            builder: (context, Box<AppNotification> box, _) {
              final items = box.values.toList()
                ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t(context, 'notifications_empty_body'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final n = items[index];
                  final selectedDays = (n.weekdays.toList()..sort())
                      .map((d) => _weekdayLabel(context, d))
                      .join(', ');
                  final hour = n.timeMinutes ~/ 60;
                  final minute = n.timeMinutes % 60;
                  final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                  final scheduleLabel = n.scheduleType == NotificationScheduleType.daily
                      ? t(context, 'notifications_schedule_daily')
                      : t(context, 'notifications_schedule_weekly');
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      onTap: () => _editNotification(n),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  // Body
                                  if (n.body.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body,
                                      style: theme.textTheme.bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  // Schedule: Daily/Weekly · Weekdays · Time
                                  Text(
                                    n.scheduleType == NotificationScheduleType.weekly
                                        ? '$scheduleLabel · $selectedDays · $timeStr'
                                        : '$scheduleLabel · $timeStr',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Switch(
                                  value: n.enabled,
                                  onChanged: (value) async {
                                    await NotificationsService.upsert(
                                      n.copyWith(enabled: value),
                                    );
                                  },
                                ),
                                IconButton(
                                  onPressed: () => _deleteNotification(n),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: theme.colorScheme.error,
                                  ),
                                  tooltip: t(context, 'delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationEditorDialog extends StatefulWidget {
  final _NotificationFormResult? initial;
  final BuildContext parentContext;

  const _NotificationEditorDialog({
    required this.initial,
    required this.parentContext,
  });

  @override
  State<_NotificationEditorDialog> createState() => _NotificationEditorDialogState();
}

class _NotificationEditorDialogState extends State<_NotificationEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late NotificationScheduleType _scheduleType;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late bool _enabled;
  late bool _vibrateEnabled;
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _bodyController = TextEditingController(text: widget.initial?.body ?? '');
    _scheduleType = widget.initial?.scheduleType ?? NotificationScheduleType.daily;
    _time = widget.initial?.time ?? const TimeOfDay(hour: 8, minute: 0);
    _weekdays = widget.initial?.weekdays.toSet() ?? <int>{};
    _enabled = widget.initial?.enabled ?? true;
    _vibrateEnabled = widget.initial?.vibrateEnabled ?? true;
    _soundEnabled = widget.initial?.soundEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool _isValid() {
    if (_titleController.text.trim().isEmpty) return false;
    if (_scheduleType == NotificationScheduleType.weekly && _weekdays.isEmpty) return false;
    return true;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked == null) return;
    setState(() {
      _time = picked;
    });
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return t(widget.parentContext, 'weekday_mon');
      case DateTime.tuesday:
        return t(widget.parentContext, 'weekday_tue');
      case DateTime.wednesday:
        return t(widget.parentContext, 'weekday_wed');
      case DateTime.thursday:
        return t(widget.parentContext, 'weekday_thu');
      case DateTime.friday:
        return t(widget.parentContext, 'weekday_fri');
      case DateTime.saturday:
        return t(widget.parentContext, 'weekday_sat');
      case DateTime.sunday:
        return t(widget.parentContext, 'weekday_sun');
      default:
        return weekday.toString();
    }
  }

  Widget _weekdayToggle(int weekday) {
    final theme = Theme.of(context);
    final selected = _weekdays.contains(weekday);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _weekdays.remove(weekday);
          } else {
            _weekdays.add(weekday);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            _weekdayLabel(weekday),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.initial == null
            ? t(widget.parentContext, 'notifications_add_title')
            : t(widget.parentContext, 'notifications_edit_title'),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t(widget.parentContext, 'notifications_field_title'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: t(widget.parentContext, 'notifications_field_body'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NotificationScheduleType>(
              initialValue: _scheduleType,
              decoration: InputDecoration(
                labelText: t(widget.parentContext, 'notifications_field_schedule'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: NotificationScheduleType.daily,
                  child: Text(t(widget.parentContext, 'notifications_schedule_daily')),
                ),
                DropdownMenuItem(
                  value: NotificationScheduleType.weekly,
                  child: Text(t(widget.parentContext, 'notifications_schedule_weekly')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _scheduleType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text(
                  '${t(widget.parentContext, 'notifications_field_time')}: ${MaterialLocalizations.of(context).formatTimeOfDay(_time, alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_scheduleType == NotificationScheduleType.weekly) ...[
              Text(
                t(widget.parentContext, 'notifications_field_weekdays'),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    for (final day in [DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday, DateTime.saturday, DateTime.sunday])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _weekdayToggle(day),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(widget.parentContext, 'notifications_field_enabled')),
              value: _enabled,
              onChanged: (v) {
                setState(() {
                  _enabled = v;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              t(widget.parentContext, 'notifications_alert_settings'),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(widget.parentContext, 'notifications_field_vibrate')),
              value: _vibrateEnabled,
              onChanged: (v) {
                setState(() {
                  _vibrateEnabled = v;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(widget.parentContext, 'notifications_field_sound')),
              value: _soundEnabled,
              onChanged: (v) {
                setState(() {
                  _soundEnabled = v;
                });
              },
            ),
            if (!_isValid()) ...[
              const SizedBox(height: 8),
              Text(
                _scheduleType == NotificationScheduleType.weekly && _weekdays.isEmpty
                    ? t(widget.parentContext, 'notifications_validation_weekdays')
                    : t(widget.parentContext, 'notifications_validation_title'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(widget.parentContext, 'cancel')),
        ),
        TextButton(
          onPressed: _isValid()
              ? () {
                  Navigator.of(context).pop(
                    _NotificationFormResult(
                      title: _titleController.text,
                      body: _bodyController.text,
                      scheduleType: _scheduleType,
                      time: _time,
                      weekdays: _weekdays,
                      enabled: _enabled,
                      vibrateEnabled: _vibrateEnabled,
                      soundEnabled: _soundEnabled,
                    ),
                  );
                }
              : null,
          child: Text(t(widget.parentContext, 'save')),
        ),
      ],
    );
  }
}
