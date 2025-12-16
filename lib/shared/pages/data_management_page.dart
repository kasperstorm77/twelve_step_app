import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import 'data_management_tab.dart';
import '../localizations.dart';

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
              Tab(text: t(context, 'general_settings')),
              Tab(text: t(context, 'data_management')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralSettingsTab(context),
            DataManagementTab(box: Hive.box<InventoryEntry>('entries')),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsTab(BuildContext context) {
    return const Center(
      child: Text(''),
    );
  }
}
