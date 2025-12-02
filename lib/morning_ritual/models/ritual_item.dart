import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'ritual_item.g.dart';

/// Type of ritual item in the morning ritual definition
@HiveType(typeId: 9)
enum RitualItemType {
  @HiveField(0)
  timer, // Timed meditation/prayer with alarm
  @HiveField(1)
  prayer, // Text-based prayer to read/recite
}

/// A single item in the morning ritual definition (timer or prayer)
@HiveType(typeId: 10)
class RitualItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name; // e.g., "5 minutes meditation", "3rd Step Prayer"

  @HiveField(2)
  RitualItemType type;

  @HiveField(3)
  int? durationSeconds; // For timer type only

  @HiveField(4)
  String? prayerText; // For prayer type only

  @HiveField(5)
  int sortOrder; // Order in the ritual sequence

  @HiveField(6)
  bool isActive; // Whether this item is currently part of the ritual

  @HiveField(7)
  DateTime lastModified;

  RitualItem({
    String? id,
    required this.name,
    required this.type,
    this.durationSeconds,
    this.prayerText,
    this.sortOrder = 0,
    this.isActive = true,
    DateTime? lastModified,
  })  : id = id ?? const Uuid().v4(),
        lastModified = lastModified ?? DateTime.now();

  /// Duration as a Duration object (for timers)
  Duration get duration => Duration(seconds: durationSeconds ?? 0);

  /// Formatted duration string (e.g., "5:00" or "1:30:00")
  String get formattedDuration {
    if (durationSeconds == null) return '';
    final d = Duration(seconds: durationSeconds!);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  RitualItem copyWith({
    String? name,
    RitualItemType? type,
    int? durationSeconds,
    String? prayerText,
    int? sortOrder,
    bool? isActive,
  }) {
    return RitualItem(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      prayerText: prayerText ?? this.prayerText,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      lastModified: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'durationSeconds': durationSeconds,
        'prayerText': prayerText,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'lastModified': lastModified.toIso8601String(),
      };

  factory RitualItem.fromJson(Map<String, dynamic> json) {
    return RitualItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: RitualItemType.values[json['type'] as int],
      durationSeconds: json['durationSeconds'] as int?,
      prayerText: json['prayerText'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
    );
  }
}

extension RitualItemTypeExtension on RitualItemType {
  String labelKey() {
    switch (this) {
      case RitualItemType.timer:
        return 'morning_ritual_type_timer';
      case RitualItemType.prayer:
        return 'morning_ritual_type_prayer';
    }
  }
}
