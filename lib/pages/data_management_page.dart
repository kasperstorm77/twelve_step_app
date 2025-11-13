import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';
import 'data_management_tab.dart';
import '../localizations.dart';

class DataManagementPage extends StatelessWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<InventoryEntry>('entries');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'data_management')),
      ),
      body: DataManagementTab(box: box),
    );
  }
}
