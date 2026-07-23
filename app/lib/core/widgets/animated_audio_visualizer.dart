import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VisualizerMode { bars, circular, particles }

class AnimatedAudioVisualizer extends StatefulWidget {
  const AnimatedAudioVisualizer({
    required this.isPlaying,
    this.mode = VisualizerMode.bars,
    this.color,
    this.barCount = 32,
    super.key,
  });

  final bool isPlaying;
  final VisualizerMode mode;
  final Color? color;
  final int barCount;

  @override
  State<AnimatedAudioVisualizer> createState() => _AnimatedAudioVisualizerState();
}

class _AnimatedAudioVisualizerState extends State<AnimatedAudioVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _VisualizerPainter(
            progress: _controller.value,
            mode: widget.mode,
            barCount: widget.barCount,
            color: primaryColor,
            isPlaying: widget.isPlaying,
            random: _random,
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  _VisualizerPainter({
    required this.progress,
    required this.mode,
    required this.barCount,
    required this.color,
    required this.isPlaying,
    required this.random,
  });

  final double progress;
  final VisualizerMode mode;
  final int barCount;
  final Color color;
  final bool isPlaying;
  final math.Random random;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    switch (mode) {
      case VisualizerMode.bars:
        _paintBars(canvas, size);
        break;
      case VisualizerMode.circular:
        _paintCircular(canvas, size);
        break;
      case VisualizerMode.particles:
        _paintParticles(canvas, size);
        break;
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final barWidth = width / (barCount * 1.5);
    final gap = barWidth * 0.5;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap) + gap / 2;
      double factor = isPlaying
          ? (0.2 + 0.8 * math.sin((progress * 2 * math.pi) + (i * 0.4)).abs())
          : 0.08;
      
      // Dynamic noise
      if (isPlaying) {
        factor = (factor + (math.sin(i * 1.7 + progress * 10) * 0.15)).clamp(0.05, 1.0);
      }

      final barHeight = height * factor;
      final rect = Rect.fromLTWH(x, height - barHeight, barWidth, barHeight);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2));

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color,
            color.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.9),
          ],
        ).createShader(rect);

      canvas.drawRRect(rrect, paint);
    }
  }

  void _paintCircular(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.3;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, bgPaint);

    const numPoints = 64;
    final path = Path();

    for (int i = 0; i <= numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      double amp = isPlaying
          ? 12.0 * math.sin((angle * 4) + (progress * 2 * math.pi))
          : 2.0;

      final r = radius + amp;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, wavePaint);
  }

  void _paintParticles(Canvas canvas, Size size) {
    const numParticles = 24;
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < numParticles; i++) {
      final angle = (i / numParticles) * 2 * math.pi + (progress * math.pi);
      final distFactor = isPlaying
          ? (0.2 + 0.8 * ((math.sin((progress * 2 * math.pi) + i) + 1) / 2))
          : 0.15;
      final dist = (size.width * 0.35) * distFactor;

      final x = center.dx + dist * math.cos(angle);
      final y = center.dy + dist * math.sin(angle);

      final pRadius = isPlaying ? (3.0 + 4.0 * math.sin(i + progress * 5).abs()) : 2.5;
      final paint = Paint()
        ..color = color.withValues(alpha: isPlaying ? 0.7 : 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), pRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mode != mode ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color;
  }
}
