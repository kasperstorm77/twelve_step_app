import 'package:hive/hive.dart';

part 'i_am_definition.g.dart';

@HiveType(typeId: 1)
class IAmDefinition extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? reasonToExist;

  IAmDefinition({required this.id, required this.name, this.reasonToExist});

  // Safe getter for reason to exist
  String get safeReasonToExist => reasonToExist ?? '';
}
