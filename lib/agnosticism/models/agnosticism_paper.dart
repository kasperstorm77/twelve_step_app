import 'package:hive/hive.dart';

part 'agnosticism_paper.g.dart';

/// Status of the agnosticism paper
@HiveType(typeId: 8)
enum PaperStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  archived,
}

/// Represents a "Piece of Paper" with barriers (Side A) and attributes (Side B)
@HiveType(typeId: 9)
class AgnosticismPaper extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  PaperStatus status;

  @HiveField(2)
  List<String> sideA; // Barriers - "The God of My Misunderstanding"

  @HiveField(3)
  List<String> sideB; // Attributes - "The Power I Need"

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? finalizedAt;

  AgnosticismPaper({
    required this.id,
    required this.status,
    required this.sideA,
    required this.sideB,
    required this.createdAt,
    this.finalizedAt,
  });

  /// Get first attribute from Side B for preview
  String get preview {
    if (sideB.isEmpty) return '';
    return sideB.first;
  }

  /// Check if paper is active
  bool get isActive => status == PaperStatus.active;

  /// Check if paper is archived
  bool get isArchived => status == PaperStatus.archived;

  /// Convert to JSON for sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.name,
      'sideA': sideA,
      'sideB': sideB,
      'createdAt': createdAt.toIso8601String(),
      'finalizedAt': finalizedAt?.toIso8601String(),
    };
  }

  /// Create from JSON for sync
  factory AgnosticismPaper.fromJson(Map<String, dynamic> json) {
    return AgnosticismPaper(
      id: json['id'] as String,
      status: PaperStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaperStatus.active,
      ),
      sideA: (json['sideA'] as List<dynamic>).cast<String>(),
      sideB: (json['sideB'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      finalizedAt: json['finalizedAt'] != null
          ? DateTime.parse(json['finalizedAt'] as String)
          : null,
    );
  }

  /// Create a copy with updated fields
  AgnosticismPaper copyWith({
    String? id,
    PaperStatus? status,
    List<String>? sideA,
    List<String>? sideB,
    DateTime? createdAt,
    DateTime? finalizedAt,
  }) {
    return AgnosticismPaper(
      id: id ?? this.id,
      status: status ?? this.status,
      sideA: sideA ?? List<String>.from(this.sideA),
      sideB: sideB ?? List<String>.from(this.sideB),
      createdAt: createdAt ?? this.createdAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
    );
  }
}
