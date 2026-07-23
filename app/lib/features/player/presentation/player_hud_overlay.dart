import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/player_controller.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class PlayerHudOverlay extends StatefulWidget {
  const PlayerHudOverlay({
    required this.playerController,
    super.key,
  });

  final PlayerController playerController;

  @override
  State<PlayerHudOverlay> createState() => PlayerHudOverlayState();
}

class PlayerHudOverlayState extends State<PlayerHudOverlay> with TickerProviderStateMixin {
  // Volume HUD State
  double _volumeOpacity = 0.0;
  double _volumeScale = 0.8;
  Timer? _volumeTimer;
  double _lastVolume = -1.0;

  // Brightness HUD State
  double _brightnessOpacity = 0.0;
  double _brightnessScale = 0.8;
  double _brightnessValue = 1.0;
  Timer? _brightnessTimer;

  // Double-Tap Seek HUD State
  Offset? _ripplePosition;
  double _rippleOpacity = 0.0;
  double _rippleScale = 0.0;
  bool _seekIsForward = true;
  int _seekAccumulatedSeconds = 0;
  double _seekHudOpacity = 0.0;
  Timer? _seekHudTimer;
  DateTime _lastSeekTime = DateTime.now();

  late final AnimationController _rippleController;
  late final AnimationController _seekTextController;

