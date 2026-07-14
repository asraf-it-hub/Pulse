import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../core/models/media_item.dart';
import '../../../core/widgets/pulse_empty_state.dart';
import '../../player/application/player_controller.dart';
import '../application/library_controller.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.libraryController,
    required this.playerController,
    super.key,
  });

  final LibraryController libraryController;
  final PlayerController playerController;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        widget.libraryController.importPaths(
          detail.files.map((file) => file.path).where((path) => path.trim().isNotEmpty).toList(growable: false),
        );
      },
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: widget.libraryController,
            builder: (context, _) {
              return CustomScrollView(
                slivers: [
                  SliverAppBar.large(
                    title: const Text('Library'),
                    floating: true,
                    actions: [
                      IconButton(
                        tooltip: 'Scan folder',
                        onPressed: widget.libraryController.importFolder,
                        icon: const Icon(Icons.drive_folder_upload_rounded),
                      ),
                      IconButton(
                        tooltip: 'Import media',
                        onPressed: widget.libraryController.importFiles,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(child: _LibraryToolbar(controller: widget.libraryController)),
                  if (widget.libraryController.loading)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  else if (widget.libraryController.error != null)
                    SliverFillRemaining(
                      child: PulseEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Something went wrong',
                        message: widget.libraryController.error!,
                        action: FilledButton.icon(
                          onPressed: widget.libraryController.load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ),
                    )
                  else if (widget.libraryController.visibleItems.isEmpty)
                    SliverFillRemaining(
                      child: PulseEmptyState(
                        icon: Icons.video_library_outlined,
                        title: 'Build your library',
                        message: 'Import files, scan a folder, or drag media into Pulse.',
                        action: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: widget.libraryController.importFiles,
                              icon: const Icon(Icons.file_open_rounded),
                              label: const Text('Import Media'),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget.libraryController.importFolder,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text('Scan Folder'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 126,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: widget.libraryController.visibleItems.length,
                        itemBuilder: (context, index) {
                          final item = widget.libraryController.visibleItems[index];
                          return _MediaTile(
                            item: item,
                            onTap: () => widget.playerController.playItem(item, widget.libraryController.visibleItems),
                            onFavorite: () => widget.libraryController.toggleFavorite(item),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          if (_dragging)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                      child: Text('Drop media or folders to import', style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        children: [
          TextField(
            onChanged: controller.setQuery,
            decoration: const InputDecoration(
              hintText: 'Search music, videos, albums, artists',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<LibraryFilter>(
                  segments: const [
                    ButtonSegment(value: LibraryFilter.all, icon: Icon(Icons.apps_rounded), label: Text('All')),
                    ButtonSegment(value: LibraryFilter.videos, icon: Icon(Icons.movie_outlined), label: Text('Videos')),
                    ButtonSegment(value: LibraryFilter.music, icon: Icon(Icons.music_note_rounded), label: Text('Music')),
                    ButtonSegment(value: LibraryFilter.favorites, icon: Icon(Icons.favorite_outline), label: Text('Favorites')),
                    ButtonSegment(value: LibraryFilter.recent, icon: Icon(Icons.history_rounded), label: Text('Recent')),
                  ],
                  selected: {controller.filter},
                  onSelectionChanged: (value) => controller.setFilter(value.first),
                ),
                const SizedBox(width: 12),
                DropdownButton<LibrarySort>(
                  value: controller.sort,
                  borderRadius: BorderRadius.circular(18),
                  onChanged: (value) {
                    if (value != null) controller.setSort(value);
                  },
                  items: const [
                    DropdownMenuItem(value: LibrarySort.recentlyAdded, child: Text('Recently added')),
                    DropdownMenuItem(value: LibrarySort.recentlyPlayed, child: Text('Recently played')),
                    DropdownMenuItem(value: LibrarySort.title, child: Text('Title')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.onTap,
    required this.onFavorite,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer]),
                ),
                child: Icon(item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (item.artist != null) item.artist,
                        if (item.album != null) item.album,
                        if (item.artist == null && item.album == null) item.isVideo ? 'Video' : 'Audio',
                      ].whereType<String>().join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: item.isFavorite ? 'Remove favorite' : 'Add favorite',
                onPressed: onFavorite,
                icon: Icon(item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
