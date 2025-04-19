import 'dart:convert';
import 'dart:async'; // Added for Completer and Stream handling
import 'package:dartz/dartz.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

import '../models/note_model.dart';
import '../../auth/services/auth_service.dart'; // To get authenticated client

// Add a logger
final _logger = Logger('NoteService');

class NoteService {
  final AuthService _authService;
  final Uuid _uuid = const Uuid();
  static const String _appFolderName =
      'DriveNotesApp'; // Or your preferred folder name
  String? _appFolderId; // Cache folder ID

  NoteService(this._authService);

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      // User is not authenticated or token expired and couldn't refresh
      return null;
    }
    return drive.DriveApi(client);
  }

  // Find or create the application-specific folder
  Future<String?> _getOrCreateAppFolder(drive.DriveApi driveApi) async {
    if (_appFolderId != null) return _appFolderId;

    try {
      // Check if folder exists
      final query =
          "mimeType='application/vnd.google-apps.folder' and name='$_appFolderName' and trashed=false";
      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        _appFolderId = response.files!.first.id;
        return _appFolderId;
      } else {
        // Create the folder if it doesn't exist
        final folder = drive.File()
          ..name = _appFolderName
          ..mimeType = 'application/vnd.google-apps.folder';

        final createdFolder = await driveApi.files.create(
          folder,
          $fields: 'id',
        );
        _appFolderId = createdFolder.id;
        return _appFolderId;
      }
    } catch (e) {
      _logger.warning('Error finding/creating app folder: $e');
      return null; // Handle error appropriately
    }
  }

  // Create a new note
  Future<Either<String, NoteModel>> createNote({
    required String title,
    required String content,
  }) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return left('Authentication required or failed.');
    }

    final folderId = await _getOrCreateAppFolder(driveApi);
    if (folderId == null) {
      return left('Failed to find or create the app folder in Google Drive.');
    }

    try {
      final now = DateTime.now().toUtc();
      final note = NoteModel(
        id: _uuid.v4(),
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
      );

      final noteJson = jsonEncode(note.toJson());
      final media = http.ByteStream(Stream.value(utf8.encode(noteJson)));
      final length = utf8.encode(noteJson).length;

      final driveFile = drive.File()
        ..name = '${note.id}.json' // Use unique ID as filename
        ..mimeType = 'application/json'
        ..parents = [folderId]; // Place it inside the app folder

      final createdFile = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(media, length),
        $fields: 'id', // Request fields needed, e.g., 'id'
      );

      if (createdFile.id != null) {
        // Optionally, you might want to store the Drive file ID with the note locally
        // or return the created NoteModel.
        return right(note);
      } else {
        return left('Failed to create note file in Google Drive.');
      }
    } catch (e) {
      _logger.warning('Error creating note: $e');
      // Consider more specific error handling based on Google Drive API errors
      return left('An error occurred while creating the note: ${e.toString()}');
    }
  }

  // List all notes from Google Drive
  Future<Either<String, List<NoteModel>>> listNotes() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return left('Authentication required or failed.');
    }

    final folderId = await _getOrCreateAppFolder(driveApi);
    if (folderId == null) {
      return left('Failed to find or create the app folder in Google Drive.');
    }

    try {
      final query =
          "parents='$folderId' and mimeType='application/json' and trashed=false";
      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (response.files == null || response.files!.isEmpty) {
        return right([]); // Return empty list if no notes found
      }

      final notes = <NoteModel>[];
      for (final file in response.files!) {
        final fileId = file.id!;
        final noteResult = await getNote(fileId);
        noteResult.fold(
          (error) => null, // Skip files with errors
          (note) => notes.add(note),
        );
      }

      return right(notes);
    } catch (e) {
      _logger.warning('Error listing notes: $e');
      return left('Failed to list notes: ${e.toString()}');
    }
  }

  // Get a specific note by ID
  Future<Either<String, NoteModel>> getNote(String noteId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return left('Authentication required or failed.');
    }

    try {
      // Find the file by ID
      await driveApi.files.get(noteId, $fields: 'id,name');

      // Download file content
      final media = await driveApi.files.get(
        noteId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await _readMedia(media);
      final contentJson = utf8.decode(bytes);

      try {
        final Map<String, dynamic> jsonMap = json.decode(contentJson);
        return right(NoteModel.fromJson(jsonMap));
      } catch (e) {
        return left('Failed to parse note data: ${e.toString()}');
      }
    } catch (e) {
      _logger.warning('Error getting note: $e');
      return left('Failed to retrieve note: ${e.toString()}');
    }
  }

  // Update an existing note
  Future<Either<String, NoteModel>> updateNote(NoteModel note) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return left('Authentication required or failed.');
    }

    try {
      // Update the modified timestamp
      final updatedNote = NoteModel(
        id: note.id,
        title: note.title,
        content: note.content,
        createdAt: note.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

      // Convert note to JSON
      final noteJson = jsonEncode(updatedNote.toJson());
      final media = http.ByteStream(Stream.value(utf8.encode(noteJson)));
      final length = utf8.encode(noteJson).length;

      // Update the file contents
      await driveApi.files.update(
        drive.File(),
        note.id, // Use note ID as the file ID
        uploadMedia: drive.Media(media, length),
      );

      return right(updatedNote);
    } catch (e) {
      _logger.warning('Error updating note: $e');
      return left('Failed to update note: ${e.toString()}');
    }
  }

  // Delete a note
  Future<Either<String, bool>> deleteNote(String noteId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return left('Authentication required or failed.');
    }

    try {
      await driveApi.files.delete(noteId);
      return right(true);
    } catch (e) {
      _logger.warning('Error deleting note: $e');
      return left('Failed to delete note: ${e.toString()}');
    }
  }

  // Helper method to read media content
  Future<List<int>> _readMedia(drive.Media media) async {
    final completer = Completer<List<int>>();
    final sink =
        ByteConversionSink.withCallback((bytes) => completer.complete(bytes));
    media.stream.listen(
      sink.add,
      onError: completer.completeError,
      onDone: sink.close,
      cancelOnError: true,
    );
    return completer.future;
  }
}
