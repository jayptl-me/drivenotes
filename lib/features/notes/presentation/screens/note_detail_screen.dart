import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/drive/providers/drive_provider.dart';
import '../../../../core/drive/models/note_model.dart';

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(selectedNoteProvider(noteId));

    return Scaffold(
      appBar: AppBar(
        title: noteAsync.maybeWhen(
          data: (note) => Text(note?.title ?? 'Note'),
          orElse: () => const Text('Note'),
        ),
        actions: [
          noteAsync.maybeWhen(
            data:
                (note) =>
                    note != null
                        ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.push('/note/edit/$noteId'),
                        )
                        : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) {
          if (note == null) {
            return const Center(child: Text('Note not found'));
          }

          return _buildNoteContent(context, note, ref);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${error.toString()}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(selectedNoteProvider(noteId)),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildNoteContent(
    BuildContext context,
    NoteModel note,
    WidgetRef ref,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy - h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note metadata
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Modified: ${dateFormat.format(note.modifiedAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Created: ${dateFormat.format(note.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),

          // Tags
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  note.tags.map((tag) {
                    return InkWell(
                      onTap: () {
                        ref.read(selectedTagProvider.notifier).state = tag;
                        context.pop();
                      },
                      child: Chip(
                        label: Text(tag),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                    );
                  }).toList(),
            ),
          ],

          const Divider(height: 32),

          // Note content
          Text(
            note.content ?? 'No content',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
