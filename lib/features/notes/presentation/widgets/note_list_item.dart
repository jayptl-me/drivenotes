import 'package:flutter/material.dart';
import '../../../../core/drive/models/note_model.dart';
import 'package:intl/intl.dart';

class NoteListItem extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Dismissible(
      key: Key(note.id ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle the actual deletion in the callback
      },
      child: ListTile(
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(note.lastModified),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.label_outline,
                      size: 14, color: theme.colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note.tags.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        onTap: onTap,
        onLongPress: onDelete,
      ),
    );
  }
}
