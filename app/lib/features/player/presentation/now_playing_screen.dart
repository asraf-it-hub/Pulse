import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'player_intents.dart';
import 'player_hud_overlay.dart';
import 'play_pause_morph_button.dart';

import '../../../core/models/media_item.dart';
import '../../../core/widgets/pulse_empty_state.dart';
import '../../../core/widgets/animated_audio_visualizer.dart';
import '../../../services/player_engine/player_engine.dart';
import '../../library/application/library_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../application/player_controller.dart';
import 'equalizer_sheet.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    required this.playerController,
    required this.libraryController,
    required this.settingsController,
    super.key,
  });

  final PlayerController playerController;
  final LibraryController libraryController;
  final SettingsController settingsController;

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
        if (playerController.isInPip) {
          return _ArtworkPanel(
            item: current,
            playerController: playerController,
            settingsController: settingsController,
            libraryController: libraryController,
          );
        }
        return ValueListenableBuilder<PlaybackSnapshot>(
          valueListenable: playerController.snapshot,
          builder: (context, snapshot, _) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverAppBar.large(title: Text('Now Playing')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final art = _ArtworkPanel(
                          item: current,
                          playerController: playerController,
                          settingsController: settingsController,
                          libraryController: libraryController,
                        );
                        final controls = ControlsPanel(
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
  const _ArtworkPanel({
    required this.item,
    required this.playerController,
    required this.settingsController,
    required this.libraryController,
  });

  final MediaItem item;
  final PlayerController playerController;
  final SettingsController settingsController;
  final LibraryController libraryController;

  @override
  State<_ArtworkPanel> createState() => _ArtworkPanelState();
}

class _ArtworkPanelState extends State<_ArtworkPanel> {
  final GlobalKey<PlayerHudOverlayState> _hudKey = GlobalKey<PlayerHudOverlayState>();
  double _brightness = 1.0;

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
            final x = details.localPosition.dx;

            if (widget.item.isVideo && x > width * 0.35 && x < width * 0.65) {
              _openFullscreen();
              return;
            }

            final forward = x > width / 2;
            final seconds = widget.settingsController.settings.skipDuration;
            widget.playerController.seekRelative(Duration(seconds: (forward ? seconds : -seconds).round()));
            _hudKey.currentState?.showSeek(details.localPosition, forward, seconds.round());
          },
          onVerticalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 1;
            final height = box?.size.height ?? 1;
            final leftSide = details.localPosition.dx < width / 2;
            final delta = -details.delta.dy / height;

            if (leftSide) {
              final target = (_brightness + delta).clamp(0.0, 1.0);
              setState(() {
                _brightness = target;
              });
              _hudKey.currentState?.showBrightness(target);
            } else {
              final currentVolume = widget.playerController.snapshot.value.volume;
              final target = (currentVolume + delta).clamp(0.0, 1.0);
              widget.playerController.setVolume(target);
            }
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
              if (_brightness < 1.0)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: (1.0 - _brightness).clamp(0.0, 0.95)),
                    ),
                  ),
                ),
              if (widget.item.isVideo && !widget.playerController.isInPip)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Picture-in-picture',
                        onPressed: widget.playerController.enterPip,
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
              PlayerHudOverlay(
                playerController: widget.playerController,
                key: _hudKey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final fit = widget.playerController.videoFit;
    final aspect = widget.playerController.videoAspectRatio;
    
    Widget videoWidget = Video(
      controller: widget.playerController.videoController,
      controls: AdaptiveVideoControls,
      fit: fit,
    );

    if (aspect != null) {
      videoWidget = AspectRatio(
        aspectRatio: aspect,
        child: videoWidget,
      );
    }
    
    return Center(child: videoWidget);
  }

  Widget _buildAudioArt(ThemeData theme) {
    Widget artwork = Center(child: Image.asset('assets/brand/pulse-logo.png', width: 220, height: 220, fit: BoxFit.contain));

    if (!kIsWeb && widget.item.thumbnailUri != null && widget.item.thumbnailUri!.isNotEmpty) {
      final file = io.File(widget.item.thumbnailUri!);
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
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 64,
          child: AnimatedAudioVisualizer(
            isPlaying: widget.playerController.snapshot.value.playing,
            color: theme.colorScheme.primary,
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipOval(
              child: ColoredBox(
                color: Colors.black45,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary, size: 28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullscreen() {
    final fullscreenHudKey = GlobalKey<PlayerHudOverlayState>();
    bool isLocked = false;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/fullscreen'),
      fullscreenDialog: true,
      builder: (context) => Shortcuts(
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
            ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(onInvoke: (_) => Navigator.of(context).pop()),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: StatefulBuilder(
                  builder: (context, setStateFullscreen) {
                    return GestureDetector(
                      onDoubleTapDown: isLocked
                          ? null
                          : (details) {
                              final box = context.findRenderObject() as RenderBox?;
                              final width = box?.size.width ?? 1;
                              final x = details.localPosition.dx;

                              if (x > width * 0.35 && x < width * 0.65) {
                                Navigator.of(context).pop();
                                return;
                              }

                              final forward = x > width / 2;
                              final seconds = widget.settingsController.settings.skipDuration;
                              widget.playerController.seekRelative(Duration(seconds: (forward ? seconds : -seconds).round()));
                              fullscreenHudKey.currentState?.showSeek(details.localPosition, forward, seconds.round());
                            },
                      onVerticalDragUpdate: isLocked
                          ? null
                          : (details) {
                              final box = context.findRenderObject() as RenderBox?;
                              final width = box?.size.width ?? 1;
                              final height = box?.size.height ?? 1;
                              final leftSide = details.localPosition.dx < width / 2;
                              final delta = -details.delta.dy / height;

                              if (leftSide) {
                                final target = (_brightness + delta).clamp(0.0, 1.0);
                                setState(() {
                                  _brightness = target;
                                });
                                setStateFullscreen(() {});
                                fullscreenHudKey.currentState?.showBrightness(target);
                              } else {
                                final currentVolume = widget.playerController.snapshot.value.volume;
                                final target = (currentVolume + delta).clamp(0.0, 1.0);
                                widget.playerController.setVolume(target);
                              }
                            },
                      child: Stack(
                        children: [
                          Center(child: _buildVideo()),
                          if (_brightness < 1.0)
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: (1.0 - _brightness).clamp(0.0, 0.95)),
                                ),
                              ),
                            ),
                          if (!isLocked) ...[
                            Positioned(
                              top: 12,
                              right: 12,
                              child: IconButton.filled(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_fullscreen_rounded),
                              ),
                            ),
                            PlayerHudOverlay(
                              playerController: widget.playerController,
                              key: fullscreenHudKey,
                            ),
                          ],
                          Positioned(
                            top: 12,
                            left: 12,
                            child: IconButton.filled(
                              onPressed: () {
                                setStateFullscreen(() {
                                  isLocked = !isLocked;
                                });
                                widget.playerController.showToast(isLocked ? 'Controls Locked' : 'Controls Unlocked');
                              },
                              icon: Icon(isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),
          ),
        ),
      ),
    )).then((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }
}

class ControlsPanel extends StatelessWidget {
  const ControlsPanel({
    required this.item,
    required this.snapshot,
    required this.playerController,
    required this.onFavorite,
    super.key,
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
            SeekSliderWithTooltip(
              progress: progress,
              duration: duration.inMilliseconds.toDouble(),
              item: item,
              onChanged: (value) => playerController.seekTo(Duration(milliseconds: value.round())),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_format(snapshot.position)), Text(_format(snapshot.duration))]),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(onPressed: playerController.previous, icon: const Icon(Icons.skip_previous_rounded)),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: () => playerController.seekRelative(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded)),
                const SizedBox(width: 12),
                PlayPauseMorphButton(
                  playing: snapshot.playing,
                  onPressed: playerController.togglePlay,
                  iconSize: 36,
                  backgroundColor: theme.colorScheme.primary,
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
                ActionChip(
                  avatar: const Icon(Icons.queue_music_rounded),
                  label: const Text('Queue'),
                  onPressed: () => _showQueueBottomSheet(context),
                ),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded),
                  label: const Text('Equalizer (EQ)'),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) => const EqualizerSheet(),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Visualizer (📊)'),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) {
                        return Container(
                          height: 340,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'Live Audio Spectrum Visualizer',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    color: Colors.black87,
                                    padding: const EdgeInsets.all(20),
                                    child: AnimatedAudioVisualizer(
                                      isPlaying: snapshot.playing,
                                      color: Theme.of(context).colorScheme.primary,
                                      barCount: 36,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
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
            if (item.isVideo && snapshot.audioTracks.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<AudioTrack?>(
                initialValue: snapshot.selectedAudioTrack,
                decoration: const InputDecoration(labelText: 'Audio Track', border: OutlineInputBorder()),
                items: [
                  for (final track in snapshot.audioTracks)
                    DropdownMenuItem(value: track, child: Text(track.label)),
                ],
                onChanged: (track) {
                  playerController.setAudioTrack(track);
                },
              ),
            ],
            if (item.isVideo) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<SubtitleTrack?>(
                initialValue: snapshot.selectedSubtitleTrack,
                decoration: const InputDecoration(labelText: 'Subtitle Track', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Off')),
                  for (final track in snapshot.subtitleTracks)
                    DropdownMenuItem(value: track, child: Text(track.label)),
                ],
                onChanged: (track) {
                  playerController.setSubtitleTrack(track);
                },
              ),
              const SizedBox(height: 10),
              ActionChip(
                avatar: const Icon(Icons.subtitles_rounded),
                label: const Text('Load external subtitles (.srt)'),
                onPressed: () => playerController.loadExternalSubtitleFile(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<BoxFit>(
                      initialValue: playerController.videoFit,
                      decoration: const InputDecoration(labelText: 'Video Fit', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: BoxFit.contain, child: Text('Fit')),
                        DropdownMenuItem(value: BoxFit.cover, child: Text('Fill')),
                        DropdownMenuItem(value: BoxFit.fill, child: Text('Stretch')),
                      ],
                      onChanged: (fit) {
                        if (fit != null) playerController.setVideoFit(fit);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<double?>(
                      initialValue: playerController.videoAspectRatio,
                      decoration: const InputDecoration(labelText: 'Aspect Ratio', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Auto')),
                        DropdownMenuItem(value: 16 / 9, child: Text('16:9')),
                        DropdownMenuItem(value: 4 / 3, child: Text('4:3')),
                        DropdownMenuItem(value: 1.0, child: Text('1:1')),
                      ],
                      onChanged: (ratio) {
                        playerController.setVideoAspectRatio(ratio);
                      },
                    ),
                  ),
                ],
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

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return ListenableBuilder(
          listenable: playerController,
          builder: (context, _) {
            final queue = playerController.queue;
            final current = playerController.current;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Playback Queue (${queue.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (queue.length > 1)
                          TextButton.icon(
                            onPressed: playerController.clearQueue,
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: queue.isEmpty
                        ? Center(
                            child: Text(
                              'Queue is empty',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ReorderableListView.builder(
                            itemCount: queue.length,
                            // ignore: deprecated_member_use
                            onReorder: playerController.reorderQueue,
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final isCurrent = current?.id == item.id;

                              return Material(
                                key: ValueKey(item.id),
                                color: Colors.transparent,
                                child: ListTile(
                                  leading: isCurrent
                                      ? Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary)
                                      : const Icon(Icons.music_note_rounded),
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
                                          onPressed: () => playerController.removeFromQueue(item.id),
                                        ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Icon(Icons.drag_handle_rounded),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    playerController.playItem(item, queue);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class SeekSliderWithTooltip extends StatefulWidget {
  const SeekSliderWithTooltip({
    required this.progress,
    required this.duration,
    required this.onChanged,
    required this.item,
    super.key,
  });

  final double progress;
  final double duration;
  final ValueChanged<double> onChanged;
  final MediaItem item;

  @override
  State<SeekSliderWithTooltip> createState() => _SeekSliderWithTooltipState();
}

class _SeekSliderWithTooltipState extends State<SeekSliderWithTooltip> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProgress = _isDragging ? _dragValue : widget.progress;
    final duration = widget.duration == 0.0 ? 1.0 : widget.duration;
    final fraction = (currentProgress / duration).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderWidth = constraints.maxWidth;
        final trackWidth = sliderWidth - 48;
        final thumbX = 24.0 + (trackWidth * fraction);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.18),
                thumbColor: Colors.white,
                overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                  elevation: 6.0,
                  pressedElevation: 10.0,
                ),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: currentProgress.clamp(0.0, duration),
                max: duration,
                onChangeStart: (val) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = val;
                  });
                },
                onChanged: (val) {
                  setState(() {
                    _dragValue = val;
                  });
                },
                onChangeEnd: (val) {
                  widget.onChanged(val);
                  setState(() {
                    _isDragging = false;
                  });
                },
              ),
            ),
            AnimatedPositioned(
              duration: _isDragging ? const Duration(milliseconds: 140) : Duration.zero,
              curve: Curves.easeOutBack,
              left: (thumbX - 60).clamp(0.0, sliderWidth - 120),
              bottom: 44,
              child: AnimatedScale(
                scale: _isDragging ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 54,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: widget.item.thumbnailUri != null && widget.item.thumbnailUri!.isNotEmpty
                                  ? Image.file(
                                      io.File(widget.item.thumbnailUri!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        widget.item.isVideo ? Icons.movie_filter_rounded : Icons.music_note_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Icon(
                                      widget.item.isVideo ? Icons.movie_filter_rounded : Icons.music_note_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _format(Duration(milliseconds: currentProgress.round())),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
          ],
        );
      },
    );
  }
}

