import 'dart:async';
import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/models/media_item.dart';
import '../../../services/player_engine/player_engine.dart';
import '../../library/application/library_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../application/player_controller.dart';
import 'ab_looper_widget.dart';
import 'play_pause_morph_button.dart';
import 'player_hud_overlay.dart';
import 'player_intents.dart';

class PremiumVideoPlayerScreen extends StatefulWidget {
  const PremiumVideoPlayerScreen({
    required this.playerController,
    required this.libraryController,
    required this.settingsController,
    super.key,
  });

  final PlayerController playerController;
  final LibraryController libraryController;
  final SettingsController settingsController;

  @override
  State<PremiumVideoPlayerScreen> createState() => _PremiumVideoPlayerScreenState();
}

class _PremiumVideoPlayerScreenState extends State<PremiumVideoPlayerScreen> with TickerProviderStateMixin {
  final GlobalKey<PlayerHudOverlayState> _hudKey = GlobalKey<PlayerHudOverlayState>();
  late final FocusNode _focusNode;
  double _brightness = 1.0;
  double _volumeValue = 1.0;
  bool _isLocked = false;
  bool _areControlsVisible = true;
  Timer? _hideTimer;
  bool _showLongPressSpeed = false;
  double _playbackSpeedBeforeLongPress = 1.0;

