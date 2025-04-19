import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for the NoteService
final noteServiceProvider = Provider<NoteService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return NoteService(authService);
});

// Provider for all notes
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(() {
  return NotesNotifier();
});

// Provider for a single note
final noteProvider =
    FutureProvider.family<NoteModel?, String>((ref, noteId) async {
  final noteService = ref.read(noteServiceProvider);
  final result = await noteService.getNote(noteId);
  return result.fold(
    (error) => null,
    (note) => note,
  );
});

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  @override
  Future<List<NoteModel>> build() async {
    return _fetchNotes();
  }

  Future<List<NoteModel>> _fetchNotes() async {
    final noteService = ref.read(noteServiceProvider);
    final result = await noteService.listNotes();
    return result.fold(
      (error) => [],
      (notes) => notes,
    );
  }

  Future<void> refreshNotes() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchNotes());
  }

  Future<void> createNote(String title, String content) async {
    final noteService = ref.read(noteServiceProvider);
    final result = await noteService.createNote(
      title: title,
      content: content,
    );

    result.fold(
      (error) => null,
      (newNote) {
        state.whenData((notes) {
          state = AsyncValue.data([newNote, ...notes]);
        });
      },
    );
  }

  Future<void> updateNote(NoteModel updatedNote) async {
    final noteService = ref.read(noteServiceProvider);
    final result = await noteService.updateNote(updatedNote);

    result.fold(
      (error) => null,
      (updated) {
        state.whenData((notes) {
          final updatedNotes = notes.map((note) {
            return note.id == updated.id ? updated : note;
          }).toList();
          state = AsyncValue.data(updatedNotes);
        });
      },
    );
  }

  Future<void> deleteNote(String noteId) async {
    final noteService = ref.read(noteServiceProvider);
    final result = await noteService.deleteNote(noteId);

    result.fold(
      (error) => null,
      (_) {
        state.whenData((notes) {
          final updatedNotes =
              notes.where((note) => note.id != noteId).toList();
          state = AsyncValue.data(updatedNotes);
        });
      },
    );
  }
}
