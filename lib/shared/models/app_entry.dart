import 'package:hive/hive.dart';

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

  static List<AppEntry> getAll() {
    return [
      AppEntry(
        id: fourthStepInventory,
        name: '4th Step Inventory',
        description: 'AA 4th Step Resentment Inventory',
        isActive: true,
      ),
      AppEntry(
        id: eighthStepAmends,
        name: '8th Step Amends',
        description: 'AA 8th Step - List of persons to make amends to',
        isActive: true,
      ),
      AppEntry(
        id: eveningRitual,
        name: 'Evening Ritual',
        description: 'Daily evening reflection and inventory',
        isActive: true,
      ),
      AppEntry(
        id: gratitude,
        name: 'Gratitude',
        description: 'Daily gratitude journal',
        isActive: true,
      ),
    ];
  }

  static AppEntry getDefault() {
    return getAll().first;
  }
}
