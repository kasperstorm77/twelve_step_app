import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelvestepsapp/shared/services/google_drive/drive_crud_client.dart';

// Regression tests for the Drive backup byte-decode path.
//
// Guards data retention: backups are written as UTF-8, but older backups were
// written via String.codeUnits (Latin1 for chars <= 0xFF). decodeBackupBytes
// must read BOTH so no previously-saved backup ever becomes unreadable.
void main() {
  group('GoogleDriveCrudClient.decodeBackupBytes', () {
    test('new UTF-8 backup with em-dash, emoji and Danish letters round-trips', () {
      const content = '{"note":"recovery — day 1 🙏","navn":"Søren æble blå"}';
      final bytes = utf8.encode(content); // how new backups are written
      expect(GoogleDriveCrudClient.decodeBackupBytes(bytes), content);
    });

    test('pure-ASCII legacy backup (codeUnits) round-trips', () {
      const content = '{"a":"plain ascii only"}';
      final bytes = content.codeUnits; // legacy write path
      expect(GoogleDriveCrudClient.decodeBackupBytes(bytes), content);
    });

    test('legacy Latin1 backup with Danish letters is preserved via fallback', () {
      const content = '{"navn":"Søren æble blå"}';
      final bytes = content.codeUnits; // legacy: each <= 0xFF char is one byte
      // Sanity: these isolated high bytes are NOT valid UTF-8, so the strict
      // decode throws and the Latin1 fallback path is what restores the text.
      expect(() => utf8.decode(bytes), throwsFormatException);
      expect(GoogleDriveCrudClient.decodeBackupBytes(bytes), content);
    });
  });
}
