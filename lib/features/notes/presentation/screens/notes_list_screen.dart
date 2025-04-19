import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/drive/providers/drive_provider.dart';
import '../widgets/note_list_item.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsyncValue = ref.watch(filteredNotesProvider);
    final selectedTag = ref.watch(selectedTagProvider);
    final allTags = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DriveNotes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(notesProvider.notifier).refreshNotes();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('All Notes'),
              selected: selectedTag == null,
              onTap: () {
                ref.read(selectedTagProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...allTags.map((tag) => ListTile(
                  title: Text(tag),
                  selected: tag == selectedTag,
                  onTap: () {
                    ref.read(selectedTagProvider.notifier).state = tag;
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
      body: notesAsyncValue.when(
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_alt_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    selectedTag == null
                        ? 'No notes yet. Create your first note!'
                        : 'No notes with tag: $selectedTag',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notesProvider.notifier).refreshNotes(),
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return NoteListItem(
                  note: note,
                  onTap: () => _viewNote(context, note.id ?? ''),
                  onDelete: () => _confirmDeleteNote(
                      context, ref, note.id ?? '', note.title),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading notes: $error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewNote(context),
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _viewNote(BuildContext context, String noteId) {
    context.push('/note/$noteId');
  }

  void _createNewNote(BuildContext context) {
    context.push('/note/new');
  }

  Future<void> _confirmDeleteNote(
    BuildContext context,
    WidgetRef ref,
    String noteId,
    String noteTitle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "$noteTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref.read(notesProvider.notifier).deleteNote(noteId);

      if (context.mounted) {
        result.fold(
          (error) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          ),
          (_) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note "$noteTitle" deleted')),
          ),
        );
      }
    }
  }
}
