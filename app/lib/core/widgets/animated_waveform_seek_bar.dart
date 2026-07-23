import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedWaveformSeekBar extends StatefulWidget {
  const AnimatedWaveformSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.playing = true,
    this.height = 24.0,
    this.activeColor,
    this.inactiveColor,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool playing;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  State<AnimatedWaveformSeekBar> createState() => _AnimatedWaveformSeekBarState();
}

class _AnimatedWaveformSeekBarState extends State<AnimatedWaveformSeekBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isDragging = false;
  double _dragFraction = 0.0;
  double _hoverFraction = -1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.playing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedWaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _currentFraction {
    if (_isDragging) return _dragFraction;
    final durMs = widget.duration.inMilliseconds;
    if (durMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / durMs).clamp(0.0, 1.0);
  }

  void _handleSeekFromDx(double dx, double width) {
    if (width <= 0) return;
    final frac = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragFraction = frac;
    });
  }

  void _commitSeek(double width) {
    if (width <= 0) return;
    final durMs = widget.duration.inMilliseconds;
    final targetMs = (_dragFraction * durMs).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCol = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveCol = widget.inactiveColor ?? theme.colorScheme.primary.withValues(alpha: 0.20);

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return MouseRegion(
            onHover: (event) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.size.width > 0) {
                setState(() {
                  _hoverFraction = (event.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                });
              }
            },
            onExit: (_) {
              setState(() {
                _hoverFraction = -1.0;
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  setState(() {
                    _isDragging = true;
                  });
                  _handleSeekFromDx(details.localPosition.dx, box.size.width);
                }
              },
              onPanUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  _handleSeekFromDx(details.localPosition.dx, box.size.width);
                }
              },
              onPanEnd: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  _commitSeek(box.size.width);
                }
                setState(() {
                  _isDragging = false;
                });
              },
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  _handleSeekFromDx(details.localPosition.dx, box.size.width);
                  _commitSeek(box.size.width);
                }
              },
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    fraction: _currentFraction,
                    hoverFraction: _hoverFraction,
                    phase: _controller.value * 2 * math.pi,
                    activeColor: activeCol,
                    inactiveColor: inactiveCol,
                    isDragging: _isDragging,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.fraction,
    required this.hoverFraction,
    required this.phase,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDragging,
  });

  final double fraction;
  final double hoverFraction;
  final double phase;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final width = size.width;
    final activeX = width * fraction;

    // Paint Background/Inactive Line
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final inactivePath = Path();
    inactivePath.moveTo(activeX, centerY);
    inactivePath.lineTo(width, centerY);
    canvas.drawPath(inactivePath, inactivePaint);

    // Paint Active Waveform Line
    if (activeX > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDragging ? 3.0 : 2.0
        ..strokeCap = StrokeCap.round;

      final wavePath = Path();
      const waveLength = 24.0;
      const waveAmplitude = 2.0;

      wavePath.moveTo(0, centerY);
      for (double x = 0; x <= activeX; x += 1.5) {
        final y = centerY + math.sin((x / waveLength * 2 * math.pi) - phase) * waveAmplitude;
        wavePath.lineTo(x, y);
      }
      canvas.drawPath(wavePath, activePaint);
    }

    // Draw Thumb/Node at Active Position
    final thumbRadius = isDragging ? 7.0 : 5.0;
    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final thumbGlow = Paint()
      ..color = activeColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(activeX, centerY), thumbRadius + 3.0, thumbGlow);
    canvas.drawCircle(Offset(activeX, centerY), thumbRadius, thumbPaint);

    // Draw Hover Preview Dot if hovering and not dragging
    if (!isDragging && hoverFraction >= 0 && hoverFraction <= 1.0) {
      final hoverX = width * hoverFraction;
      final hoverPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hoverX, centerY), 3.0, hoverPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.hoverFraction != hoverFraction ||
        oldDelegate.phase != phase ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
