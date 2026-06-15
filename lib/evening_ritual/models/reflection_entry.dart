import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'reflection_entry.g.dart';

@HiveType(typeId: 6)
enum ReflectionType {
  @HiveField(0)
  resentful,
  @HiveField(1)
  selfish,
  @HiveField(2)
  dishonest,
  @HiveField(3)
  afraid,
  @HiveField(4)
  apologyOwed,
  @HiveField(5)
  keptToMyself,
  @HiveField(6)
  kindAndLoving,
  @HiveField(7)
  couldHaveDoneBetter,
  @HiveField(8)
  godsForgiveness,
  @HiveField(9)
  correctiveMeasures,
}

@HiveType(typeId: 5)
class ReflectionEntry extends HiveObject {
  @HiveField(0)
  final String internalId;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  ReflectionType type;

  @HiveField(3)
  String? detail;

  @HiveField(4)
  int? thinkingFocus; // Only used for one special entry per day (0-10 scale)

  @HiveField(5)
  DateTime lastModified;

  ReflectionEntry({
    String? internalId,
    required this.date,
    required this.type,
    this.detail,
    this.thinkingFocus,
  }) : internalId = internalId ?? const Uuid().v4(),
       lastModified = DateTime.now();

  // Safe getters
  String get safeDetail => detail ?? '';

  ReflectionEntry copyWith({
    DateTime? date,
    ReflectionType? type,
    String? detail,
    int? thinkingFocus,
  }) {
    return ReflectionEntry(
      internalId: internalId,
      date: date ?? this.date,
      type: type ?? this.type,
      detail: detail ?? this.detail,
      thinkingFocus: thinkingFocus ?? this.thinkingFocus,
    );
  }

  // JSON serialization for Drive sync
  Map<String, dynamic> toJson() => {
    'internalId': internalId,
    'date': date.toIso8601String().substring(0, 10),
    'type': type.index,
    'detail': detail,
    'thinkingFocus': thinkingFocus,
    'lastModified': lastModified.toIso8601String(),
  };

  factory ReflectionEntry.fromJson(Map<String, dynamic> json) {
    return ReflectionEntry(
      internalId: json['internalId'] as String,
      date: DateTime.parse(json['date'] as String),
      type: ReflectionType.values[json['type'] as int],
      detail: json['detail'] as String?,
      thinkingFocus: json['thinkingFocus'] as int?,
    );
  }
}

extension ReflectionTypeExtension on ReflectionType {
  String labelKey() {
    switch (this) {
      case ReflectionType.resentful:
        return 'reflection_type_resentful';
      case ReflectionType.selfish:
        return 'reflection_type_selfish';
      case ReflectionType.dishonest:
        return 'reflection_type_dishonest';
      case ReflectionType.afraid:
        return 'reflection_type_afraid';
      case ReflectionType.apologyOwed:
        return 'reflection_type_apology_owed';
      case ReflectionType.keptToMyself:
        return 'reflection_type_kept_to_myself';
      case ReflectionType.kindAndLoving:
        return 'reflection_type_kind_loving';
      case ReflectionType.couldHaveDoneBetter:
        return 'reflection_type_could_do_better';
      case ReflectionType.godsForgiveness:
        return 'reflection_type_gods_forgiveness';
      case ReflectionType.correctiveMeasures:
        return 'reflection_type_corrective_measures';
    }
  }
}
