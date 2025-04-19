import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notes/providers/note_provider.dart';
import '../../../../core/notes/models/note_model.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isEditMode = false;
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
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final noteResult = await ref.read(noteProvider(widget.noteId!).future);

      if (noteResult != null) {
        _titleController.text = noteResult.title;
        _contentController.text = noteResult.content;
        setState(() {
          _originalNote = noteResult;
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

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Check if there are actual changes when in edit mode
    if (_isEditMode && _originalNote != null) {
      bool hasChanges =
          title != _originalNote!.title || content != _originalNote!.content;

      if (!hasChanges) {
        if (mounted) {
          context.pop();
        }
        return;
      }
    }

    // Validate inputs
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditMode && _originalNote != null) {
        final updatedNote = NoteModel(
          id: _originalNote!.id,
          title: title,
          content: content,
          createdAt: _originalNote!.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );

        await ref.read(notesProvider.notifier).updateNote(updatedNote);
      } else {
        await ref.read(notesProvider.notifier).createNote(title, content);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save note: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Note' : 'New Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEditorForm(),
    );
  }

  Widget _buildEditorForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              labelText: 'Content',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 20,
            minLines: 10,
          ),
          const SizedBox(height: 16),
          if (_isSaving)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
