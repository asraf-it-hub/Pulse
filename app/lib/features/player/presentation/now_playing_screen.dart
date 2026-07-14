import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/models/media_item.dart';
import '../../../core/widgets/pulse_empty_state.dart';
import '../../../services/player_engine/player_engine.dart';
import '../../library/application/library_controller.dart';
import '../application/player_controller.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    required this.playerController,
    required this.libraryController,
    super.key,
  });

  final PlayerController playerController;
  final LibraryController libraryController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playerController,
      builder: (context, _) {
        final current = playerController.current;
        if (current == null) {
          return PulseEmptyState(
            icon: Icons.play_circle_outline_rounded,
            title: 'Nothing playing',
            message: 'Choose something from your library to start playback.',
            action: FilledButton.icon(
              onPressed: libraryController.importFiles,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Import Media'),
            ),
          );
        }
        return ValueListenableBuilder<PlaybackSnapshot>(
          valueListenable: playerController.snapshot,
          builder: (context, snapshot, _) {
            return CustomScrollView(
              slivers: [
                const SliverAppBar.large(title: Text('Now Playing')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final art = _ArtworkPanel(item: current, playerController: playerController);
                        final controls = _ControlsPanel(
                          item: current,
                          snapshot: snapshot,
                          playerController: playerController,
                          onFavorite: () => libraryController.toggleFavorite(current),
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Expanded(child: art), const SizedBox(width: 28), Expanded(child: controls)],
                          );
                        }
                        return Column(mainAxisSize: MainAxisSize.min, children: [art, const SizedBox(height: 20), controls]);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ArtworkPanel extends StatefulWidget {
  const _ArtworkPanel({required this.item, required this.playerController});

  final MediaItem item;
  final PlayerController playerController;

  @override
  State<_ArtworkPanel> createState() => _ArtworkPanelState();
}

class _ArtworkPanelState extends State<_ArtworkPanel> {
  VideoController? _videoController;
  String? _gestureLabel;

  @override
  void didUpdateWidget(covariant _ArtworkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerController.platformPlayer != widget.playerController.platformPlayer) {
      _videoController = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: widget.item.isVideo ? 16 / 10 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onDoubleTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 1;
            final forward = details.localPosition.dx > width / 2;
            widget.playerController.seekRelative(Duration(seconds: forward ? 10 : -10));
            _showGesture(forward ? 'Forward 10s' : 'Back 10s');
          },
          onVerticalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 1;
            final leftSide = details.localPosition.dx < width / 2;
            _showGesture(leftSide ? 'Brightness' : 'Volume');
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.28),
                      theme.colorScheme.secondary.withValues(alpha: 0.18),
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: widget.item.isVideo ? _buildVideo() : _buildAudioArt(theme),
              ),
              if (widget.item.isVideo)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Picture-in-picture',
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Picture-in-picture is prepared for platform integration.')),
                        ),
                        icon: const Icon(Icons.picture_in_picture_alt_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Fullscreen',
                        onPressed: _openFullscreen,
                        icon: const Icon(Icons.fullscreen_rounded),
                      ),
                    ],
                  ),
                ),
              AnimatedOpacity(
                opacity: _gestureLabel == null ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Text(_gestureLabel ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final player = widget.playerController.platformPlayer as mk.Player;
    _videoController ??= VideoController(player);
    return Video(controller: _videoController!, controls: AdaptiveVideoControls);
  }

  Widget _buildAudioArt(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: Image.asset('assets/brand/pulse-logo.png', width: 220, height: 220, fit: BoxFit.contain)),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Icon(Icons.graphic_eq_rounded, color: theme.colorScheme.primary, size: 42),
          ),
        ),
      ],
    );
  }

  void _showGesture(String label) {
    setState(() => _gestureLabel = label);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _gestureLabel == label) {
        setState(() => _gestureLabel = null);
      }
    });
  }

  void _openFullscreen() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(child: _buildVideo()),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_fullscreen_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.item,
    required this.snapshot,
    required this.playerController,
    required this.onFavorite,
  });

  final MediaItem item;
  final PlaybackSnapshot snapshot;
  final PlayerController playerController;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = snapshot.duration.inMilliseconds == 0 ? const Duration(seconds: 1) : snapshot.duration;
    final progress = snapshot.position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(_subtitleText(item), style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 30),
            Slider(value: progress, max: duration.inMilliseconds.toDouble(), onChanged: (value) => playerController.seekTo(Duration(milliseconds: value.round()))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_format(snapshot.position)), Text(_format(snapshot.duration))]),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(onPressed: playerController.previous, icon: const Icon(Icons.skip_previous_rounded)),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: () => playerController.seekRelative(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded)),
                const SizedBox(width: 12),
                IconButton.filled(iconSize: 36, onPressed: playerController.togglePlay, icon: Icon(snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: () => playerController.seekRelative(const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded)),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: playerController.next, icon: const Icon(Icons.skip_next_rounded)),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(selected: playerController.shuffle, onSelected: (_) => playerController.toggleShuffle(), avatar: const Icon(Icons.shuffle_rounded), label: const Text('Shuffle')),
                FilterChip(
                  selected: playerController.repeatMode != PulseRepeatMode.off,
                  onSelected: (_) => playerController.cycleRepeat(),
                  avatar: Icon(playerController.repeatMode == PulseRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
                  label: Text(playerController.repeatMode.name),
                ),
                ActionChip(avatar: const Icon(Icons.favorite_border_rounded), label: const Text('Favorite'), onPressed: onFavorite),
                ActionChip(
                  avatar: const Icon(Icons.bedtime_outlined),
                  label: Text(playerController.sleepTimerActive ? 'Cancel timer' : 'Sleep 30m'),
                  onPressed: () => playerController.sleepTimerActive ? playerController.cancelSleepTimer() : playerController.startSleepTimer(const Duration(minutes: 30)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<double>(
              initialValue: snapshot.speed,
              decoration: const InputDecoration(labelText: 'Playback speed', border: OutlineInputBorder()),
              items: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => DropdownMenuItem(value: speed, child: Text('${speed}x'))).toList(growable: false),
              onChanged: (speed) {
                if (speed != null) playerController.setSpeed(speed);
              },
            ),
            if (item.subtitleTracks.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: 'off',
                decoration: const InputDecoration(labelText: 'Subtitles', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: 'off', child: Text('Off')),
                  for (final track in item.subtitleTracks) DropdownMenuItem(value: track.uri, child: Text(track.label)),
                ],
                onChanged: (uri) {
                  final track = item.subtitleTracks.where((track) => track.uri == uri).firstOrNull;
                  playerController.setSubtitleTrack(track);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _subtitleText(MediaItem item) {
    return [
      if (item.artist != null) item.artist,
      if (item.album != null) item.album,
      item.isVideo ? 'Video playback' : 'Audio playback',
      if (item.subtitleTracks.isNotEmpty) '${item.subtitleTracks.length} subtitle track${item.subtitleTracks.length == 1 ? '' : 's'}',
    ].whereType<String>().join(' • ');
  }

  static String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

