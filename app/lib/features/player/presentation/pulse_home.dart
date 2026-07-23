import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/models/media_item.dart';
import 'player_intents.dart';
import 'play_pause_morph_button.dart';

import '../../library/application/library_controller.dart';
import '../../library/presentation/library_screen.dart';
import '../../radio/presentation/radio_screen.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/player_controller.dart';
import '../../../core/widgets/animated_waveform_seek_bar.dart';
import '../../../core/widgets/animated_audio_visualizer.dart';
import '../../../services/player_engine/player_engine.dart';
import 'equalizer_sheet.dart';
import 'now_playing_screen.dart';
import 'premium_video_player_screen.dart';

class PulseHome extends StatefulWidget {
  const PulseHome({
    required this.settingsController,
    required this.libraryController,
    required this.playerController,
    super.key,
  });

  final SettingsController settingsController;
  final LibraryController libraryController;
  final PlayerController playerController;

  @override
  State<PulseHome> createState() => _PulseHomeState();
}

class _PulseHomeState extends State<PulseHome> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _panelController;

  // Splash & Resume States
  bool _showSplash = true;
  bool _showResumePrompt = false;
  String? _resumeTitle;
  String? _resumeId;
  int? _resumePositionMs;
  bool? _resumeIsVideo;

  @override
  void initState() {
    super.initState();
    widget.playerController.addListener(_onPlayerChanged);
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // Splash screen timer
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });

    _checkResumeState();
  }

  Timer? _resumeDismissTimer;

  @override
  void dispose() {
    widget.playerController.removeListener(_onPlayerChanged);
    _panelController.dispose();
    _resumeDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkResumeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('resume_id');
      final title = prefs.getString('resume_title');
      final pos = prefs.getInt('resume_position');
      final isVideo = prefs.getBool('resume_is_video');

      if (id != null && title != null && pos != null && isVideo != null) {
        setState(() {
          _resumeId = id;
          _resumeTitle = title;
          _resumePositionMs = pos;
          _resumeIsVideo = isVideo;
          _showResumePrompt = true;
        });
        _resumeDismissTimer?.cancel();
        _resumeDismissTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() {
              _showResumePrompt = false;
            });
            widget.playerController.clearResumeState();
          }
        });
      }
    } catch (_) {}
  }

  void _onPlayerChanged() {
    // Tapping music does not auto-expand the player drawer anymore.
  }

  Future<void> _toggleFullscreen() async {
    final current = widget.playerController.current;
    if (current != null && current.isVideo) {
      if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
        try {
          final isFull = await windowManager.isFullScreen();
          await windowManager.setFullScreen(!isFull);
        } catch (_) {}
      }
      if (!mounted) return;
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null && modalRoute.settings.name == '/premium_video_player') {
        // already on video route
      } else {
        Navigator.of(context).push(PageRouteBuilder<void>(
          settings: const RouteSettings(name: '/premium_video_player'),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: PremiumVideoPlayerScreen(
              playerController: widget.playerController,
              libraryController: widget.libraryController,
              settingsController: widget.settingsController,
            ),
          ),
        ));
      }
    }
  }

  Widget _buildArtworkBackground(MediaItem item) {
    if (!kIsWeb && item.thumbnailUri != null && item.thumbnailUri!.isNotEmpty) {
      final file = io.File(item.thumbnailUri!);
      try {
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
    }
    return Image.asset(
      'assets/brand/pulse-logo.png',
      fit: BoxFit.cover,
    );
  }

  Widget _buildArtworkThumbnail(MediaItem item) {
    if (!kIsWeb && item.thumbnailUri != null && item.thumbnailUri!.isNotEmpty) {
      final file = io.File(item.thumbnailUri!);
      try {
        if (file.existsSync()) {
          return Image.file(file, width: 44, height: 44, fit: BoxFit.cover);
        }
      } catch (_) {}
    }
    return Container(
      width: 44,
      height: 44,
      color: Colors.white10,
      child: const Icon(Icons.music_note_rounded, size: 20),
    );
  }

  Widget _buildArtwork(bool isVideo, bool isExpanded, ThemeData theme, MediaItem item) {
    if (isVideo) {
      final fit = widget.playerController.videoFit;
      final aspect = widget.playerController.videoAspectRatio;

      Widget videoWidget = Video(
        controller: widget.playerController.videoController,
        controls: isExpanded ? AdaptiveVideoControls : NoVideoControls,
        fit: fit,
      );

      if (aspect != null && isExpanded) {
        videoWidget = AspectRatio(
          aspectRatio: aspect,
          child: videoWidget,
        );
      }

      return Center(child: videoWidget);
    }

    Widget artwork = Center(child: Image.asset('assets/brand/pulse-logo.png', width: 220, height: 220, fit: BoxFit.contain));

    if (!kIsWeb && item.thumbnailUri != null && item.thumbnailUri!.isNotEmpty) {
      final file = io.File(item.thumbnailUri!);
      try {
        if (file.existsSync()) {
          artwork = Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        artwork,
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(lerpDouble(6.0, 24.0, _panelController.value)!),
            child: ClipOval(
              child: ColoredBox(
                color: Colors.black45,
                child: Padding(
                  padding: EdgeInsets.all(lerpDouble(4.0, 12.0, _panelController.value)!),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.colorScheme.primary,
                    size: lerpDouble(12.0, 32.0, _panelController.value)!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie_rounded), label: 'Video'),
      const NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note_rounded), label: 'Music'),
      const NavigationDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_fill_rounded), label: 'Player'),
      const NavigationDestination(icon: Icon(Icons.playlist_play_rounded), selectedIcon: Icon(Icons.playlist_play_rounded), label: 'Playlists'),
      const NavigationDestination(icon: Icon(Icons.folder_open_rounded), selectedIcon: Icon(Icons.folder_rounded), label: 'Folders'),
      const NavigationDestination(icon: Icon(Icons.radio_outlined), selectedIcon: Icon(Icons.radio_rounded), label: 'Radio'),
      const NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
    ];

    final pages = [
      LibraryScreen(
        libraryController: widget.libraryController,
        playerController: widget.playerController,
        settingsController: widget.settingsController,
        defaultTab: 0,
      ),
      LibraryScreen(
        libraryController: widget.libraryController,
        playerController: widget.playerController,
        settingsController: widget.settingsController,
        defaultTab: 1,
      ),
      NowPlayingScreen(
        playerController: widget.playerController,
        libraryController: widget.libraryController,
        settingsController: widget.settingsController,
      ),
      LibraryScreen(
        libraryController: widget.libraryController,
        playerController: widget.playerController,
        settingsController: widget.settingsController,
        defaultTab: 2,
      ),
      LibraryScreen(
        libraryController: widget.libraryController,
        playerController: widget.playerController,
        settingsController: widget.settingsController,
        defaultTab: 3,
      ),
      RadioScreen(playerController: widget.playerController),
      SettingsScreen(settingsController: widget.settingsController),
    ];

    return DropTarget(
      onDragDone: (details) async {
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          await widget.libraryController.importPaths(paths);
          final imported = widget.libraryController.items
              .where((i) => paths.contains(i.uri))
              .toList();
          if (imported.isNotEmpty) {
            widget.playerController.playItem(
              imported.first,
              widget.libraryController.items,
            );
          }
        }
      },
      child: Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyO, control: true): ImportFilesIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, control: true, shift: true): ScanFolderIntent(),
        SingleActivator(LogicalKeyboardKey.space): TogglePlaybackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): SeekBackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): SeekForwardIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): VolumeUpIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): VolumeDownIntent(),
        SingleActivator(LogicalKeyboardKey.keyM): ToggleMuteIntent(),
        SingleActivator(LogicalKeyboardKey.keyF): ToggleFullscreenIntent(),
      },
      child: Actions(
        actions: {
          ImportFilesIntent: CallbackAction<ImportFilesIntent>(onInvoke: (_) => widget.libraryController.importFiles()),
          ScanFolderIntent: CallbackAction<ScanFolderIntent>(onInvoke: (_) => widget.libraryController.importFolder()),
          TogglePlaybackIntent: CallbackAction<TogglePlaybackIntent>(onInvoke: (_) => widget.playerController.togglePlay()),
          SeekBackIntent: CallbackAction<SeekBackIntent>(onInvoke: (_) {
            final seconds = widget.settingsController.settings.skipDuration;
            widget.playerController.seekRelative(Duration(seconds: -seconds.round()));
            return null;
          }),
          SeekForwardIntent: CallbackAction<SeekForwardIntent>(onInvoke: (_) {
            final seconds = widget.settingsController.settings.skipDuration;
            widget.playerController.seekRelative(Duration(seconds: seconds.round()));
            return null;
          }),
          VolumeUpIntent: CallbackAction<VolumeUpIntent>(onInvoke: (_) {
            final step = widget.settingsController.settings.volumeStep;
            widget.playerController.setVolume((widget.playerController.snapshot.value.volume + step).clamp(0.0, 1.0));
            return null;
          }),
          VolumeDownIntent: CallbackAction<VolumeDownIntent>(onInvoke: (_) {
            final step = widget.settingsController.settings.volumeStep;
            widget.playerController.setVolume((widget.playerController.snapshot.value.volume - step).clamp(0.0, 1.0));
            return null;
          }),
          ToggleMuteIntent: CallbackAction<ToggleMuteIntent>(onInvoke: (_) => widget.playerController.toggleMute()),
          ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(onInvoke: (_) => _toggleFullscreen()),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final content = AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
              );

              Widget mainLayout;
              if (wide) {
                mainLayout = Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        extended: constraints.maxWidth >= 1180,
                        selectedIndex: _index,
                        onDestinationSelected: (value) => setState(() => _index = value),
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 18),
                          child: Image.asset('assets/brand/pulse-logo.png', width: 44, height: 44),
                        ),
                        destinations: const [
                          NavigationRailDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie_rounded), label: Text('Video')),
                          NavigationRailDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note_rounded), label: Text('Music')),
                          NavigationRailDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_fill_rounded), label: Text('Player')),
                          NavigationRailDestination(icon: Icon(Icons.playlist_play_rounded), selectedIcon: Icon(Icons.playlist_play_rounded), label: Text('Playlists')),
                          NavigationRailDestination(icon: Icon(Icons.folder_open_rounded), selectedIcon: Icon(Icons.folder_rounded), label: Text('Folders')),
                          NavigationRailDestination(icon: Icon(Icons.radio_outlined), selectedIcon: Icon(Icons.radio_rounded), label: Text('Radio')),
                          NavigationRailDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: Text('Settings')),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  ),
                );
              } else {
                mainLayout = Scaffold(
                  body: content,
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (value) => setState(() => _index = value),
                    destinations: destinations,
                  ),
                );
              }

              return Stack(
                children: [
                  mainLayout,

                  // Sliding Now Playing Panel (Audio only)
                  ListenableBuilder(
                    listenable: Listenable.merge([_panelController, widget.playerController]),
                    builder: (context, _) {
                      final current = widget.playerController.current;
                      if (current == null || current.isVideo) return const SizedBox.shrink();

                      final value = _panelController.value;
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final bottomPadding = MediaQuery.of(context).padding.bottom;

                      final railWidth = wide ? (constraints.maxWidth >= 1180 ? 256.0 : 72.0) : 0.0;
                      final double bottomOffset = lerpDouble(wide ? 0.0 : 80.0 + bottomPadding, 0.0, value)!;
                      final double leftOffset = lerpDouble(railWidth, 0.0, value)!;
                      final double panelWidth = lerpDouble(screenWidth - railWidth, screenWidth, value)!;
                      final double panelHeight = lerpDouble(72.0, screenHeight, value)!;

                      final double fullArtworkSize = wide ? 400.0 : screenWidth - 40.0;
                      final double fullArtworkLeft = (panelWidth - fullArtworkSize) / 2;
                      final double fullArtworkTop = wide ? 100.0 : 80.0;

                      final double artSize = lerpDouble(44.0, fullArtworkSize, value)!;
                      final double artLeft = lerpDouble(16.0, fullArtworkLeft, value)!;
                      final double artTop = lerpDouble(14.0, fullArtworkTop, value)!;
                      final double artRadius = lerpDouble(8.0, 24.0, value)!;

                      return ValueListenableBuilder<PlaybackSnapshot>(
                        valueListenable: widget.playerController.snapshot,
                        builder: (context, snapshot, _) {
                          return Positioned(
                            left: leftOffset,
                            bottom: bottomOffset,
                            width: panelWidth,
                            height: panelHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(lerpDouble(12.0, 0.0, value)!),
                                topRight: Radius.circular(lerpDouble(12.0, 0.0, value)!),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainer,
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                     if (value > 0.01)
                                       Positioned.fill(
                                         child: Opacity(
                                           opacity: value,
                                           child: ClipRect(
                                             child: Stack(
                                               fit: StackFit.expand,
                                               children: [
                                                 _buildArtworkBackground(current),
                                                 BackdropFilter(
                                                   filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                                   child: Container(
                                                     decoration: BoxDecoration(
                                                       gradient: LinearGradient(
                                                         begin: Alignment.topCenter,
                                                         end: Alignment.bottomCenter,
                                                         colors: [
                                                           Colors.black.withValues(alpha: 0.10),
                                                           Colors.black.withValues(alpha: 0.25),
                                                           Colors.black.withValues(alpha: 0.40),
                                                         ],
                                                       ),
                                                     ),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ),
                                       ),
                                    if (value > 0.1)
                                      Positioned.fill(
                                        top: 64,
                                        child: Opacity(
                                          opacity: ((value - 0.2) * 1.25).clamp(0.0, 1.0),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: Column(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'Queue (${widget.playerController.queue.length})',
                                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                      ),
                                                      const Spacer(),
                                                      FilledButton.tonalIcon(
                                                        onPressed: () {
                                                          showModalBottomSheet<void>(
                                                            context: context,
                                                            isScrollControlled: true,
                                                            useSafeArea: true,
                                                            shape: const RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                                            ),
                                                            builder: (context) => EqualizerSheet(playerController: widget.playerController),
                                                          );
                                                        },
                                                        icon: const Icon(Icons.tune_rounded, size: 18),
                                                        label: const Text('Equalizer (EQ)'),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (widget.playerController.queue.length > 1)
                                                        TextButton.icon(
                                                          onPressed: widget.playerController.clearQueue,
                                                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                                                          label: const Text('Clear'),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                Expanded(
                                                  child: widget.playerController.queue.isEmpty
                                                      ? Center(
                                                          child: Text(
                                                            'Queue is empty',
                                                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                                          ),
                                                        )
                                                      : ReorderableListView.builder(
                                                          padding: const EdgeInsets.only(bottom: 120),
                                                          itemCount: widget.playerController.queue.length,
                                                          // ignore: deprecated_member_use
                                                          onReorder: widget.playerController.reorderQueue,
                                                          itemBuilder: (context, index) {
                                                            final queue = widget.playerController.queue;
                                                            final item = queue[index];
                                                            final isCurrent = current.id == item.id;

                                                            return Material(
                                                              key: ValueKey(item.id),
                                                              color: Colors.transparent,
                                                              child: ListTile(
                                                                leading: SizedBox(
                                                                  width: 44,
                                                                  height: 44,
                                                                  child: Stack(
                                                                    alignment: Alignment.center,
                                                                    children: [
                                                                      ClipRRect(
                                                                        borderRadius: BorderRadius.circular(6),
                                                                        child: _buildArtworkThumbnail(item),
                                                                      ),
                                                                      if (isCurrent)
                                                                        Positioned.fill(
                                                                          child: Container(
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.black45,
                                                                              borderRadius: BorderRadius.circular(6),
                                                                            ),
                                                                            child: Center(
                                                                              child: snapshot.playing
                                                                                  ? const PlayingWavesIndicator()
                                                                                  : Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 20),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                title: Text(
                                                                  item.title,
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                                    color: isCurrent ? theme.colorScheme.primary : null,
                                                                  ),
                                                                ),
                                                                subtitle: Text(
                                                                  item.artist ?? 'Unknown Artist',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                trailing: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    if (!isCurrent)
                                                                      IconButton(
                                                                        icon: const Icon(Icons.remove_circle_outline_rounded),
                                                                        onPressed: () => widget.playerController.removeFromQueue(item.id),
                                                                      ),
                                                                    ReorderableDragStartListener(
                                                                      index: index,
                                                                      child: const Icon(Icons.drag_handle_rounded),
                                                                    ),
                                                                  ],
                                                                ),
                                                                onTap: () {
                                                                  widget.playerController.playItem(item, queue);
                                                                },
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (value < 0.2)
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTap: () => _panelController.forward(),
                                          onVerticalDragUpdate: (details) {
                                            _panelController.value -= details.primaryDelta! / screenHeight;
                                          },
                                          onVerticalDragEnd: (details) {
                                            if (_panelController.value > 0.1 || details.primaryVelocity! < -200) {
                                              _panelController.forward();
                                            } else {
                                              _panelController.reverse();
                                            }
                                          },
                                          child: const MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: ColoredBox(color: Colors.transparent),
                                          ),
                                        ),
                                      ),
                                    if (value < 0.9)
                                      Positioned(
                                        left: artLeft + artSize + 12,
                                        right: 16,
                                        top: 0,
                                        bottom: 0,
                                        child: Opacity(
                                          opacity: (1.0 - value * 3.0).clamp(0.0, 1.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _index = 2;
                                                    });
                                                  },
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              current.title,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                            ),
                                                            if (current.artist != null)
                                                              Text(
                                                                current.artist!,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 42,
                                                        height: 24,
                                                        child: AnimatedAudioVisualizer(
                                                          isPlaying: snapshot.playing,
                                                          barCount: 8,
                                                          color: theme.colorScheme.primary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.skip_previous_rounded, size: 24),
                                                onPressed: widget.playerController.previous,
                                              ),
                                              const SizedBox(width: 4),
                                              PlayPauseMorphButton(
                                                playing: snapshot.playing,
                                                onPressed: widget.playerController.togglePlay,
                                                iconSize: 24,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.skip_next_rounded, size: 24),
                                                onPressed: widget.playerController.next,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 22),
                                                onPressed: () {
                                                  widget.playerController.pause();
                                                  widget.playerController.clearQueue();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (value < 0.2)
                                      Positioned(
                                        left: artLeft,
                                        top: artTop,
                                        width: artSize,
                                        height: artSize,
                                        child: Opacity(
                                          opacity: (1.0 - value * 5.0).clamp(0.0, 1.0),
                                          child: GestureDetector(
                                            onTap: () => _panelController.forward(),
                                            child: Hero(
                                              tag: 'fullscreen-video',
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(artRadius),
                                                child: Container(
                                                  color: Colors.black,
                                                  child: _buildArtwork(false, false, theme, current),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (value > 0.8)
                                      Positioned(
                                        top: 12,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: GestureDetector(
                                            onVerticalDragUpdate: (details) {
                                              _panelController.value -= details.primaryDelta! / screenHeight;
                                            },
                                            onVerticalDragEnd: (details) {
                                              if (_panelController.value < 0.8) {
                                                _panelController.reverse();
                                              } else {
                                                _panelController.forward();
                                              }
                                            },
                                            child: Container(
                                              width: 40,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: Colors.white30,
                                                borderRadius: BorderRadius.circular(99),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (value > 0.8)
                                      Positioned(
                                        top: 24,
                                        right: 20,
                                        child: Opacity(
                                          opacity: ((value - 0.8) * 5.0).clamp(0.0, 1.0),
                                          child: IconButton.filledTonal(
                                            onPressed: () => _panelController.reverse(),
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                                          ),
                                        ),
                                      ),


                                     // Animated Waveform Seek Bar at bottom of mini-player
                                     if (value < 0.1)
                                       Positioned(
                                         bottom: 0,
                                         left: 0,
                                         right: 0,
                                         height: 18,
                                         child: AnimatedWaveformSeekBar(
                                           position: snapshot.position,
                                           duration: snapshot.duration,
                                           playing: snapshot.playing,
                                           activeColor: theme.colorScheme.primary,
                                           inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.22),
                                           onSeek: widget.playerController.seekTo,
                                         ),
                                       ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Continuation/Resume Dialog Banner overlay
                  if (_showResumePrompt && !_showSplash)
                    Positioned(
                      bottom: wide ? 24 : 96,
                      left: 20,
                      right: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.28)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _resumeIsVideo == true ? Icons.movie_rounded : Icons.music_note_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Resume playback?',
                                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _resumeTitle ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    _resumeDismissTimer?.cancel();
                                    setState(() {
                                      _showResumePrompt = false;
                                    });
                                    widget.playerController.clearResumeState();
                                  },
                                  child: const Text('Dismiss'),
                                ),
                                FilledButton(
                                  onPressed: () async {
                                    _resumeDismissTimer?.cancel();
                                    setState(() {
                                      _showResumePrompt = false;
                                    });
                                    final items = widget.libraryController.items;
                                    final matched = items.where((item) => item.id == _resumeId).firstOrNull;
                                    if (matched != null) {
                                      widget.playerController.resumeItemAtPosition(
                                        matched,
                                        [matched],
                                        Duration(milliseconds: _resumePositionMs ?? 0),
                                      );
                                      if (_resumeIsVideo == true) {
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
                                    widget.playerController.clearResumeState();
                                  },
                                  child: const Text('Resume'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Open App Splash & Scan Animation
                  if (_showSplash)
                    Positioned.fill(
                      child: Container(
                        color: theme.scaffoldBackgroundColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/brand/pulse-logo.png', width: 120, height: 120, fit: BoxFit.contain),
                              const SizedBox(height: 32),
                              const SizedBox(
                                width: 160,
                                child: LinearProgressIndicator(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Scanning media library...',
                                style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
}

class PulseMusicVisualizer extends StatefulWidget {
  const PulseMusicVisualizer({
    required this.playerController,
    required this.isPlaying,
    required this.volume,
    required this.baseColor,
    required this.accentColor,
    required this.artworkWidget,
    super.key,
  });

  final PlayerController playerController;
  final bool isPlaying;
  final double volume;
  final Color baseColor;
  final Color accentColor;
  final Widget artworkWidget;

  @override
  State<PulseMusicVisualizer> createState() => _PulseMusicVisualizerState();
}

class _PulseMusicVisualizerState extends State<PulseMusicVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sound waves, rings, and particles painter
          Positioned.fill(
            child: CustomPaint(
              painter: VisualizerPainter(
                animationValue: _controller.value,
                isPlaying: widget.isPlaying,
                volume: widget.volume,
                accentColor: widget.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VisualizerPainter extends CustomPainter {
  VisualizerPainter({
    required this.animationValue,
    required this.isPlaying,
    required this.volume,
    required this.accentColor,
  });

  final double animationValue;
  final bool isPlaying;
  final double volume;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 80.0);
    final themeAngle = animationValue * 2 * math.pi;

    // 1. Radial glow behind artwork (Bass makes it swell and glow stronger)
    final bassIntensity = isPlaying ? (math.sin(themeAngle * 5.0) + 1.0) / 2.0 : 0.2;
    final glowRadius = 170.0 + bassIntensity * 25.0 * volume;
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    canvas.drawCircle(
      center,
      glowRadius,
      glowPaint..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.20 + bassIntensity * 0.15),
          accentColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // 2. Concentric Energy Rings with varying blur/glow
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3); // Soft blurred edge for premium feel

    // Inner ring (Slow drift)
    canvas.drawCircle(
      center,
      84.0 + math.sin(themeAngle) * 2.0,
      ringPaint..color = accentColor.withValues(alpha: 0.25),
    );

    // Middle ring (Vocal vibration)
    canvas.drawCircle(
      center,
      104.0 + (isPlaying ? math.cos(themeAngle * 2.5) * 4.0 : 0.0),
      ringPaint..color = accentColor.withValues(alpha: 0.15),
    );

    // Outer ring (Bass pulse)
    canvas.drawCircle(
      center,
      125.0 + (isPlaying ? bassIntensity * 8.0 * volume : 0.0),
      ringPaint..color = accentColor.withValues(alpha: 0.10),
    );

    // 3. Sound Waves coming as bass movement directly from the center circle (radius 70.0)
    final wavePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final wavePath = Path();
    const int pointsCount = 90;
    // Base radius is just outside the 70.0 radius of the artwork (140 diameter)
    final double baseRadius = 74.0 + (isPlaying ? bassIntensity * 6.0 * volume : 0.0);

    for (int i = 0; i <= pointsCount; i++) {
      final double angle = (i / pointsCount) * 2 * math.pi;

      double waveDisplacement = 0.0;
      if (isPlaying) {
        // High frequency ripple + vocal vibration + heavy bass swell
        final bassSwell = math.sin(themeAngle * 4.0 + angle * 2) * 8.0 * volume;
        final vocalVibe = math.cos(themeAngle * 10.0 + angle * 5) * 4.0 * volume;
        final trebleRipple = math.sin(themeAngle * 22.0 + angle * 12) * 1.8 * volume;
        waveDisplacement = bassSwell + vocalVibe + trebleRipple;
      }

      final double r = baseRadius + waveDisplacement;
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;

      if (i == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);

    // Draw a secondary outer wave for depth
    final outerWavePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final outerWavePath = Path();
    final double outerBaseRadius = 110.0 + (isPlaying ? bassIntensity * 10.0 * volume : 0.0);

    for (int i = 0; i <= pointsCount; i++) {
      final double angle = (i / pointsCount) * 2 * math.pi;
      double waveDisplacement = 0.0;
      if (isPlaying) {
        final bassSwell = math.cos(themeAngle * 3.0 + angle * 3) * 10.0 * volume;
        final trebleRipple = math.sin(themeAngle * 15.0 + angle * 8) * 3.0 * volume;
        waveDisplacement = bassSwell + trebleRipple;
      }
      final double r = outerBaseRadius + waveDisplacement;
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;

      if (i == 0) {
        outerWavePath.moveTo(x, y);
      } else {
        outerWavePath.lineTo(x, y);
      }
    }
    outerWavePath.close();
    canvas.drawPath(outerWavePath, outerWavePaint);

    // 4. Particle system with soft blur and orbits
    final particlePaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    for (int i = 0; i < 30; i++) {
      final seed = i * 73.51;
      final speed = 0.2 + (i % 4) * 0.1;
      final angle = (seed + themeAngle * speed) % (2 * math.pi);
      final radiusDist = 95.0 + (i % 6) * 30.0 + (isPlaying ? math.sin(themeAngle * 1.5 + seed) * 10.0 : 0.0);
      final px = center.dx + math.cos(angle) * radiusDist;
      final py = center.dy + math.sin(angle) * radiusDist;
      final size = 1.5 + (i % 2);
      final opacity = 0.15 + (math.sin(angle * 2.0) + 1.0) / 2.0 * 0.45;

      canvas.drawCircle(
        Offset(px, py),
        size,
        particlePaint..color = accentColor.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.volume != volume ||
        oldDelegate.accentColor != accentColor;
  }
}

class PlayingWavesIndicator extends StatefulWidget {
  const PlayingWavesIndicator({super.key});

  @override
  State<PlayingWavesIndicator> createState() => _PlayingWavesIndicatorState();
}

class _PlayingWavesIndicatorState extends State<PlayingWavesIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 24,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final double progress = (_controller.value + (index * 0.33)) % 1.0;
              final double bounce = (progress - 0.5).abs() * 2.0;
              final double height = 4.0 + (bounce * 14.0);
              return Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
