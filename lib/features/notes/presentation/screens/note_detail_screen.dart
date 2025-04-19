import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/drive/models/note_model.dart';
import '../../../../core/drive/providers/drive_provider.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String? noteId; // null means new note

  const NoteDetailScreen({Key? key, this.noteId}) : super(key: key);

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _title = '';
  String _content = '';
  List<String> _tags = [];
  bool _isLoading = false;
  bool _isNew = false;
  NoteModel? _originalNote;

  final _tagController = TextEditingController();
  final _tagFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _isNew = widget.noteId == null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If editing an existing note, fetch its details
    if (!_isNew) {
      return ref.watch(selectedNoteProvider(widget.noteId!)).when(
            data: (note) {
              if (note != null && _originalNote == null) {
                _originalNote = note;
                _titleController.text = note.title;
                _contentController.text = note.content;
                _title = note.title;
                _content = note.content;
                _tags = List.from(note.tags);
              }
              return _buildScaffold(context);
            },
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: Center(
                child: Text('Error loading note: $error'),
              ),
            ),
          );
    } else {
      // New note
      return _buildScaffold(context);
    }
  }

  Scaffold _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Note' : 'Edit Note'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    onChanged: (value) => _title = value,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 15,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter note content';
                      }
                      return null;
                    },
                    onChanged: (value) => _content = value,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ..._tags.map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  onDeleted: () {
                                    setState(() {
                                      _tags.remove(tag);
                                    });
                                  },
                                ),
                              ),
                              // Add tag chip
                              InputChip(
                                label: const Icon(Icons.add),
                                onPressed: _showAddTagDialog,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: _tagController,
          focusNode: _tagFocus,
          decoration: const InputDecoration(
            labelText: 'Tag Name',
            hintText: 'Enter a tag name',
          ),
          onSubmitted: (_) {
            _addTag();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              _addTag();
              Navigator.of(context).pop();
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    ).then((_) => _tagController.clear());

    // Focus the text field when dialog is shown
    Future.delayed(const Duration(milliseconds: 200), () {
      _tagFocus.requestFocus();
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isNew) {
        // Create new note
        final result = await ref.read(notesProvider.notifier).createNote(
              _title,
              _content,
              tags: _tags,
            );

        if (mounted) {
          result.fold(
            (error) => _showError('Failed to create note: $error'),
            (note) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note created successfully')),
              );
              context.pop();
            },
          );
        }
      } else {
        // Update existing note
        final result = await ref.read(notesProvider.notifier).updateNote(
              widget.noteId!,
              _title,
              _content,
              tags: _tags,
            );

        if (mounted) {
          result.fold(
            (error) => _showError('Failed to update note: $error'),
            (note) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note updated successfully')),
              );
              context.pop();
            },
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content:
            Text('Are you sure you want to delete "${_originalNote?.title}"?'),
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

    if (confirmed == true && widget.noteId != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result =
            await ref.read(notesProvider.notifier).deleteNote(widget.noteId!);

        if (mounted) {
          result.fold(
            (error) => _showError('Failed to delete note: $error'),
            (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note deleted')),
              );
              context.pop();
            },
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
