import 'package:hive/hive.dart';

part 'inventory_entry.g.dart';

@HiveType(typeId: 0)
class InventoryEntry extends HiveObject {
  @HiveField(0)
  String? resentment;

  @HiveField(1)
  String? reason;

  @HiveField(2)
  String? affect;

  @HiveField(3)
  String? part;  // Now represents "My Take"

  @HiveField(4)
  String? defect;  // Now represents "Shortcomings"

  @HiveField(5)
  String? iAmId;  // Links to IAmDefinition by ID

  InventoryEntry(
    this.resentment,
    this.reason,
    this.affect,
    this.part,
    this.defect, {
    this.iAmId,
  });

  // Safe getters that provide empty strings for null values
  String get safeResentment => resentment ?? '';
  String get safeReason => reason ?? '';
  String get safeAffect => affect ?? '';
  String get safePart => part ?? '';  // "My Take"
  String get safeDefect => defect ?? '';  // "Shortcomings"
  
  // Convenience getters with new names
  String? get myTake => part;
  set myTake(String? value) => part = value;
  
  String? get shortcomings => defect;
  set shortcomings(String? value) => defect = value;

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'resentment': resentment,
    'reason': reason,
    'affect': affect,
    'part': part,
    'defect': defect,
    'iAmId': iAmId,
  };

  factory InventoryEntry.fromJson(Map<String, dynamic> json) {
    return InventoryEntry(
      json['resentment'] as String?,
      json['reason'] as String?,
      json['affect'] as String?,
      json['part'] as String?,
      json['defect'] as String?,
      iAmId: json['iAmId'] as String?,
    );
  }
}
