import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;

import '../models/note_model.dart';

class DriveService {
  static const String folderName = 'DriveNotes';
  static const String folderMimeType = 'application/vnd.google-apps.folder';
  static const String textMimeType = 'text/plain';

  // Initialize Drive API client
  Future<drive.DriveApi> _getDriveApi(http.Client client) async {
    return drive.DriveApi(client);
  }

  // Find or create the DriveNotes folder
  Future<Either<String, String>> findOrCreateFolder(http.Client client) async {
    try {
      final driveApi = await _getDriveApi(client);

      // Search for existing folder
      final folderList = await driveApi.files.list(
        q: "name='$folderName' and mimeType='$folderMimeType' and trashed=false",
        spaces: 'drive',
      );

      // If folder exists, return its ID
      if (folderList.files != null && folderList.files!.isNotEmpty) {
        return right(folderList.files!.first.id!);
      }

      // Otherwise, create the folder
      final folderMetadata =
          drive.File()
            ..name = folderName
            ..mimeType = folderMimeType;

      final folder = await driveApi.files.create(folderMetadata);

      return right(folder.id!);
    } catch (e) {
      return left('Failed to find or create Drive folder: ${e.toString()}');
    }
  }

  // Get all notes from the DriveNotes folder
  Future<Either<String, List<NoteModel>>> getNotes(http.Client client) async {
    try {
      final driveApi = await _getDriveApi(client);

      // Get folder ID
      final folderResult = await findOrCreateFolder(client);

      return await folderResult.fold((error) => left(error), (folderId) async {
        // Query files in the folder
        final fileList = await driveApi.files.list(
          q: "parents in '$folderId' and mimeType='$textMimeType' and trashed=false",
          spaces: 'drive',
          $fields: 'files(id, name, createdTime, modifiedTime, properties)',
        );

        if (fileList.files == null) {
          return right([]);
        }

        final notes =
            fileList.files!.map((file) {
              // Extract tags from file properties
              List<String> tags = [];
              if (file.properties != null &&
                  file.properties!.containsKey('tags')) {
                final tagsJson = file.properties!['tags'];
                if (tagsJson != null) {
                  tags = List<String>.from(json.decode(tagsJson));
                }
              }

              // Convert file to note model
              return NoteModel(
                id: file.id!,
                title: file.name!.replaceAll('.txt', ''),
                content: null, // Content will be loaded on demand
                createdAt: file.createdTime ?? DateTime.now(),
                modifiedAt: file.modifiedTime ?? DateTime.now(),
                tags: tags,
              );
            }).toList();

        return right(notes);
      });
    } catch (e) {
      return left('Failed to get notes: ${e.toString()}');
    }
  }

  // Get a specific note with its content
  Future<Either<String, NoteModel>> getNoteById(
    http.Client client,
    String noteId,
  ) async {
    try {
      final driveApi = await _getDriveApi(client);

      // Get file metadata
      final file =
          await driveApi.files.get(
                noteId,
                $fields: 'id,name,createdTime,modifiedTime,properties',
              )
              as drive.File;

      // Get file content
      final media =
          await driveApi.files.get(
                noteId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final contentBytes = await media.stream.toBytes();
      final content = utf8.decode(contentBytes);

      // Extract tags from properties
      List<String> tags = [];
      if (file.properties != null && file.properties!.containsKey('tags')) {
        final tagsJson = file.properties!['tags'];
        if (tagsJson != null) {
          tags = List<String>.from(json.decode(tagsJson));
        }
      }

      final note = NoteModel(
        id: file.id!,
        title: file.name!.replaceAll('.txt', ''),
        content: content,
        createdAt: file.createdTime ?? DateTime.now(),
        modifiedAt: file.modifiedTime ?? DateTime.now(),
        tags: tags,
      );

      return right(note);
    } catch (e) {
      return left('Failed to get note: ${e.toString()}');
    }
  }

  // Create a new note
  Future<Either<String, NoteModel>> createNote(
    http.Client client,
    String title,
    String content, {
    List<String>? tags,
  }) async {
    try {
      final driveApi = await _getDriveApi(client);

      // Get folder ID
      final folderResult = await findOrCreateFolder(client);

      return await folderResult.fold((error) => left(error), (folderId) async {
        final fileName = '$title.txt';

        // Create file metadata with tags in properties
        final fileMetadata =
            drive.File()
              ..name = fileName
              ..mimeType = textMimeType
              ..parents = [folderId];

        // Add tags as properties if provided
        if (tags != null && tags.isNotEmpty) {
          fileMetadata.properties = {'tags': json.encode(tags)};
        }

        // Create file with content
        final contentBytes = utf8.encode(content);
        final media = drive.Media(
          Stream.fromIterable([contentBytes]),
          contentBytes.length,
        );

        final file = await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );

        final now = DateTime.now();

        final note = NoteModel(
          id: file.id!,
          title: title,
          content: content,
          createdAt: now,
          modifiedAt: now,
          tags: tags ?? [],
        );

        return right(note);
      });
    } catch (e) {
      return left('Failed to create note: ${e.toString()}');
    }
  }

  // Update an existing note
  Future<Either<String, NoteModel>> updateNote(
    http.Client client,
    String noteId,
    String title,
    String content, {
    List<String>? tags,
  }) async {
    try {
      final driveApi = await _getDriveApi(client);

      // Update file metadata
      final fileMetadata = drive.File()..name = '$title.txt';

      // Add tags as properties if provided
      if (tags != null) {
        fileMetadata.properties = {'tags': json.encode(tags)};
      }

      // Update file with content
      final contentBytes = utf8.encode(content);
      final media = drive.Media(
        Stream.fromIterable([contentBytes]),
        contentBytes.length,
      );

      final file = await driveApi.files.update(
        fileMetadata,
        noteId,
        uploadMedia: media,
      );

      final now = DateTime.now();

      final note = NoteModel(
        id: file.id!,
        title: title,
        content: content,
        createdAt: file.createdTime ?? now,
        modifiedAt: now,
        tags: tags ?? [],
      );

      return right(note);
    } catch (e) {
      return left('Failed to update note: ${e.toString()}');
    }
  }

  // Delete a note
  Future<Either<String, bool>> deleteNote(
    http.Client client,
    String noteId,
  ) async {
    try {
      final driveApi = await _getDriveApi(client);
      await driveApi.files.delete(noteId);
      return right(true);
    } catch (e) {
      return left('Failed to delete note: ${e.toString()}');
    }
  }
}

extension StreamExtension on Stream<List<int>> {
  Future<List<int>> toBytes() async {
    final chunks = <int>[];
    await for (final chunk in this) {
      chunks.addAll(chunk);
    }
    return chunks;
  }
}
