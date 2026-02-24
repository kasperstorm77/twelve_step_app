import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'app_notification.g.dart';

@HiveType(typeId: 15)
enum NotificationScheduleType {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
}

@HiveType(typeId: 16)
class AppNotification extends HiveObject {
  @HiveField(0)
  final String id;

  /// Stable integer ID used by the notification plugin.
  @HiveField(1)
  final int notificationId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String body;

  @HiveField(4)
  bool enabled;

  @HiveField(5)
  NotificationScheduleType scheduleType;

  /// Minutes since midnight (local time).
  @HiveField(6)
  int timeMinutes;

  /// Weekdays (1=Mon ... 7=Sun) used when scheduleType == weekly.
  @HiveField(7)
  List<int> weekdays;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime lastModified;

  @HiveField(10)
  bool vibrateEnabled;

  @HiveField(11)
  bool soundEnabled;

  AppNotification({
    String? id,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.enabled,
    required this.scheduleType,
    required this.timeMinutes,
    List<int>? weekdays,
    DateTime? createdAt,
    DateTime? lastModified,
    this.vibrateEnabled = true,
    this.soundEnabled = true,
  })  : id = id ?? const Uuid().v4(),
        weekdays = weekdays ?? <int>[],
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  AppNotification copyWith({
    String? title,
    String? body,
    bool? enabled,
    NotificationScheduleType? scheduleType,
    int? timeMinutes,
    List<int>? weekdays,
    bool? vibrateEnabled,
    bool? soundEnabled,
  }) {
    return AppNotification(
      id: id,
      notificationId: notificationId,
      title: title ?? this.title,
      body: body ?? this.body,
      enabled: enabled ?? this.enabled,
      scheduleType: scheduleType ?? this.scheduleType,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      weekdays: weekdays ?? List<int>.from(this.weekdays),
      createdAt: createdAt,
      lastModified: DateTime.now(),
      vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationId': notificationId,
        'title': title,
        'body': body,
        'enabled': enabled,
        'scheduleType': scheduleType.index,
        'timeMinutes': timeMinutes,
        'weekdays': weekdays,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'vibrateEnabled': vibrateEnabled,
        'soundEnabled': soundEnabled,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String?,
      notificationId: json['notificationId'] as int,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
      scheduleType: NotificationScheduleType.values[(json['scheduleType'] as int?) ?? 0],
      timeMinutes: (json['timeMinutes'] as int?) ?? 8 * 60,
      weekdays: (json['weekdays'] as List?)?.cast<int>() ?? <int>[],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
      vibrateEnabled: (json['vibrateEnabled'] as bool?) ?? true,
      soundEnabled: (json['soundEnabled'] as bool?) ?? true,
    );
  }
}
