import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'person.g.dart';

@HiveType(typeId: 4)
enum ColumnType {
  @HiveField(0)
  yes,
  @HiveField(1)
  no,
  @HiveField(2)
  maybe,
}

@HiveType(typeId: 3) // Changed from 1 to avoid conflict with IAmDefinition
class Person extends HiveObject {
  @HiveField(0)
  final String internalId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? amends;

  @HiveField(3)
  ColumnType column;

  @HiveField(4)
  bool amendsDone;

  @HiveField(5)
  DateTime lastModified;

  @HiveField(6)
  int sortOrder;

  Person({
    String? internalId,
    required this.name,
    this.amends,
    required this.column,
    this.amendsDone = false,
    int? sortOrder,
  }) : internalId = internalId ?? const Uuid().v4(),
       sortOrder = sortOrder ?? DateTime.now().millisecondsSinceEpoch,
       lastModified = DateTime.now();

  factory Person.create({
    required String name,
    String? amends,
    required ColumnType column,
  }) {
    return Person(name: name, amends: amends, column: column);
  }

  Person copyWith({
    String? name,
    String? amends,
    ColumnType? column,
    bool? amendsDone,
    int? sortOrder,
  }) {
    return Person(
      internalId: internalId,
      name: name ?? this.name,
      amends: amends ?? this.amends,
      column: column ?? this.column,
      amendsDone: amendsDone ?? this.amendsDone,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static ColumnType columnFromString(String value) {
    switch (value.toLowerCase()) {
      case 'yes':
        return ColumnType.yes;
      case 'no':
        return ColumnType.no;
      case 'maybe':
        return ColumnType.maybe;
      default:
        return ColumnType.yes;
    }
  }

  static String columnToString(ColumnType column) {
    switch (column) {
      case ColumnType.yes:
        return 'yes';
      case ColumnType.no:
        return 'no';
      case ColumnType.maybe:
        return 'maybe';
    }
  }

  // JSON serialization for Drive sync
  Map<String, dynamic> toJson() => {
    'internalId': internalId,
    'name': name,
    'amends': amends,
    'column': columnToString(column),
    'amendsDone': amendsDone,
    'lastModified': lastModified.toIso8601String(),
    'sortOrder': sortOrder,
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      internalId: json['internalId'] as String,
      name: json['name'] as String,
      amends: json['amends'] as String?,
      column: columnFromString(json['column'] as String),
      amendsDone: json['amendsDone'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int?,
    );
  }
}
