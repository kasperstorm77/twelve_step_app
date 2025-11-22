import 'package:hive/hive.dart';

part 'gratitude_entry.g.dart';

@HiveType(typeId: 7)
class GratitudeEntry extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  late String gratitudeTowards;

  @HiveField(2)
  late DateTime createdAt;

  GratitudeEntry({
    required this.date,
    required this.gratitudeTowards,
    required this.createdAt,
  });

  /// Check if this entry can be edited (only if created today)
  bool get canEdit {
    final now = DateTime.now();
    final entryDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return entryDate.isAtSameMomentAs(today);
  }

  /// Check if this entry can be deleted (only if created today)
  bool get canDelete => canEdit;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'gratitudeTowards': gratitudeTowards,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GratitudeEntry.fromJson(Map<String, dynamic> json) {
    return GratitudeEntry(
      date: DateTime.parse(json['date'] as String),
      gratitudeTowards: json['gratitudeTowards'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
