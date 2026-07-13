import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
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
                SliverFillRemaining(
                  hasScrollBody: false,
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
                            children: [
                              Expanded(child: art),
                              const SizedBox(width: 28),
                              Expanded(child: controls),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            art,
                            const SizedBox(height: 20),
                            controls,
                          ],
                        );
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
        child: DecoratedBox(
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
      ),
    );
  }

  Widget _buildVideo() {
    final player = widget.playerController.platformPlayer as Player;
    _videoController ??= VideoController(player);
    return Video(controller: _videoController!, controls: AdaptiveVideoControls);
  }

  Widget _buildAudioArt(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Image.asset(
            'assets/brand/pulse-logo.png',
            width: 220,
            height: 220,
            fit: BoxFit.contain,
          ),
        ),
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
            Text(item.isVideo ? 'Video playback' : 'Audio playback', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 30),
            Slider(
              value: progress,
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) => playerController.seekTo(Duration(milliseconds: value.round())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_format(snapshot.position)),
                Text(_format(snapshot.duration)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(onPressed: playerController.previous, icon: const Icon(Icons.skip_previous_rounded)),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: () => playerController.seekRelative(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded)),
                const SizedBox(width: 12),
                IconButton.filled(
                  iconSize: 36,
                  onPressed: playerController.togglePlay,
                  icon: Icon(snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
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
                FilterChip(
                  selected: playerController.shuffle,
                  onSelected: (_) => playerController.toggleShuffle(),
                  avatar: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle'),
                ),
                FilterChip(
                  selected: playerController.repeatMode != PulseRepeatMode.off,
                  onSelected: (_) => playerController.cycleRepeat(),
                  avatar: Icon(playerController.repeatMode == PulseRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
                  label: Text(playerController.repeatMode.name),
                ),
                ActionChip(avatar: const Icon(Icons.favorite_border_rounded), label: const Text('Favorite'), onPressed: onFavorite),
                ActionChip(avatar: const Icon(Icons.bedtime_outlined), label: Text(playerController.sleepTimerActive ? 'Cancel timer' : 'Sleep 30m'), onPressed: () {
                  if (playerController.sleepTimerActive) {
                    playerController.cancelSleepTimer();
                  } else {
                    playerController.startSleepTimer(const Duration(minutes: 30));
                  }
                }),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<double>(
              initialValue: snapshot.speed,
              decoration: const InputDecoration(labelText: 'Playback speed', border: OutlineInputBorder()),
              items: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                  .map((speed) => DropdownMenuItem(value: speed, child: Text('${speed}x')))
                  .toList(growable: false),
              onChanged: (speed) {
                if (speed != null) playerController.setSpeed(speed);
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}




