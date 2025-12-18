import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import 'data_management_tab.dart';
import '../localizations.dart';
import '../services/app_settings_service.dart';
import '../services/all_apps_drive_service.dart';

class DataManagementPage extends StatelessWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t(context, 'settings_title')),
          bottom: TabBar(
            tabs: [
              Tab(text: t(context, 'data_management')),
              Tab(text: t(context, 'general_settings')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DataManagementTab(box: Hive.box<InventoryEntry>('entries')),
            const GeneralSettingsTab(),
          ],
        ),
      ),
    );
  }
}

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  bool _loadMorningRitualEnabled = false;
  TimeOfDay _morningStartTime = const TimeOfDay(hour: 5, minute: 0);
  TimeOfDay _morningEndTime = const TimeOfDay(hour: 9, minute: 0);
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = AppSettingsService.getMorningRitualSettings();
    setState(() {
      _loadMorningRitualEnabled = settings['enabled'] as bool;
      _morningStartTime = settings['startTime'] as TimeOfDay;
      _morningEndTime = settings['endTime'] as TimeOfDay;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveSettings() async {
    // Validate that start time is before end time
    final startMinutes = _morningStartTime.hour * 60 + _morningStartTime.minute;
    final endMinutes = _morningEndTime.hour * 60 + _morningEndTime.minute;
    
    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'morning_time_error')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await AppSettingsService.saveMorningRitualSettings(
      enabled: _loadMorningRitualEnabled,
      startTime: _morningStartTime,
      endTime: _morningEndTime,
    );

    // Trigger Drive sync if enabled
    if (AllAppsDriveService.instance.isAuthenticated) {
      AllAppsDriveService.instance.scheduleUploadFromBox();
    }

    setState(() {
      _hasUnsavedChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'settings_saved'))),
      );
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final initialTime = isStartTime ? _morningStartTime : _morningEndTime;
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _morningStartTime = picked;
        } else {
          _morningEndTime = picked;
        }
        _hasUnsavedChanges = true;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Morning Ritual Auto-Load Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'morning_ritual_settings'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Toggle
                  SwitchListTile(
                    title: Text(t(context, 'load_morning_ritual_toggle')),
                    value: _loadMorningRitualEnabled,
                    onChanged: (value) {
                      setState(() {
                        _loadMorningRitualEnabled = value;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                  
                  const Divider(),
                  
                  // Start Time
                  ListTile(
                    title: Text(t(context, 'morning_start_time')),
                    subtitle: Text(_formatTime(_morningStartTime)),
                    trailing: const Icon(Icons.access_time),
                    enabled: _loadMorningRitualEnabled,
                    onTap: _loadMorningRitualEnabled 
                        ? () => _selectTime(true) 
                        : null,
                  ),
                  
                  // End Time
                  ListTile(
                    title: Text(t(context, 'morning_end_time')),
                    subtitle: Text(_formatTime(_morningEndTime)),
                    trailing: const Icon(Icons.access_time),
                    enabled: _loadMorningRitualEnabled,
                    onTap: _loadMorningRitualEnabled 
                        ? () => _selectTime(false) 
                        : null,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _hasUnsavedChanges ? _saveSettings : null,
              icon: const Icon(Icons.save),
              label: Text(t(context, 'save_settings')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          if (_hasUnsavedChanges) ...[
            const SizedBox(height: 8),
            Text(
              t(context, 'unsaved_changes'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
