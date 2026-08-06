import 'package:hive/hive.dart';

part 'barrier_power_pair.g.dart';

/// Represents a Barrier/Power pair for the agnosticism exercise.
///
/// Uses typeId **8** only (previously `PaperStatus`); the old `AgnosticismPaper`
/// structure is completely replaced. typeId 9 is **not** free — it belongs to
/// `RitualItemType` in morning_ritual.
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

  /// Stored connecting fear; `null` on records written before this field
  /// existed. Read it through [connectedFear], which never returns null — a
  /// non-nullable field here would make the generated adapter throw on those
  /// records, and the corruption fallback would then wipe real user data.
  @HiveField(7)
  String? storedConnectedFear;

  /// The fear or reason connecting the barrier to the power.
  ///
  /// Added after the first release, so pairs written by earlier versions and
  /// by the Emotional Sobriety application may carry an empty value. An empty
  /// fear means "not recorded yet"; the pair stays valid and is never
  /// discarded. The form asks for it whenever a pair is written or edited.
  String get connectedFear => storedConnectedFear ?? '';

  set connectedFear(String value) => storedConnectedFear = value;

  BarrierPowerPair({
    required this.id,
    required this.barrier,
    required this.power,
    this.isArchived = false,
    required this.createdAt,
    this.archivedAt,
    this.position = 0,
    String connectedFear = '',
  }) : storedConnectedFear = connectedFear;

  /// Convert to JSON for sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barrier': barrier,
      'power': power,
      'isArchived': isArchived,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'archivedAt': archivedAt?.toUtc().toIso8601String(),
      'position': position,
      'connectedFear': connectedFear,
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
      connectedFear: json['connectedFear'] as String? ?? '',
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
    String? connectedFear,
  }) {
    return BarrierPowerPair(
      id: id ?? this.id,
      barrier: barrier ?? this.barrier,
      power: power ?? this.power,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      position: position ?? this.position,
      connectedFear: connectedFear ?? this.connectedFear,
    );
  }
}
