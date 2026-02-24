import 'package:hive/hive.dart';

part 'barrier_power_pair.g.dart';

/// Represents a Barrier/Power pair for the agnosticism exercise
/// Note: Reusing typeId 8 (previously PaperStatus) and typeId 9 (previously AgnosticismPaper)
/// The old data structure is completely replaced
@HiveType(typeId: 8)
class BarrierPowerPair extends HiveObject {
  /// Unique identifier for this pair
  @HiveField(0)
  String id;

  /// The barrier text (front of the paper)
  @HiveField(1)
  String barrier;

  /// The power text (back of the paper)
  @HiveField(2)
  String power;

  /// Whether this pair is archived
  @HiveField(3)
  bool isArchived;

  /// When this pair was created
  @HiveField(4)
  DateTime createdAt;

  /// When this pair was archived (null if not archived)
  @HiveField(5)
  DateTime? archivedAt;

  /// Position index on the paper (0-4 for active pairs)
  @HiveField(6)
  int position;

  BarrierPowerPair({
    required this.id,
    required this.barrier,
    required this.power,
    this.isArchived = false,
    required this.createdAt,
    this.archivedAt,
    this.position = 0,
  });

  /// Convert to JSON for sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barrier': barrier,
      'power': power,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
      'position': position,
    };
  }

  /// Create from JSON for sync
  factory BarrierPowerPair.fromJson(Map<String, dynamic> json) {
    return BarrierPowerPair(
      id: json['id'] as String,
      barrier: json['barrier'] as String,
      power: json['power'] as String,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'] as String)
          : null,
      position: json['position'] as int? ?? 0,
    );
  }

  /// Create a copy with updated fields
  BarrierPowerPair copyWith({
    String? id,
    String? barrier,
    String? power,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? archivedAt,
    int? position,
  }) {
    return BarrierPowerPair(
      id: id ?? this.id,
      barrier: barrier ?? this.barrier,
      power: power ?? this.power,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      position: position ?? this.position,
    );
  }
}
