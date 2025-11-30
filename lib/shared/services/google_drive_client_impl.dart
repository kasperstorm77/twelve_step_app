// --------------------------------------------------------------------------
// GoogleDriveClient - Handles Google Drive API Calls
// --------------------------------------------------------------------------
// 
// PLATFORM SUPPORT: Android, iOS, Windows, macOS, Linux
// This file depends on google_sign_in for mobile or desktop OAuth for desktop.
// 
// Usage: Import this file directly - it will use the appropriate authentication
// method based on the platform.
// --------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive_api;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;

// --------------------------------------------------------------------------
// Drive Constants
// --------------------------------------------------------------------------
const fileName = 'aa4step_inventory_data.json';
const fileMime = 'application/json';

// AppDataFolder scope
const String driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

// --------------------------------------------------------------------------
// GoogleDriveClient - Handles API Calls
// --------------------------------------------------------------------------

class GoogleDriveClient {
  final drive_api.DriveApi _driveApi;

  GoogleDriveClient._create(this._driveApi);

  static Future<GoogleDriveClient> create(
    GoogleSignInAccount googleAccount,
    String accessToken,
  ) async {
    final authClient = auth.authenticatedClient(
      http.Client(),
      auth.AccessCredentials(
        auth.AccessToken('Bearer', accessToken,
            DateTime.now().toUtc().add(const Duration(minutes: 59))),
        null,
        [driveAppDataScope],
      ),
    );

    final driveApi = drive_api.DriveApi(authClient);
    return GoogleDriveClient._create(driveApi);
  }

  Future<String?> _getFileId() async {
    final result = await _driveApi.files.list(q: "name='$fileName' and trashed=false", spaces: 'appDataFolder');
    final files = result.files;
    if (files != null && files.isNotEmpty) return files.first.id;
    return null;
  }

  Future<String?> _downloadFileContent(String fileId) async {
    final media = await _driveApi.files.get(fileId, downloadOptions: drive_api.DownloadOptions.fullMedia) as drive_api.Media?;
    if (media != null) {
      final bytes = await media.stream.expand((chunk) => chunk).toList();
      return String.fromCharCodes(bytes);
    }
    return null;
  }

  Future<String?> _createOrUpdateFile({required String content}) async {
    final currentFileId = await _getFileId();

    final bytes = content.codeUnits;
    final media = drive_api.Media(Stream.fromIterable([bytes]), bytes.length);

    final fileMetadata = drive_api.File()
      ..name = fileName
      ..mimeType = fileMime;

    if (currentFileId != null) {
      try {
        final updated = await _driveApi.files.update(fileMetadata, currentFileId, uploadMedia: media);
        if (kDebugMode) print("Updated file in AppDataFolder: ${updated.id}");
        return updated.id;
      } catch (e) {
        if (kDebugMode) print('Update failed, will attempt create fallback: $e');
      }
    }

    try {
      // Explicitly place file in appDataFolder
      fileMetadata.parents = ['appDataFolder'];
      final created = await _driveApi.files.create(fileMetadata, uploadMedia: media);
      if (kDebugMode) print("Created file in AppDataFolder: ${created.id}");
      return created.id;
    } catch (e) {
      if (kDebugMode) print('Create in AppDataFolder failed: $e');
      rethrow;
    }
  }

  Future<void> _deleteFileOnGoogleDrive(String fileId) async {
    await _driveApi.files.delete(fileId);
  }

  Future<void> uploadFile(String fileContent) async {
    try {
      await _createOrUpdateFile(content: fileContent);
    } catch (e) {
      if (kDebugMode) print("GoogleDrive uploadFile error: $e");
      rethrow;
    }
  }

  Future<String?> downloadFile() async {
    try {
      final fileId = await _getFileId();
      if (fileId != null) return await _downloadFileContent(fileId);
      if (kDebugMode) print("File not found in AppDataFolder");
      return null;
    } catch (e) {
      if (kDebugMode) print("GoogleDrive downloadFile error: $e");
      rethrow;
    }
  }

  Future<void> deleteFile() async {
    try {
      final fileId = await _getFileId();
      if (fileId != null) {
        await _deleteFileOnGoogleDrive(fileId);
        if (kDebugMode) print("Deleted file from AppDataFolder: $fileId");
      } else {
        if (kDebugMode) print("File not found in AppDataFolder, nothing to delete.");
      }
    } catch (e) {
      if (kDebugMode) print("GoogleDrive deleteFile error: $e");
      rethrow;
    }
  }
}