  @override
  void initState() {
    super.initState();
    widget.playerController.snapshot.addListener(_onVolumeChanged);
    widget.playerController.playerToast.addListener(_onToastChanged);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        setState(() {
          _rippleScale = _rippleController.value;
          _rippleOpacity = (1.0 - _rippleController.value).clamp(0.0, 1.0);
        });
      });

    _seekTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    widget.playerController.snapshot.removeListener(_onVolumeChanged);
    widget.playerController.playerToast.removeListener(_onToastChanged);
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
    _seekHudTimer?.cancel();
    _rippleController.dispose();
    _seekTextController.dispose();
    super.dispose();
  }

  void _onVolumeChanged() {
    final vol = widget.playerController.snapshot.value.volume;
    if (_lastVolume == -1.0) {
      _lastVolume = vol;
      return;
    }
    if ((vol - _lastVolume).abs() > 0.001) {
      _lastVolume = vol;
      showVolume();
    }
  }

  void _onToastChanged() {
    final toast = widget.playerController.playerToast.value;
    if (toast == null) return;

    if (toast.startsWith('Forward') || toast.startsWith('Back')) {
      final now = DateTime.now();
      if (now.difference(_lastSeekTime).inMilliseconds > 100) {
        final isForward = toast.startsWith('Forward');
        final match = RegExp(r'\d+').firstMatch(toast);
        final seconds = match != null ? int.tryParse(match.group(0)!) ?? 10 : 10;
        showSeek(Offset.zero, isForward, seconds, isKeyboard: true);
      }
    } else if (toast == 'Muted') {
      showVolume();
    }
  }

  // Trigger Volume HUD
  void showVolume() {
    _volumeTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _volumeOpacity = 1.0;
      _volumeScale = 1.05;
    });
    _volumeTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _volumeOpacity = 0.0;
          _volumeScale = 0.8;
        });
      }
    });
  }

  // Trigger Brightness HUD
  void showBrightness(double value) {
    _brightnessTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _brightnessValue = value;
      _brightnessOpacity = 1.0;
      _brightnessScale = 1.05;
    });
    _brightnessTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _brightnessOpacity = 0.0;
          _brightnessScale = 0.8;
        });
      }
    });
  }

  // Trigger Double-Tap Seek HUD & Ripple
  void showSeek(Offset localPosition, bool forward, int seconds, {bool isKeyboard = false}) {
    _lastSeekTime = DateTime.now();
    _seekHudTimer?.cancel();
    
    // Accumulate if same direction, reset if different
    if (_seekIsForward == forward && _seekHudOpacity > 0.0) {
      _seekAccumulatedSeconds += seconds;
    } else {
      _seekIsForward = forward;
      _seekAccumulatedSeconds = seconds;
    }

    setState(() {
      _ripplePosition = isKeyboard ? null : localPosition;
      _seekHudOpacity = 1.0;
    });

    if (!isKeyboard) {
      _rippleController.forward(from: 0.0);
    }
    _seekTextController.forward(from: 0.0).then((_) => _seekTextController.reverse());

    _seekHudTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _seekHudOpacity = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final volume = widget.playerController.snapshot.value.volume;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Touch Ripple Overlay for Seek
        if (_ripplePosition != null && _rippleOpacity > 0.0)
          Positioned(
            left: _ripplePosition!.dx - 120,
            top: _ripplePosition!.dy - 120,
            child: IgnorePointer(
              child: Opacity(
                opacity: _rippleOpacity * 0.28,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                        theme.colorScheme.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  transform: Matrix4.identity()..scaleByVector3(vm.Vector3(_rippleScale * 1.5, _rippleScale * 1.5, 1.0)),
                  transformAlignment: Alignment.center,
                ),
              ),
            ),
          ),

        // 2. Double-Tap Seek Chevrons & Numbers (Centered or Side)
        if (_seekHudOpacity > 0.0)
          Positioned(
            left: _ripplePosition == null ? 0 : (_seekIsForward ? null : 40),
            right: _ripplePosition == null ? 0 : (_seekIsForward ? 40 : null),
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _seekHudOpacity,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: Colors.black45,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_seekIsForward) ...[
                              const Text('≪≪', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                            ],
                            ScaleTransition(
                              scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                                CurvedAnimation(parent: _seekTextController, curve: Curves.easeOutCubic),
                              ),
                              child: Text(
                                '${_seekIsForward ? "+" : "-"}${_seekAccumulatedSeconds}s',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (_seekIsForward) ...[
                              const SizedBox(width: 8),
                              const Text('≫≫', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 3. Volume Glass vertical pill & Supercharged 200% Boost Effect
        Builder(
          builder: (context) {
            final isBoosted = volume > 1.0;
            final fillRatio = (volume / 2.0).clamp(0.0, 1.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Satisfying Fiery Right Screen Edge Flare when > 100%
                if (isBoosted && _volumeOpacity > 0.0)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 160,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: (_volumeOpacity * ((volume - 1.0) / 1.0)).clamp(0.0, 0.6),
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Colors.deepOrangeAccent.withValues(alpha: 0.6),
                                Colors.amberAccent.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                Align(
                  alignment: const Alignment(0.85, 0.0),
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _volumeOpacity,
                      duration: Duration(milliseconds: _volumeOpacity == 0.0 ? 250 : 120),
                      child: AnimatedScale(
                        scale: _volumeScale * (isBoosted ? 1.08 : 1.0),
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: isBoosted ? 56 : 50,
                              height: isBoosted ? 230 : 200,
                              decoration: BoxDecoration(
                                color: isBoosted ? Colors.black87 : Colors.black38,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isBoosted ? Colors.amberAccent : Colors.white12,
                                  width: isBoosted ? 2.0 : 1.0,
                                ),
                                boxShadow: isBoosted
                                    ? [
                                        BoxShadow(
                                          color: Colors.deepOrangeAccent.withValues(alpha: 0.8),
                                          blurRadius: 24,
                                          spreadRadius: 6,
                                        ),
                                        BoxShadow(
                                          color: Colors.amberAccent.withValues(alpha: 0.6),
                                          blurRadius: 36,
                                          spreadRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  AnimatedScale(
                                    scale: 1.0 + (volume * 0.25),
                                    duration: const Duration(milliseconds: 80),
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      isBoosted
                                          ? Icons.local_fire_department_rounded
                                          : volume == 0.0
                                              ? Icons.volume_mute_rounded
                                              : volume < 0.3
                                                  ? Icons.volume_down_rounded
                                                  : Icons.volume_up_rounded,
                                      color: isBoosted ? Colors.amberAccent : Colors.white,
                                      size: isBoosted ? 24 : 20,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      child: Container(
                                        width: isBoosted ? 7 : 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Stack(
                                              alignment: Alignment.bottomCenter,
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 80),
                                                  curve: Curves.easeOutCubic,
                                                  height: constraints.maxHeight * fillRatio,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    gradient: isBoosted
                                                        ? const LinearGradient(
                                                            begin: Alignment.bottomCenter,
                                                            end: Alignment.topCenter,
                                                            colors: [
                                                              Colors.amber,
                                                              Colors.deepOrangeAccent,
                                                              Colors.redAccent,
                                                            ],
                                                          )
                                                        : null,
                                                    color: isBoosted ? null : theme.colorScheme.primary,
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isBoosted ? '🔥 ${(volume * 100).round()}%' : '${(volume * 100).round()}%',
                                    style: TextStyle(
                                      color: isBoosted ? Colors.amberAccent : Colors.white,
                                      fontSize: isBoosted ? 11 : 10,
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
            );
          },
        ),

        // 4. Brightness Apple-like Glowing Sun HUD
        Center(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _brightnessOpacity,
              duration: Duration(milliseconds: _brightnessOpacity == 0.0 ? 250 : 120),
              child: AnimatedScale(
                scale: _brightnessScale,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: _brightnessValue * 0.24),
                            blurRadius: 15 + _brightnessValue * 25,
                            spreadRadius: 2 + _brightnessValue * 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Transform.rotate(
                             angle: _brightnessValue * 2.0 * 3.1415926,
                             child: Icon(
                               Icons.light_mode_rounded,
                               color: Colors.white.withValues(alpha: 0.7 + _brightnessValue * 0.3),
                               size: 44,
                             ),
                           ),
                           const SizedBox(height: 12),
                          Text(
                            'Brightness: ${(_brightnessValue * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
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
    );
  }
}
