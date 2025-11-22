import 'package:hive_flutter/hive_flutter.dart';
import '../../eighth_step/models/person.dart';
import '../../shared/services/all_apps_drive_service.dart';
import '../../fourth_step/models/inventory_entry.dart';

class PersonService {
  static final Box<Person> _box = Hive.box<Person>('people_box');

  static List<Person> getAllPeople() {
    return _box.values.toList();
  }

  static List<Person> getPeopleByColumn(ColumnType column) {
    return _box.values.where((person) => person.column == column).toList();
  }

  static Future<void> addPerson(Person person) async {
    await _box.put(person.internalId, person);
    _triggerSync();
  }

  static Future<void> updatePerson(Person person) async {
    person.lastModified = DateTime.now();
    await _box.put(person.internalId, person);
    _triggerSync();
  }

  static Future<void> deletePerson(String internalId) async {
    await _box.delete(internalId);
    _triggerSync();
  }

  static Person? getPersonById(String internalId) {
    return _box.get(internalId);
  }

  static Future<void> toggleAmendsDone(String internalId) async {
    final person = _box.get(internalId);
    if (person != null) {
      final updatedPerson = person.copyWith(amendsDone: !person.amendsDone);
      updatedPerson.lastModified = DateTime.now();
      await _box.put(internalId, updatedPerson);
      _triggerSync();
    }
  }

  static Box<Person> getBox() {
    return _box;
  }

  /// Trigger background sync after changes
  static void _triggerSync() {
    try {
      // Trigger sync using the centralized AllAppsDriveService
      final entriesBox = Hive.box<InventoryEntry>('entries');
      AllAppsDriveService.instance.scheduleUploadFromBox(entriesBox);
    } catch (e) {
      // Sync not available or failed, silently continue
    }
  }
}
