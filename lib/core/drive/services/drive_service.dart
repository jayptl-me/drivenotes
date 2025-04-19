import 'dart:convert';
import 'dart:async'; // Added for Stream reading
import 'package:dartz/dartz.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/note_model.dart';

const String folderName = 'DriveNotesApp';
const String folderMimeType = 'application/vnd.google-apps.folder';
const String textMimeType = 'text/plain';

class DriveService {
  // Find or create the app folder
  Future<Either<String, String>> _findOrCreateFolder(http.Client client) async {
    final driveApi = drive.DriveApi(client);
    try {
      final fileList = await driveApi.files.list(
        q: "mimeType='$folderMimeType' and name='$folderName' and trashed=false",
        $fields: 'files(id)', // Corrected parameter name
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return right(fileList.files!.first.id!);
      } else {
        // Folder not found, create it
        final folder = drive.File()
          ..name = folderName
          ..mimeType = folderMimeType;
        final createdFolder = await driveApi.files.create(
          folder,
          $fields: 'id', // Corrected parameter name
        );
        return right(createdFolder.id!);
      }
    } catch (e) {
      return left('Error finding/creating app folder: ${e.toString()}');
    }
  }

  // Get all notes
  Future<Either<String, List<NoteModel>>> getNotes(http.Client client) async {
    try {
      final folderIdResult = await _findOrCreateFolder(client);

      return folderIdResult.fold(
        (error) => left(error),
        (folderId) async {
          final driveApi = drive.DriveApi(client);
          final fileList = await driveApi.files.list(
            q: "'$folderId' in parents and mimeType='$textMimeType' and trashed=false",
            $fields:
                'files(id, name, modifiedTime)', // Corrected parameter name
          );

          if (fileList.files == null) {
            return right([]);
          }

          final notes = <NoteModel>[];
          for (final file in fileList.files!) {
            // Check if file has an ID before proceeding
            if ((file as drive.File).id == null) continue;

            try {
              final media = await driveApi.files.get(
                (file as drive.File).id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              ) as drive.Media; // Keep cast here for media download

              final contentBytes = await _readMedia(media);
              final content = utf8.decode(contentBytes);

              // Parse content for potential JSON data (for tags, etc.)
              Map<String, dynamic> metadata = {};
              String noteContent = content;

              try {
                if (content.startsWith('---JSON---')) {
                  final parts = content.split('---JSON---\n');
                  if (parts.length > 1) {
                    // Safely decode JSON
                    final jsonPart =
                        parts[1].split('\n').first; // Get only the JSON line
                    metadata = json.decode(jsonPart);
                    noteContent = parts.length > 2
                        ? parts.sublist(2).join('---JSON---\n')
                        : ''; // Reconstruct content after JSON
                  }
                }
              } catch (e) {
                // If parsing fails, use the entire content as the note
                noteContent =
                    content; // Ensure noteContent is the full content on error
              }

              notes.add(NoteModel(
                id: (file as drive.File).id!, // Access id directly from file
                title: (file as drive.File).name?.replaceAll('.txt', '') ??
                    'Untitled', // Access name directly
                content: noteContent,
                lastModified: (file as drive.File).modifiedTime ??
                    DateTime.now(), // Access modifiedTime directly
                tags:
                    (metadata['tags'] as List<dynamic>?)?.cast<String>() ?? [],
              ));
            } catch (e) {
              // Optionally skip this file or add a placeholder note
            }
          }
          return right(notes);
        },
      );
    } catch (e) {
      return left('Error fetching notes: ${e.toString()}');
    }
  }

