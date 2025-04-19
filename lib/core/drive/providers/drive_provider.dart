import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http; // Add this import

import '../models/note_model.dart';
import '../services/drive_service.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for Drive service
final driveServiceProvider = Provider<DriveService>((ref) {
  return DriveService();
});

// Provider for authenticated HTTP client
final authenticatedClientProvider = FutureProvider<http.Client?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getAuthenticatedClient();
});

// Provider for notes state
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(() {
  return NotesNotifier();
});

// Provider for storing currently selected tag filter
final selectedTagProvider = StateProvider<String?>((ref) => null);

// Provider for filtered notes based on selected tag
final filteredNotesProvider = Provider<AsyncValue<List<NoteModel>>>((ref) {
  final notesState = ref.watch(notesProvider);
  final selectedTag = ref.watch(selectedTagProvider);

  return notesState.when(
    data: (notes) {
      if (selectedTag == null) return AsyncValue.data(notes);

      final filtered =
          notes.where((note) => note.tags.contains(selectedTag)).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Provider for all unique tags across notes
final allTagsProvider = Provider<List<String>>((ref) {
  final notesState = ref.watch(notesProvider);

  return notesState.when(
    data: (notes) {
      final Set<String> uniqueTags = {};
      for (final note in notes) {
        uniqueTags.addAll(note.tags);
      }
      return uniqueTags.toList()..sort();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  @override
  Future<List<NoteModel>> build() async {
    return _fetchNotes();
  }

  DriveService get _driveService => ref.read(driveServiceProvider);

  Future<List<NoteModel>> _fetchNotes() async {
    final client = await ref.read(authenticatedClientProvider.future);
    if (client == null) {
      throw Exception('Not authenticated');
    }

    final result = await _driveService.getNotes(client);
    return result.fold((error) => throw Exception(error), (notes) => notes);
  }

  Future<NoteModel?> getNoteById(String noteId) async {
    // First check if the note exists in the current state
    final currentNotes = state.value;
    if (currentNotes != null) {
      final cachedNote =
          currentNotes.firstWhereOrNull((note) => note.id == noteId);
      if (cachedNote != null) {
        return cachedNote;
      }
    }

    // If not found in the cache, fetch from Drive
    final client = await ref.read(authenticatedClientProvider.future);
    if (client == null) return null;

    final result = await _driveService.getNoteById(client, noteId);
    return result.fold((error) => null, (note) => note);
  }

  Future<Either<String, NoteModel>> createNote(
    String title,
    String content, {
    List<String>? tags,
  }) async {
    final client = await ref.read(authenticatedClientProvider.future);
    if (client == null) {
      return left('Not authenticated');
    }

    final result = await _driveService.createNote(
      client,
      title,
      content,
      tags: tags ?? [],
    );

    result.fold((error) => null, (note) {
      // Add the new note to the current state
      state = AsyncValue.data([...state.value ?? [], note]);
    });

    return result;
  }

  Future<Either<String, NoteModel>> updateNote(
    String noteId,
    String title,
    String content, {
    List<String>? tags,
  }) async {
    final client = await ref.read(authenticatedClientProvider.future);
    if (client == null) {
      return left('Not authenticated');
    }

    final result = await _driveService.updateNote(
      client,
      noteId,
      title,
      content,
      tags: tags ?? [], // Ensure non-nullable list
    );

    result.fold((error) => null, (updatedNote) {
      // Update the note in the current state
      final currentNotes = state.value ?? [];
      final updatedNotes = currentNotes.map((note) {
        if (note.id == noteId) {
          return updatedNote;
        }
        return note;
      }).toList();

      state = AsyncValue.data(updatedNotes);
    });

    return result;
  }

  Future<Either<String, bool>> deleteNote(String noteId) async {
    final client = await ref.read(authenticatedClientProvider.future);
    if (client == null) {
      return left('Not authenticated');
    }

    final result = await _driveService.deleteNote(client, noteId);

    result.fold((error) => null, (_) {
      // Remove the note from the current state
      final currentNotes = state.value ?? [];
      final updatedNotes =
          currentNotes.where((note) => note.id != noteId).toList();
      state = AsyncValue.data(updatedNotes);
    });

    return result;
  }

  Future<void> refreshNotes() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchNotes());
  }
}

// Provider for selected note details
final selectedNoteProvider = FutureProvider.family<NoteModel?, String>((
  ref,
  noteId,
) async {
  final notifier = ref.read(notesProvider.notifier);
  return notifier.getNoteById(noteId);
});
