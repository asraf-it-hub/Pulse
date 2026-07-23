import 'dart:io' as io;
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/models/media_item.dart';
import '../../../core/widgets/pulse_empty_state.dart';
import '../../player/application/player_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../player/presentation/premium_video_player_screen.dart';
import '../application/library_controller.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.libraryController,
    required this.playerController,
    required this.settingsController,
    required this.defaultTab, // 0 = Videos, 1 = Music, 2 = Playlists, 3 = Folders
    super.key,
  });

  final LibraryController libraryController;
  final PlayerController playerController;
  final SettingsController settingsController;
  final int defaultTab;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _dragging = false;

  // Folder Browser State
  String? _currentFolderPath;
  List<io.FileSystemEntity> _folderContents = [];

  // Active playlist details view state
  Playlist? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    widget.libraryController.load();
  }

  void _loadFolderContents(String path) {
    try {
      final dir = io.Directory(path);
      if (dir.existsSync()) {
        final list = dir.listSync();
        setState(() {
          _folderContents = list.where((entity) {
            final name = entity.path.toLowerCase();
            final isDir = entity is io.Directory;
            final isPlayable = name.endsWith('.mp3') ||
                name.endsWith('.mp4') ||
                name.endsWith('.wav') ||
                name.endsWith('.mkv') ||
                name.endsWith('.m4a');
            return isDir || isPlayable;
          }).toList();
          // Sort directories first, then files
          _folderContents.sort((a, b) {
            if (a is io.Directory && b is! io.Directory) return -1;
            if (a is! io.Directory && b is io.Directory) return 1;
            return a.path.toLowerCase().compareTo(b.path.toLowerCase());
          });
        });
      }
    } catch (_) {
      widget.playerController.showToast('Could not open folder');
    }
  }

  Future<void> _selectFolderToBrowse() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        setState(() {
          _currentFolderPath = path;
        });
        _loadFolderContents(path);
      }
    } catch (_) {
      widget.playerController.showToast('Error picking directory');
    }
  }

  void _playMediaItem(MediaItem item, List<MediaItem> queue) {
    widget.playerController.playItem(item, queue);
    if (item.isVideo) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: PremiumVideoPlayerScreen(
              playerController: widget.playerController,
              libraryController: widget.libraryController,
              settingsController: widget.settingsController,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAutoScanProgressBar() {
    return AnimatedBuilder(
      animation: widget.libraryController,
      builder: (context, _) {
        final syncing = widget.libraryController.syncing;
        final isFirstScan = widget.libraryController.items.isEmpty;

        return AnimatedCrossFade(
          firstChild: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isFirstScan
                            ? 'Scanning storage for the first time... (May take a few seconds)'
                            : 'Auto-scanning storage for new media...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ],
                ),
                if (isFirstScan) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: syncing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 300),
        );
      },
    );
  }

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
          Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/brand/pulse-logo.png',
                    height: 32,
                    width: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pulse',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: 'Import media',
                  onPressed: widget.libraryController.importFiles,
                  icon: const Icon(Icons.add_rounded),
                ),
                AnimatedBuilder(
                  animation: widget.libraryController,
                  builder: (context, _) {
                    final syncing = widget.libraryController.syncing;
                    return _SyncingIconButton(
                      syncing: syncing,
                      onPressed: () => widget.libraryController.refreshLibrary(forceScan: true),
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                _buildAutoScanProgressBar(),
                Expanded(child: _buildPageContent()),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: !_dragging
                ? const SizedBox.shrink()
                : Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.upload_file_rounded,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Drop media or folders to import',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  BoxFit classOfLogoFit() {
    return BoxFit.contain;
  }

  Widget _buildPageContent() {
    switch (widget.defaultTab) {
      case 0:
        return _buildTracksTab(isVideoOnly: true);
      case 1:
        return _buildTracksTab(isVideoOnly: false);
      case 2:
        return _buildPlaylistsTab();
      case 3:
        return _buildFoldersTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTracksTab({required bool isVideoOnly}) {
    return AnimatedBuilder(
      animation: widget.libraryController,
      builder: (context, _) {
        if (widget.libraryController.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.libraryController.error != null) {
          return PulseEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            message: widget.libraryController.error!,
            action: FilledButton.icon(
              onPressed: widget.libraryController.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
        }

        final visibleItems = widget.libraryController.visibleItems
            .where((item) => item.isVideo == isVideoOnly)
            .toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                firstCurve: Curves.easeInOutCubic,
                secondCurve: Curves.easeInOutCubic,
                crossFadeState: widget.libraryController.syncing
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Syncing library folders...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _LibraryToolbar(
                  controller: widget.libraryController,
                  onShufflePlay: isVideoOnly
                      ? null
                      : () {
                          final tracks = visibleItems.toList();
                          if (tracks.isNotEmpty) {
                            tracks.shuffle();
                            widget.playerController.playItem(tracks.first, tracks);
                          }
                        },
                ),
              ),
            ),
            if (visibleItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PulseEmptyState(
                  icon: isVideoOnly ? Icons.video_library_outlined : Icons.library_music_outlined,
                  title: isVideoOnly ? 'No videos found' : 'No music found',
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
                    mainAxisExtent: 110,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return _MediaTile(
                      item: item,
                      playerController: widget.playerController,
                      libraryController: widget.libraryController,
                      onTap: () {
                        final queue = widget.playerController.shuffle ? visibleItems : [item];
                        _playMediaItem(item, queue);
                      },
                      onFavorite: () => widget.libraryController.toggleFavorite(item),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return AnimatedBuilder(
      animation: widget.libraryController,
      builder: (context, _) {
        final playlists = widget.libraryController.playlists;

        if (_selectedPlaylist != null) {
          // Verify it still exists
          final pIndex = playlists.indexWhere((p) => p.id == _selectedPlaylist!.id);
          if (pIndex == -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedPlaylist = null;
              });
            });
            return const SizedBox.shrink();
          }
          final activePlaylist = playlists[pIndex];
          final playlistTracks = activePlaylist.itemIds
              .map((id) => widget.libraryController.items.where((item) => item.id == id).firstOrNull)
              .whereType<MediaItem>()
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() => _selectedPlaylist = null),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(activePlaylist.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('${playlistTracks.length} tracks', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (playlistTracks.isNotEmpty)
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All'),
                        onPressed: () => _playMediaItem(playlistTracks.first, playlistTracks),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: playlistTracks.isEmpty
                    ? Center(
                        child: Text(
                          'No tracks in this playlist',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: playlistTracks.length,
                        itemBuilder: (context, index) {
                          final item = playlistTracks[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: Icon(item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded),
                                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(item.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                  onPressed: () => widget.libraryController.removeTrackFromPlaylist(activePlaylist.id, item.id),
                                ),
                                onTap: () => _playMediaItem(item, playlistTracks),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Your Playlists', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Playlist'),
                      onPressed: () => _showCreatePlaylistDialog(context),
                    ),
                  ],
                ),
              ),
            ),
            if (playlists.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Create a playlist to start organizing your media.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final theme = Theme.of(context);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => _selectedPlaylist = playlist),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.playlist_play_rounded, size: 36),
                              const Spacer(),
                              Text(
                                playlist.name,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${playlist.itemIds.length} items',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    onPressed: () => _showRenamePlaylistDialog(context, playlist),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    onPressed: () => widget.libraryController.deletePlaylist(playlist.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFoldersTab() {
    final theme = Theme.of(context);

    if (_currentFolderPath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 72, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'Browse Local Directory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a folder to browse and play media files.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose Folder'),
              onPressed: _selectFolderToBrowse,
            ),
          ],
        ),
      );
    }

    final pathSegments = _currentFolderPath!.split(io.Platform.pathSeparator);
    final visiblePath = pathSegments.length > 3
        ? '... / ${pathSegments.sublist(pathSegments.length - 3).join(' / ')}'
        : _currentFolderPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Go up a folder',
                onPressed: () {
                  final parent = io.Directory(_currentFolderPath!).parent;
                  if (parent.path != _currentFolderPath) {
                    setState(() {
                      _currentFolderPath = parent.path;
                    });
                    _loadFolderContents(parent.path);
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visiblePath ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open_rounded),
                tooltip: 'Change Folder',
                onPressed: _selectFolderToBrowse,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _folderContents.isEmpty
              ? const Center(child: Text('No playable media in this directory'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: _folderContents.length,
                  itemBuilder: (context, index) {
                    final entity = _folderContents[index];
                    final isDir = entity is io.Directory;
                    final name = entity.path.split(io.Platform.pathSeparator).last;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(isDir ? Icons.folder_rounded : (name.endsWith('.mp4') || name.endsWith('.mkv') ? Icons.movie_rounded : Icons.music_note_rounded)),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: isDir ? const Icon(Icons.chevron_right_rounded) : null,
                          onTap: () {
                            if (isDir) {
                              setState(() {
                                _currentFolderPath = entity.path;
                              });
                              _loadFolderContents(entity.path);
                            } else {
                              final fileItem = MediaItem(
                                id: entity.path,
                                title: name,
                                uri: entity.path,
                                kind: name.endsWith('.mp4') || name.endsWith('.mkv') ? MediaKind.video : MediaKind.audio,
                              );
                              _playMediaItem(fileItem, [fileItem]);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  widget.libraryController.createPlaylist(name);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, Playlist playlist) {
    final textController = TextEditingController(text: playlist.name);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Playlist'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'New Playlist Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  widget.libraryController.renamePlaylist(playlist.id, name);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.controller,
    this.onShufflePlay,
  });

  final LibraryController controller;
  final VoidCallback? onShufflePlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        children: [
          TextField(
            onChanged: controller.setQuery,
            decoration: const InputDecoration(
              hintText: 'Search title, album, artist',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
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
                if (onShufflePlay != null) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onShufflePlay,
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: const Text('Shuffle Play'),
                  ),
                ],
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
    required this.playerController,
    required this.libraryController,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final PlayerController playerController;
  final LibraryController libraryController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _buildLeading(theme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (item.artist != null) item.artist,
                        if (item.album != null) item.album,
                        if (item.artist == null && item.album == null) item.isVideo ? 'Video' : 'Audio',
                      ].whereType<String>().join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: item.isFavorite ? 'Remove favorite' : 'Add favorite',
                onPressed: onFavorite,
                iconSize: 20,
                icon: Icon(item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (value) {
                  if (value == 'play_next') {
                    playerController.playNext(item);
                  } else if (value == 'add_queue') {
                    playerController.addToQueue(item);
                  } else if (value == 'add_playlist') {
                    _showAddToPlaylistDialog(context);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'play_next', child: Text('Play Next')),
                  PopupMenuItem(value: 'add_queue', child: Text('Add to Queue')),
                  PopupMenuItem(value: 'add_playlist', child: Text('Add to Playlist')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(ThemeData theme) {
    Widget leadingWidget = _buildPlaceholder(theme);
    if (!kIsWeb && item.thumbnailUri != null && item.thumbnailUri!.isNotEmpty) {
      final file = io.File(item.thumbnailUri!);
      try {
        if (file.existsSync()) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              file,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
            ),
          );
        }
      } catch (_) {}
    }
    return Hero(
      tag: 'video-hero-${item.id}',
      child: leadingWidget,
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer]),
      ),
      child: Icon(item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded, size: 24),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Add to Playlist'),
          content: ListenableBuilder(
            listenable: libraryController,
            builder: (context, _) {
              final playlists = libraryController.playlists;
              return SizedBox(
                width: 320,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_rounded),
                      title: const Text('New Playlist'),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreatePlaylistDialog(context);
                      },
                    ),
                    const Divider(),
                    if (playlists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No playlists yet',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    for (final playlist in playlists)
                      ListTile(
                        leading: const Icon(Icons.playlist_play_rounded),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.itemIds.length} tracks'),
                        onTap: () {
                          libraryController.addTrackToPlaylist(playlist.id, item.id);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  final oldIds = libraryController.playlists.map((p) => p.id).toSet();
                  await libraryController.createPlaylist(name);
                  final newPlaylist = libraryController.playlists.firstWhere((p) => !oldIds.contains(p.id));
                  await libraryController.addTrackToPlaylist(newPlaylist.id, item.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

class _SyncingIconButton extends StatefulWidget {
  const _SyncingIconButton({required this.syncing, required this.onPressed});
  final bool syncing;
  final VoidCallback onPressed;

  @override
  State<_SyncingIconButton> createState() => _SyncingIconButtonState();
}

class _SyncingIconButtonState extends State<_SyncingIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.syncing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SyncingIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing != oldWidget.syncing) {
      if (widget.syncing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotationController,
      child: IconButton(
        tooltip: 'Refresh library',
        onPressed: widget.syncing ? null : widget.onPressed,
        icon: const Icon(Icons.sync_rounded),
      ),
    );
  }
}
