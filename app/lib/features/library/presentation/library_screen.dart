import 'package:flutter/material.dart';

import '../../../core/models/media_item.dart';
import '../../../core/widgets/pulse_empty_state.dart';
import '../../player/application/player_controller.dart';
import '../application/library_controller.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    required this.libraryController,
    required this.playerController,
    super.key,
  });

  final LibraryController libraryController;
  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: libraryController,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Library'),
              floating: true,
              actions: [
                IconButton(
                  tooltip: 'Import media',
                  onPressed: libraryController.importFiles,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _LibraryToolbar(controller: libraryController)),
            if (libraryController.loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (libraryController.error != null)
              SliverFillRemaining(
                child: PulseEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  message: libraryController.error!,
                  action: FilledButton.icon(
                    onPressed: libraryController.load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              )
            else if (libraryController.visibleItems.isEmpty)
              SliverFillRemaining(
                child: PulseEmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'Build your library',
                  message: 'Import audio and video files to start playing them with Pulse.',
                  action: FilledButton.icon(
                    onPressed: libraryController.importFiles,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Import Media'),
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
                  itemCount: libraryController.visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = libraryController.visibleItems[index];
                    return _MediaTile(
                      item: item,
                      onTap: () => playerController.playItem(item, libraryController.visibleItems),
                      onFavorite: () => libraryController.toggleFavorite(item),
                    );
                  },
                ),
              ),
          ],
        );
      },
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
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer],
                  ),
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
                      item.isVideo ? 'Video' : 'Audio',
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
