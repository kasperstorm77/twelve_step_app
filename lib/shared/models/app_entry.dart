import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../localizations.dart';

part 'app_entry.g.dart';

/// Represents an available app in the multi-app system
@HiveType(typeId: 2)
class AppEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  bool isActive;

  AppEntry({
    required this.id,
    required this.name,
    required this.description,
    this.isActive = true,
  });

  /// Create a copy with updated fields
  AppEntry copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return AppEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Available apps in the system
class AvailableApps {
  static const String fourthStepInventory = 'fourth_step_inventory';
  static const String eighthStepAmends = 'eighth_step_amends';
  static const String eveningRitual = 'evening_ritual';
  static const String gratitude = 'gratitude';
  static const String agnosticism = 'agnosticism';

  static List<AppEntry> getAll(BuildContext context) {
    return [
      AppEntry(
        id: fourthStepInventory,
        name: t(context, 'app_fourth_step_name'),
        description: t(context, 'app_fourth_step_desc'),
        isActive: true,
      ),
      AppEntry(
        id: eighthStepAmends,
        name: t(context, 'app_eighth_step_name'),
        description: t(context, 'app_eighth_step_desc'),
        isActive: true,
      ),
      AppEntry(
        id: eveningRitual,
        name: t(context, 'app_evening_ritual_name'),
        description: t(context, 'app_evening_ritual_desc'),
        isActive: true,
      ),
      AppEntry(
        id: gratitude,
        name: t(context, 'app_gratitude_name'),
        description: t(context, 'app_gratitude_desc'),
        isActive: true,
      ),
      AppEntry(
        id: agnosticism,
        name: t(context, 'app_agnosticism_name'),
        description: t(context, 'app_agnosticism_desc'),
        isActive: true,
      ),
    ];
  }

  static AppEntry? getDefault(BuildContext? context) {
    if (context == null) {
      // Return non-localized default if no context available
      return AppEntry(
        id: fourthStepInventory,
        name: '4th Step Inventory',
        description: 'AA 4th Step Resentment Inventory',
        isActive: true,
      );
    }
    return getAll(context).first;
  }
}
