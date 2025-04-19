import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/drive/providers/drive_provider.dart';
import '../../../../core/drive/models/note_model.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isEditMode = false;
  List<String> _tags = [];
  NoteModel? _originalNote;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.noteId != null;
    if (_isEditMode) {
      _loadNote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final note = await ref
          .read(notesProvider.notifier)
          .getNoteById(widget.noteId!);

      if (note != null) {
        _titleController.text = note.title;
        _contentController.text = note.content ?? '';
        setState(() {
          _tags = List.from(note.tags);
          _originalNote = note;
        });
      } else {
        _errorMessage = 'Note not found';
      }
    } catch (e) {
      _errorMessage = 'Failed to load note: ${e.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Check if there are actual changes when in edit mode
    if (_isEditMode && _originalNote != null) {
      bool hasChanges = title != _originalNote!.title || 
                        content != _originalNote!.content ||
                        !_areTagListsEqual(_tags, _originalNote!.tags);
                        
      if (!hasChanges) {
        if (context.mounted) {
          context.pop();
        }
        return;
      }
    }
    
    // Validate inputs
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result =
          _isEditMode
              ? await ref
                  .read(notesProvider.notifier)
                  .updateNote(widget.noteId!, title, content, tags: _tags)
              : await ref
                  .read(notesProvider.notifier)
                  .createNote(title, content, tags: _tags);

      result.fold(
        (error) {
          setState(() {
            _errorMessage = error;
            _isSaving = false;
          });
        },
        (note) {
          setState(() {
            _isSaving = false;
          });
          if (context.mounted) {
            context.pop();
          }
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save note: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  bool _areTagListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Note' : 'New Note'),
        actions: [
          _isSaving
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
              : IconButton(icon: const Icon(Icons.check), onPressed: _saveNote),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(_errorMessage!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isEditMode ? _loadNote : () => context.pop(),
                      child: Text(_isEditMode ? 'Try Again' : 'Go Back'),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Title input
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      autofocus: !_isEditMode,
                    ),
                    const Divider(),

                    // Tags section
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              hintText: 'Add a tag',
                              prefixIcon: Icon(Icons.tag),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                        ),
                      ],
                    ),

                    // Tags list
                    if (_tags.isNotEmpty)
                      Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(_tags[index]),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeTag(_tags[index]),
                              ),
                            );
                          },
                        ),
                      ),

                    const Divider(),

                    // Content input
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Note content...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