  // Get a single note by ID
  Future<Either<String, NoteModel>> getNoteById(
      http.Client client, String noteId) async {
    try {
      final driveApi = drive.DriveApi(client);

      // Get file metadata first
      final file = await driveApi.files.get(
        noteId,
        $fields: 'id, name, modifiedTime', // Corrected parameter name
      ) as drive.File; // Explicitly cast to drive.File

      // Then get file content
      final media = await driveApi.files.get(
        noteId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media; // Cast is correct here for content download

      final contentBytes = await _readMedia(media);
      final content = utf8.decode(contentBytes);

      // Parse content for potential JSON data
      Map<String, dynamic> metadata = {};
      String noteContent = content;

      try {
        if (content.startsWith('---JSON---')) {
          final parts = content.split('---JSON---\n');
          if (parts.length > 1) {
            final jsonPart =
                parts[1].split('\n').first; // Get only the JSON line
            metadata = json.decode(jsonPart);
            noteContent = parts.length > 2
                ? parts.sublist(2).join('---JSON---\n')
                : ''; // Reconstruct content after JSON
          }
        }
      } catch (_) {
        // If parsing fails, use the entire content as the note
        noteContent =
            content; // Ensure noteContent is the full content on error
      }

      return right(NoteModel(
        id: file.id!, // Now file is properly typed as drive.File
        title: file.name?.replaceAll('.txt', '') ??
            'Untitled', // Now file is properly typed as drive.File
        content: noteContent,
        lastModified: file.modifiedTime ??
            DateTime.now(), // Now file is properly typed as drive.File
        tags: (metadata['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      ));
    } catch (e) {
      return left('Error fetching note: ${e.toString()}');
    }
  }

  // Create a new note
  Future<Either<String, NoteModel>> createNote(
    http.Client client,
    String title,
    String content, {
    List<String> tags = const [],
  }) async {
    try {
      final folderIdResult = await _findOrCreateFolder(client);

      return folderIdResult.fold(
        (error) => left(error),
        (folderId) async {
          final driveApi = drive.DriveApi(client);

          // Prepare file metadata
          final fileMetadata = drive.File()
            ..name = '$title.txt'
            ..parents = [folderId]
            ..mimeType = textMimeType;

          // Format content with metadata
          final Map<String, dynamic> metadata = {'tags': tags};
          // Ensure JSON is on a single line after the separator
          final formattedContent =
              '---JSON---\n${json.encode(metadata)}\n$content';

          // Create file with content
          final contentBytes = utf8.encode(formattedContent);
          final media = drive.Media(
            Stream.fromIterable([contentBytes]),
            contentBytes.length,
            contentType: textMimeType,
          );

          final createdFile = await driveApi.files.create(
            fileMetadata,
            uploadMedia: media,
            $fields:
                'id, name, modifiedTime', // Request fields for the created file
          );

          return right(NoteModel(
            id: createdFile.id!,
            title: createdFile.name?.replaceAll('.txt', '') ??
                title, // Use returned name
            content: content, // Original content
            lastModified:
                createdFile.modifiedTime ?? DateTime.now(), // Use returned time
            tags: tags,
          ));
        },
      );
    } catch (e) {
      return left('Error creating note: ${e.toString()}');
    }
  }

  // Update an existing note
  Future<Either<String, NoteModel>> updateNote(
    http.Client client,
    String noteId,
    String title,
    String content, {
    List<String> tags = const [],
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      // Update file metadata (name) if needed
      final fileUpdate = drive.File()..name = '$title.txt';
      // Request updated fields in response
      final updatedMetadata = await driveApi.files.update(
        fileUpdate,
        noteId,
        $fields: 'id, name, modifiedTime', // Corrected parameter name
      );

      // Format content with metadata
      final Map<String, dynamic> metadata = {'tags': tags};
      // Ensure JSON is on a single line after the separator
      final formattedContent = '---JSON---\n${json.encode(metadata)}\n$content';

      // Update content
      final contentBytes = utf8.encode(formattedContent);
      final media = drive.Media(
        Stream.fromIterable([contentBytes]),
        contentBytes.length,
        contentType: textMimeType,
      );

      // Perform the content update (doesn't need $fields here)
      await driveApi.files.update(
        drive.File(), // Empty file for content update
        noteId,
        uploadMedia: media,
      );

      return right(NoteModel(
        id: updatedMetadata.id!, // Use returned ID
        title: updatedMetadata.name?.replaceAll('.txt', '') ??
            title, // Use returned name
        content: content, // Original content
        lastModified:
            updatedMetadata.modifiedTime ?? DateTime.now(), // Use returned time
        tags: tags,
      ));
    } catch (e) {
      return left('Error updating note: ${e.toString()}');
    }
  }

  // Delete a note
  Future<Either<String, bool>> deleteNote(
      http.Client client, String noteId) async {
    try {
      final driveApi = drive.DriveApi(client);
      await driveApi.files.delete(noteId);
      return right(true);
    } catch (e) {
      return left('Error deleting note: ${e.toString()}');
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
