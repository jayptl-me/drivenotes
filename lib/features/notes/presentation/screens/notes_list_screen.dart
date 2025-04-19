import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../../core/drive/providers/drive_provider.dart';
import '../../../../core/drive/models/note_model.dart';
import '../../../../core/auth/providers/auth_provider.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredNotesState = ref.watch(filteredNotesProvider);
    final userState = ref.watch(authStateProvider);
    final allTags = ref.watch(allTagsProvider);
    final selectedTag = ref.watch(selectedTagProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(notesProvider.notifier).refreshNotes(),
          ),
          PopupMenuButton(
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    child: const Text('Sign Out'),
                    onTap: () => ref.read(authStateProvider.notifier).signOut(),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // User info header
          userState.maybeWhen(
            data: (user) {
              if (user != null) {
                return ListTile(
                  leading:
                      user.photoUrl != null
                          ? CircleAvatar(
                            backgroundImage: NetworkImage(user.photoUrl!),
                          )
                          : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),

          Divider(color: Colors.grey[300]),

          // Tags filter
          if (allTags.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allTags.length + 1, // +1 for "All" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: selectedTag == null,
                        onSelected:
                            (_) =>
                                ref.read(selectedTagProvider.notifier).state =
                                    null,
                      ),
                    );
                  } else {
                    final tag = allTags[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: selectedTag == tag,
                        onSelected:
                            (_) =>
                                ref.read(selectedTagProvider.notifier).state =
                                    tag,
                      ),
                    );
                  }
                },
              ),
            ),

          // Notes list
          Expanded(
            child: filteredNotesState.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.note_alt_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedTag != null
                              ? 'No notes with tag "$selectedTag"'
                              : 'No notes yet',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first note by tapping the + button',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh:
                      () => ref.read(notesProvider.notifier).refreshNotes(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _buildNoteItem(context, ref, note);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${error.toString()}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              () =>
                                  ref
                                      .read(notesProvider.notifier)
                                      .refreshNotes(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/note/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, WidgetRef ref, NoteModel note) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(note.modifiedAt);

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              context.push('/note/edit/${note.id}');
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (context) {
              _confirmDelete(context, ref, note);
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedDate, style: const TextStyle(fontSize: 12)),
            if (note.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children:
                      note.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/note/${note.id}'),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NoteModel note) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Note'),
            content: Text('Are you sure you want to delete "${note.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(notesProvider.notifier).deleteNote(note.id);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${note.title} deleted'),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () {
                            // Restore note functionality would go here
                          },
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
