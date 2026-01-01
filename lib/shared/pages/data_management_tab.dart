// --------------------------------------------------------------------------
// Data Management Tab - Platform Selector
// --------------------------------------------------------------------------
// 
// This file provides the DataManagementTab widget that automatically selects
// the correct implementation based on the current platform:
// - Mobile (Android/iOS): data_management_tab_mobile.dart
// - Windows: data_management_tab_windows.dart
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../fourth_step/models/inventory_entry.dart';
import '../utils/platform_helper.dart';
import 'data_management_tab_mobile.dart' as mobile;
import 'data_management_tab_windows.dart' as windows;

class DataManagementTab extends StatelessWidget {
  final Box<InventoryEntry> box;

  const DataManagementTab({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    // Use desktop implementation for all desktop platforms (Windows, macOS, Linux)
    // The desktop implementation uses loopback OAuth which works on all desktops
    if (PlatformHelper.isDesktop) {
      return windows.DataManagementTab(box: box);
    } else {
      return mobile.DataManagementTab(box: box);
    }
  }
}
