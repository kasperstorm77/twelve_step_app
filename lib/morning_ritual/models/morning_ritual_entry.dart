import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'morning_ritual_entry.g.dart';

abstract final class RitualItemRecordHiveFields {
  static const selectedContentId = 5;
  static const selectedContentText = 6;
}

abstract final class RitualItemRecordJsonKeys {
  static const selectedContentId = 'selectedContentId';
  static const selectedContentText = 'selectedContentText';
}

/// Status of a ritual item completion
@HiveType(typeId: 11)
enum RitualItemStatus {
  @HiveField(0)
  completed, // Successfully completed (green checkmark)
  @HiveField(1)
  skipped, // Manually skipped (red X)
  @HiveField(2)
  missed, // Ritual not started that day (red X)
}

/// Record of a single ritual item completion for a specific day
@HiveType(typeId: 12)
class RitualItemRecord {
  @HiveField(0)
  final String ritualItemId; // Reference to RitualItem.id

  @HiveField(1)
  final String ritualItemName; // Snapshot of name at completion time

  @HiveField(2)
  final RitualItemStatus status;

  @HiveField(3)
  final int? actualDurationSeconds; // For timers, actual time spent

  @HiveField(4)
  final int? originalDurationSeconds; // For timers, original timer duration

  @HiveField(RitualItemRecordHiveFields.selectedContentId)
  final String? selectedContentId;

  @HiveField(RitualItemRecordHiveFields.selectedContentText)
  final String? selectedContentText;

  RitualItemRecord({
    required this.ritualItemId,
    required this.ritualItemName,
    required this.status,
    this.actualDurationSeconds,
    this.originalDurationSeconds,
    this.selectedContentId,
    this.selectedContentText,
  }) : assert(
         (selectedContentId == null) == (selectedContentText == null),
         'Selected content ID and text must both be present or absent',
       );

  /// Format the original duration as mm:ss
  String get formattedDuration {
    if (originalDurationSeconds == null) return '';
    final minutes = originalDurationSeconds! ~/ 60;
    final seconds = originalDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'ritualItemId': ritualItemId,
    'ritualItemName': ritualItemName,
    'status': status.index,
    'actualDurationSeconds': actualDurationSeconds,
    'originalDurationSeconds': originalDurationSeconds,
    RitualItemRecordJsonKeys.selectedContentId: selectedContentId,
    RitualItemRecordJsonKeys.selectedContentText: selectedContentText,
  };

  factory RitualItemRecord.fromJson(Map<String, dynamic> json) {
    final selectedContentId =
        json[RitualItemRecordJsonKeys.selectedContentId] as String?;
    final selectedContentText =
        json[RitualItemRecordJsonKeys.selectedContentText] as String?;
    if ((selectedContentId == null) != (selectedContentText == null)) {
      throw const FormatException(
        'Selected content ID and text must both be present or absent',
      );
    }
    return RitualItemRecord(
      ritualItemId: json['ritualItemId'] as String,
      ritualItemName: json['ritualItemName'] as String,
      status: RitualItemStatus.values[json['status'] as int],
      actualDurationSeconds: json['actualDurationSeconds'] as int?,
      originalDurationSeconds: json['originalDurationSeconds'] as int?,
      selectedContentId: selectedContentId,
      selectedContentText: selectedContentText,
    );
  }
}

/// A morning ritual entry for a specific date
@HiveType(typeId: 13)
class MorningRitualEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  List<RitualItemRecord> items;

  @HiveField(3)
  DateTime? startedAt; // When the ritual was started

  @HiveField(4)
  DateTime? completedAt; // When the ritual was completed

  @HiveField(5)
  DateTime lastModified;

  MorningRitualEntry({
    String? id,
    required this.date,
    required this.items,
    this.startedAt,
    this.completedAt,
    DateTime? lastModified,
  }) : id = id ?? const Uuid().v4(),
       lastModified = lastModified ?? DateTime.now();

  /// Check if all items were completed successfully
  bool get isFullyCompleted =>
      items.isNotEmpty &&
      items.every((item) => item.status == RitualItemStatus.completed);

  /// Check if the ritual was started (not just missed)
  bool get wasStarted => startedAt != null;

  /// Count of completed items
  int get completedCount =>
      items.where((i) => i.status == RitualItemStatus.completed).length;

  /// Count of skipped items
  int get skippedCount =>
      items.where((i) => i.status == RitualItemStatus.skipped).length;

  /// Count of missed items
  int get missedCount =>
      items.where((i) => i.status == RitualItemStatus.missed).length;

  MorningRitualEntry copyWith({
    DateTime? date,
    List<RitualItemRecord>? items,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return MorningRitualEntry(
      id: id,
      date: date ?? this.date,
      items: items ?? this.items,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastModified: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'items': items.map((i) => i.toJson()).toList(),
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'lastModified': lastModified.toUtc().toIso8601String(),
  };

  factory MorningRitualEntry.fromJson(Map<String, dynamic> json) {
    return MorningRitualEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      items: (json['items'] as List)
          .map((i) => RitualItemRecord.fromJson(i as Map<String, dynamic>))
          .toList(),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
    );
  }
}

extension RitualItemStatusExtension on RitualItemStatus {
  String labelKey() {
    switch (this) {
      case RitualItemStatus.completed:
        return 'morning_ritual_status_completed';
      case RitualItemStatus.skipped:
        return 'morning_ritual_status_skipped';
      case RitualItemStatus.missed:
        return 'morning_ritual_status_missed';
    }
  }
}
