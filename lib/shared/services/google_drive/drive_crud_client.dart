import 'dart:async';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive_api;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'drive_config.dart';

// --------------------------------------------------------------------------
// Core Google Drive CRUD Client - Reusable
// --------------------------------------------------------------------------

/// Pure Google Drive CRUD operations client
/// No business logic, just raw Drive API operations
class GoogleDriveCrudClient {
  final drive_api.DriveApi _driveApi;
  final GoogleDriveConfig _config;
  final auth.AuthClient _authClient;

  GoogleDriveCrudClient._(this._driveApi, this._config, this._authClient);

  /// Create a new Google Drive client with authentication
  static Future<GoogleDriveCrudClient> create({
    required String accessToken,
    required GoogleDriveConfig config,
  }) async {
    final authClient = auth.authenticatedClient(
      http.Client(),
      auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          accessToken,
          DateTime.now().toUtc().add(const Duration(minutes: 59)),
        ),
        null,
        [config.scope],
      ),
    );

    final driveApi = drive_api.DriveApi(authClient);
    return GoogleDriveCrudClient._(driveApi, config, authClient);
  }

  /// Find file by name in the configured location
  Future<String?> findFile() async {
    final query = "name='${_config.fileName}' and trashed=false";
    final spaces = _config.parentFolder;
    
    final result = await _driveApi.files.list(
      q: query,
      spaces: spaces,
    );
    
    final files = result.files;
    return (files != null && files.isNotEmpty) ? files.first.id : null;
  }

  /// Read file content by ID
  Future<String?> readFile(String fileId) async {
    final media = await _driveApi.files.get(
      fileId,
      downloadOptions: drive_api.DownloadOptions.fullMedia,
    ) as drive_api.Media?;

    if (media != null) {
      final bytes = await media.stream.expand((chunk) => chunk).toList();
      return String.fromCharCodes(bytes);
    }
    return null;
  }

  /// Read only the first part of a file using an HTTP Range request.
  ///
  /// Useful for extracting small metadata fields from JSON (e.g., `lastModified`)
  /// without downloading the full backup file.
  Future<String?> readFilePrefix(String fileId, {int maxBytes = 8192}) async {
    if (maxBytes <= 0) return '';

    final end = maxBytes - 1;
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
    final response = await _authClient.get(
      uri,
      headers: {
        'Range': 'bytes=0-$end',
      },
    );

    if (response.statusCode == 206 || response.statusCode == 200) {
      // The JSON is ASCII/UTF-8; if we cut mid-codepoint, allow malformed.
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    }

    return null;
  }

  /// Create a new file with content
  Future<String> createFile(String content) async {
    final bytes = content.codeUnits;
    final media = drive_api.Media(Stream.fromIterable([bytes]), bytes.length);

    final fileMetadata = drive_api.File()
      ..name = _config.fileName
      ..mimeType = _config.mimeType;

    // Set parent folder if specified
    if (_config.parentFolder != null) {
      fileMetadata.parents = [_config.parentFolder!];
    }

    final created = await _driveApi.files.create(fileMetadata, uploadMedia: media);
    return created.id!;
  }

  /// Update existing file with new content
  Future<String> updateFile(String fileId, String content) async {
    final bytes = content.codeUnits;
    final media = drive_api.Media(Stream.fromIterable([bytes]), bytes.length);

    final fileMetadata = drive_api.File()
      ..name = _config.fileName
      ..mimeType = _config.mimeType;

    final updated = await _driveApi.files.update(
      fileMetadata,
      fileId,
      uploadMedia: media,
    );
    return updated.id!;
  }

  /// Delete file by ID
  Future<void> deleteFile(String fileId) async {
    await _driveApi.files.delete(fileId);
  }

  /// Create or update file (upsert operation)
  Future<String> upsertFile(String content) async {
    final existingFileId = await findFile();
    
    if (existingFileId != null) {
      try {
        return await updateFile(existingFileId, content);
      } catch (e) {
        // If update fails, try to create new file
        return await createFile(content);
      }
    } else {
      return await createFile(content);
    }
  }

  /// Read file content (find and read in one operation)
  Future<String?> readFileContent() async {
    final fileId = await findFile();
    return fileId != null ? await readFile(fileId) : null;
  }

  /// Delete file by name (find and delete in one operation)
  Future<bool> deleteFileByName() async {
    final fileId = await findFile();
    if (fileId != null) {
      await deleteFile(fileId);
      return true;
    }
    return false;
  }

  /// List all files in the configured location
  Future<List<drive_api.File>> listFiles({String? query}) async {
    final searchQuery = query ?? "trashed=false";
    final spaces = _config.parentFolder;
    
    final result = await _driveApi.files.list(
      q: searchQuery,
      spaces: spaces,
    );
    
    return result.files ?? [];
  }

  /// Check if file exists
  Future<bool> fileExists() async {
    final fileId = await findFile();
    return fileId != null;
  }

  /// Get file metadata
  Future<drive_api.File?> getFileMetadata() async {
    final fileId = await findFile();
    if (fileId != null) {
      return await _driveApi.files.get(fileId) as drive_api.File;
    }
    return null;
  }

  /// Find backup files matching a pattern (e.g., "twelve_steps_backup_*.json")
  Future<List<drive_api.File>> findBackupFiles(String fileNamePattern) async {
    // Extract the base name without extension and wildcard
    final baseName = fileNamePattern.replaceAll('*', '').replaceAll('.json', '');
    
    // Query for files that start with the base name
    final query = "name contains '$baseName' and trashed=false";
    final spaces = _config.parentFolder;
    
    final result = await _driveApi.files.list(
      q: query,
      spaces: spaces,
      orderBy: 'name desc', // Most recent first (by name/date)
      $fields: 'files(id, name, createdTime, modifiedTime)',
    );
    
    return result.files ?? [];
  }

  /// Create a dated backup file with content
  Future<String> createDatedBackupFile(String content, DateTime date) async {
    final bytes = content.codeUnits;
    final media = drive_api.Media(Stream.fromIterable([bytes]), bytes.length);

    // Generate dated filename with timestamp (e.g., twelve_steps_backup_2025-11-23_14-30-15.json)
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}-${date.second.toString().padLeft(2, '0')}';
    final baseName = _config.fileName.replaceAll('.json', '');
    final datedFileName = '${baseName}_${dateStr}_$timeStr.json';

    final fileMetadata = drive_api.File()
      ..name = datedFileName
      ..mimeType = _config.mimeType;

    // Set parent folder if specified
    if (_config.parentFolder != null) {
      fileMetadata.parents = [_config.parentFolder!];
    }

    final created = await _driveApi.files.create(fileMetadata, uploadMedia: media);
    return created.id!;
  }

  /// Read content from a specific backup file by name
  Future<String?> readBackupFile(String fileName) async {
    final query = "name='$fileName' and trashed=false";
    final spaces = _config.parentFolder;
    
    final result = await _driveApi.files.list(
      q: query,
      spaces: spaces,
    );
    
    final files = result.files;
    if (files != null && files.isNotEmpty) {
      return await readFile(files.first.id!);
    }
    return null;
  }
}