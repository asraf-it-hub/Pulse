import 'package:flutter/material.dart';
import '../../../core/models/media_item.dart';
import '../application/library_controller.dart';

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    required this.item,
    required this.libraryController,
    super.key,
  });

  final MediaItem item;
  final LibraryController libraryController;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _genreController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _artistController = TextEditingController(text: widget.item.artist ?? '');
    _albumController = TextEditingController(text: widget.item.album ?? '');
    _genreController = TextEditingController(text: widget.item.genre ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.item.copyWith(
      title: _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
      album: _albumController.text.trim().isEmpty ? null : _albumController.text.trim(),
      genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
    );
    widget.libraryController.updateItem(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Edit Track Metadata (🏷️)',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Track Title',
              prefixIcon: Icon(Icons.title_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _artistController,
            decoration: const InputDecoration(
              labelText: 'Artist',
              prefixIcon: Icon(Icons.person_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _albumController,
            decoration: const InputDecoration(
              labelText: 'Album',
              prefixIcon: Icon(Icons.album_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _genreController,
            decoration: const InputDecoration(
              labelText: 'Genre',
              prefixIcon: Icon(Icons.category_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Metadata'),
            ),
          ),
        ],
      ),
    );
  }
}