  // Track completion
  bool _isCompleted = false;
  StreamSubscription<bool>? _completionSub;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startHideTimer();
    widget.playerController.setWantsPip(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    // Listen to video completion stream from media_kit
    final player = widget.playerController.videoController.player;
    _completionSub = player.stream.completed.listen((completed) {
      if (completed) {
        setState(() {
          _isCompleted = true;
          _areControlsVisible = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.playerController.setWantsPip(false);
    widget.playerController.pause();
    _completionSub?.cancel();
    _hideTimer?.cancel();
    if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
      try {
        windowManager.setFullScreen(false);
        windowManager.setTitleBarStyle(TitleBarStyle.normal, windowButtonVisibility: true);
      } catch (_) {}
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onMouseHover() {
    if (!_areControlsVisible) {
      setState(() {
        _areControlsVisible = true;
      });
    }
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isLocked || _isCompleted) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _areControlsVisible = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() {
        _areControlsVisible = !_areControlsVisible;
      });
      _startHideTimer();
      return;
    }
    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
    if (_areControlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _seekRelative(Duration offset) {
    widget.playerController.seekRelative(offset);
  }

  Future<void> _toggleOSFullscreen() async {
    if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (!isFull) {
          await windowManager.setFullScreen(true);
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
        } else {
          await windowManager.setFullScreen(false);
          await windowManager.setTitleBarStyle(TitleBarStyle.normal, windowButtonVisibility: true);
        }
        if (mounted) {
          if (!isFull) {
            await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          } else {
            await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
        }
        return;
      } catch (_) {}
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playerController,
      builder: (context, _) {
        final theme = Theme.of(context);
        final current = widget.playerController.current;
        if (current == null) return const Scaffold(backgroundColor: Colors.black);

        final snapshot = widget.playerController.snapshot.value;
        final fit = widget.playerController.videoFit;
        final aspect = widget.playerController.videoAspectRatio;

        Widget videoWidget = Video(
          controller: widget.playerController.videoController,
          controls: NoVideoControls,
          fit: fit,
        );

        if (aspect != null) {
          videoWidget = AspectRatio(
            aspectRatio: aspect,
            child: videoWidget,
          );
        }

        return MouseRegion(
          onHover: (_) => _onMouseHover(),
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.space): TogglePlaybackIntent(),
              SingleActivator(LogicalKeyboardKey.arrowLeft): SeekBackIntent(),
              SingleActivator(LogicalKeyboardKey.arrowRight): SeekForwardIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp): VolumeUpIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): VolumeDownIntent(),
              SingleActivator(LogicalKeyboardKey.keyM): ToggleMuteIntent(),
              SingleActivator(LogicalKeyboardKey.keyF): ToggleFullscreenIntent(),
              SingleActivator(LogicalKeyboardKey.escape): CloseVideoIntent(),
              SingleActivator(LogicalKeyboardKey.backspace): CloseVideoIntent(),
              SingleActivator(LogicalKeyboardKey.keyQ): CloseVideoIntent(),
            },
            child: Actions(
              actions: {
                TogglePlaybackIntent: CallbackAction<TogglePlaybackIntent>(onInvoke: (_) {
                  widget.playerController.togglePlay();
                  _startHideTimer();
                  return null;
                }),
                SeekBackIntent: CallbackAction<SeekBackIntent>(onInvoke: (_) {
                  final seconds = widget.settingsController.settings.skipDuration;
                  _seekRelative(Duration(seconds: -seconds.round()));
                  _hudKey.currentState?.showSeek(Offset.zero, false, seconds.round(), isKeyboard: true);
                  _startHideTimer();
                  return null;
                }),
                SeekForwardIntent: CallbackAction<SeekForwardIntent>(onInvoke: (_) {
                  final seconds = widget.settingsController.settings.skipDuration;
                  _seekRelative(Duration(seconds: seconds.round()));
                  _hudKey.currentState?.showSeek(Offset.zero, true, seconds.round(), isKeyboard: true);
                  _startHideTimer();
                  return null;
                }),
                VolumeUpIntent: CallbackAction<VolumeUpIntent>(onInvoke: (_) {
                  final step = widget.settingsController.settings.volumeStep;
                  final currentVol = widget.playerController.snapshot.value.volume;
                  widget.playerController.setVolume((currentVol + step).clamp(0.0, 1.0));
                  _hudKey.currentState?.showVolume();
                  _startHideTimer();
                  return null;
                }),
                VolumeDownIntent: CallbackAction<VolumeDownIntent>(onInvoke: (_) {
                  final step = widget.settingsController.settings.volumeStep;
                  final currentVol = widget.playerController.snapshot.value.volume;
                  widget.playerController.setVolume((currentVol - step).clamp(0.0, 1.0));
                  _hudKey.currentState?.showVolume();
                  _startHideTimer();
                  return null;
                }),
                ToggleMuteIntent: CallbackAction<ToggleMuteIntent>(onInvoke: (_) {
                  widget.playerController.toggleMute();
                  _hudKey.currentState?.showVolume();
                  _startHideTimer();
                  return null;
                }),
                ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(onInvoke: (_) {
                  _toggleOSFullscreen();
                  _startHideTimer();
                  return null;
                }),
                CloseVideoIntent: CallbackAction<CloseVideoIntent>(onInvoke: (_) {
                  Navigator.of(context).pop();
                  return null;
                }),
              },
              child: Focus(
                focusNode: _focusNode,
                autofocus: true,
                child: Scaffold(
                  backgroundColor: Colors.black,
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                        // Video and gesture detector area
                        GestureDetector(
                          onTap: _toggleControls,
                          onLongPressStart: _isLocked
                              ? null
                              : (_) {
                                  setState(() {
                                    _showLongPressSpeed = true;
                                    _playbackSpeedBeforeLongPress = snapshot.speed;
                                  });
                                  widget.playerController.setSpeed(2.0);
                                },
                          onLongPressEnd: _isLocked
                              ? null
                              : (_) {
                                  setState(() {
                                    _showLongPressSpeed = false;
                                  });
                                  widget.playerController.setSpeed(_playbackSpeedBeforeLongPress);
                                },
                          onDoubleTapDown: _isLocked
                              ? null
                              : (details) {
                                  final box = context.findRenderObject() as RenderBox?;
                                  final width = box?.size.width ?? 1;
                                  final x = details.localPosition.dx;

                                  final isLeft = x < width * 0.3;
                                  final isRight = x > width * 0.7;

                                  if (isLeft || isRight) {
                                    final isForward = isRight;
                                    final seconds = widget.settingsController.settings.skipDuration;
                                    _seekRelative(Duration(seconds: (isForward ? seconds : -seconds).round()));
                                    _hudKey.currentState?.showSeek(details.localPosition, isForward, seconds.round());
                                  }
                                },
                          onVerticalDragStart: (details) {
                            final box = context.findRenderObject() as RenderBox?;
                            final width = box?.size.width ?? 1;
                            final leftSide = details.localPosition.dx < width / 2;
                            if (!leftSide) {
                              _volumeValue = widget.playerController.snapshot.value.volume;
                            }
                          },
                          onVerticalDragUpdate: _isLocked
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
                                    _hudKey.currentState?.showBrightness(target);
                                  } else {
                                    _volumeValue = (_volumeValue + delta * 1.5).clamp(0.0, 2.0);
                                    widget.playerController.setVolume(_volumeValue);
                                    _hudKey.currentState?.showVolume();
                                  }
                                },
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Center(child: videoWidget),
                          ),
                        ),

                        // Volume/Brightness HUD gestures display layer
                        IgnorePointer(
                          child: PlayerHudOverlay(
                            playerController: widget.playerController,
                            key: _hudKey,
                          ),
                        ),

                        // Brightness overlay dimming filter
                        if (_brightness < 1.0)
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: (1.0 - _brightness).clamp(0.0, 0.95)),
                              ),
                            ),
                          ),

                        // Top Bar
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          top: _areControlsVisible && !_isLocked ? 0 : -120,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _areControlsVisible && !_isLocked ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !_areControlsVisible || _isLocked,
                              child: _buildTopBar(theme, current),
                            ),
                          ),
                        ),

                        // Bottom Bar and Progress Seek
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          bottom: _areControlsVisible && !_isLocked ? 0 : -240,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _areControlsVisible && !_isLocked ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !_areControlsVisible || _isLocked,
                              child: _buildBottomControls(theme, snapshot),
                            ),
                          ),
                        ),

                        // Large Center Play/Pause button
                        if (_areControlsVisible && !_isLocked && !_isCompleted)
                          Center(
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.black26,
                                  child: Center(
                                    child: PlayPauseMorphButton(
                                      playing: snapshot.playing,
                                      onPressed: widget.playerController.togglePlay,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Long Press 2x Speed indicator HUD
                        if (_showLongPressSpeed)
                          Positioned(
                            top: 80,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    color: Colors.black45,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          '2x Speed',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: Colors.white,
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

                        // Lock indicator overlay button when locked
                        if (_isLocked)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: AnimatedOpacity(
                              opacity: _areControlsVisible ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              child: IconButton.filled(
                                onPressed: () {
                                  setState(() {
                                    _isLocked = false;
                                    _areControlsVisible = true;
                                  });
                                  _startHideTimer();
                                  widget.playerController.showToast('Controls Unlocked');
                                },
                                icon: const Icon(Icons.lock_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // Video Completed End Card Overlay
                        if (_isCompleted)
                          Positioned.fill(
                            child: _buildEndCard(theme, current),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
      },
    );
  }

  Widget _buildTopBar(ThemeData theme, MediaItem current) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Fullscreen (F)',
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
            onPressed: _toggleOSFullscreen,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: () => _showFileInfo(current),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme, PlaybackSnapshot snapshot) {
    final progress = snapshot.duration.inMilliseconds > 0
        ? snapshot.position.inMilliseconds / snapshot.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timeline Slider (Glassmorphic White/Translucent)
          Row(
            children: [
              Text(
                _formatDuration(snapshot.position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackShape: RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (val) {
                      final ms = (val * snapshot.duration.inMilliseconds).round();
                      widget.playerController.seekTo(Duration(milliseconds: ms));
                      _startHideTimer();
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(snapshot.duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),

          // Bottom Toolbar Row
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Lock
              IconButton(
                tooltip: 'Lock player',
                icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isLocked = true;
                    _areControlsVisible = false;
                  });
                  widget.playerController.showToast('Controls Locked');
                },
              ),

              // CC Subtitle
              IconButton(
                tooltip: 'Subtitles',
                icon: const Icon(Icons.closed_caption_rounded, color: Colors.white),
                onPressed: () => _showTracksBottomSheet(context, isAudio: false),
              ),

              // 1.0x Speed
              IconButton(
                tooltip: 'Playback Speed',
                icon: const Icon(Icons.speed_rounded, color: Colors.white),
                onPressed: () => _showSpeedWheelSelector(context),
              ),

              // Fullscreen
              IconButton(
                tooltip: 'Fullscreen (F)',
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                onPressed: _toggleOSFullscreen,
              ),

              // More Options Menu
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () => _showMoreOptionsBottomSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEndCard(ThemeData theme, MediaItem current) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.12),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Playback Finished',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Replay'),
                        onPressed: () {
                          setState(() {
                            _isCompleted = false;
                            _areControlsVisible = true;
                          });
                          widget.playerController.seekTo(Duration.zero);
                          widget.playerController.play();
                          _startHideTimer();
                        },
                      ),
                      if (widget.playerController.queue.length > 1)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Next Video'),
                          onPressed: () {
                            setState(() {
                              _isCompleted = false;
                            });
                            widget.playerController.next();
                            _startHideTimer();
                          },
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedWheelSelector(BuildContext context) {
    final theme = Theme.of(context);
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentSpeed = widget.playerController.snapshot.value.speed;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black87,
              height: 220,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text('Playback Speed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 44,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        widget.playerController.setSpeed(speeds[index]);
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: speeds.length,
                        builder: (context, index) {
                          final speed = speeds[index];
                          final isSelected = (speed - currentSpeed).abs() < 0.01;
                          return Center(
                            child: Text(
                              '${speed}x',
                              style: TextStyle(
                                color: isSelected ? theme.colorScheme.primary : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: isSelected ? 18 : 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTracksBottomSheet(BuildContext context, {required bool isAudio}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListenableBuilder(
                listenable: widget.playerController,
                builder: (context, _) {
                  final snap = widget.playerController.snapshot.value;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Text(
                        isAudio ? 'Audio Channels' : 'Subtitle Track',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: isAudio
                              ? [
                                  for (final track in snap.audioTracks)
                                    ListTile(
                                      leading: const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                                      title: Text(track.label, style: const TextStyle(color: Colors.white70)),
                                      trailing: snap.selectedAudioTrack?.id == track.id
                                          ? const Icon(Icons.check_rounded, color: Colors.white)
                                          : null,
                                      onTap: () {
                                        widget.playerController.setAudioTrack(track);
                                        Navigator.pop(context);
                                      },
                                    ),
                                ]
                              : [
                                  ListTile(
                                    leading: const Icon(Icons.closed_caption_off_rounded, color: Colors.white70),
                                    title: const Text('Off', style: TextStyle(color: Colors.white70)),
                                    trailing: snap.selectedSubtitleTrack == null
                                        ? const Icon(Icons.check_rounded, color: Colors.white)
                                        : null,
                                    onTap: () {
                                      widget.playerController.setSubtitleTrack(null);
                                      Navigator.pop(context);
                                    },
                                  ),
                                  for (final track in snap.subtitleTracks)
                                    ListTile(
                                      leading: const Icon(Icons.closed_caption_rounded, color: Colors.white70),
                                      title: Text(track.label, style: const TextStyle(color: Colors.white70)),
                                      trailing: snap.selectedSubtitleTrack?.uri == track.uri
                                          ? const Icon(Icons.check_rounded, color: Colors.white)
                                          : null,
                                      onTap: () {
                                        widget.playerController.setSubtitleTrack(track);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  const Divider(color: Colors.white10),
                                  ListTile(
                                    leading: const Icon(Icons.add_rounded, color: Colors.white70),
                                    title: const Text('Load external subtitles (.srt)', style: TextStyle(color: Colors.white70)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      widget.playerController.loadExternalSubtitleFile();
                                    },
                                  ),
                                ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMoreOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Properties & Scaling', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

                  // Aspect Ratio / Video Fit Row selector
                  const Text('Video Layout', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildLayoutChip('Fit Screen', BoxFit.contain, null),
                        _buildLayoutChip('Crop', BoxFit.cover, null),
                        _buildLayoutChip('Stretch', BoxFit.fill, null),
                        _buildLayoutChip('16:9 Size', BoxFit.contain, 16 / 9),
                        _buildLayoutChip('4:3 Size', BoxFit.contain, 4 / 3),
                        _buildLayoutChip('1:1 Original', BoxFit.contain, 1.0),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Audio track, Sleep timer rows
                  ListTile(
                    leading: const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                    title: const Text('Audio Track', style: TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      _showTracksBottomSheet(context, isAudio: true);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bedtime_outlined, color: Colors.white70),
                    title: const Text('Sleep Timer (30m)', style: TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      widget.playerController.startSleepTimer(const Duration(minutes: 30));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.repeat_rounded, color: Colors.white70),
                    title: const Text('A-B Segment Looper (🔁)', style: TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => ABLooperWidget(
                          currentPosition: widget.playerController.snapshot.value.position,
                          duration: widget.playerController.snapshot.value.duration,
                          onSeek: widget.playerController.seekTo,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                    title: const Text('Playback Info', style: TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      final current = widget.playerController.current;
                      if (current != null) _showFileInfo(current);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutChip(String label, BoxFit fit, double? aspect) {
    final currentFit = widget.playerController.videoFit;
    final currentAspect = widget.playerController.videoAspectRatio;
    final isSelected = currentFit == fit && currentAspect == aspect;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) {
          widget.playerController.setVideoFit(fit);
          widget.playerController.setVideoAspectRatio(aspect);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showFileInfo(MediaItem item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Playback Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${item.title}'),
              const SizedBox(height: 6),
              Text('Path: ${item.uri}'),
              const SizedBox(height: 6),
              Text('Kind: ${item.kind.name.toUpperCase()}'),
              if (item.artist != null) ...[
                const SizedBox(height: 6),
                Text('Artist: ${item.artist}'),
              ],
              if (item.album != null) ...[
                const SizedBox(height: 6),
                Text('Album: ${item.album}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
