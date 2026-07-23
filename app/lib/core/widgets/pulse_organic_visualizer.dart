import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/models/media_item.dart';

class PulseOrganicVisualizer extends StatefulWidget {
  const PulseOrganicVisualizer({
    required this.isPlaying,
    required this.item,
    this.accentColor,
    this.size = 300.0,
    super.key,
  });

  final bool isPlaying;
  final MediaItem item;
  final Color? accentColor;
  final double size;

  @override
  State<PulseOrganicVisualizer> createState() => _PulseOrganicVisualizerState();
}

class _PulseOrganicVisualizerState extends State<PulseOrganicVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final List<_OrbitParticle> _particles = List.generate(32, (index) => _OrbitParticle.random());

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(PulseOrganicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animController.repeat();
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.accentColor ?? theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.tertiary;

    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 60 FPS Organic Radial Wave & Particle Painter
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _OrganicHaloPainter(
                      progress: _animController.value,
                      isPlaying: widget.isPlaying,
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),

            // Centered Circular Artwork
            Container(
              width: widget.size * 0.58,
              height: widget.size * 0.58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.38),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildArtworkWidget(widget.item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkWidget(MediaItem item) {
    if (!kIsWeb && item.thumbnailUri != null && item.thumbnailUri!.isNotEmpty) {
      final file = io.File(item.thumbnailUri!);
      try {
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
    }

    return Container(
      color: Colors.black87,
      child: Center(
        child: Image.asset(
          'assets/brand/pulse-logo.png',
          width: widget.size * 0.34,
          height: widget.size * 0.34,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _OrbitParticle {
  _OrbitParticle({
    required this.radiusOffset,
    required this.speed,
    required this.angle,
    required this.size,
    required this.alpha,
  });

  factory _OrbitParticle.random() {
    final rand = math.Random();
    return _OrbitParticle(
      radiusOffset: rand.nextDouble() * 36.0,
      speed: (rand.nextDouble() * 0.8 + 0.4) * (rand.nextBool() ? 1 : -1),
      angle: rand.nextDouble() * math.pi * 2,
      size: rand.nextDouble() * 2.8 + 1.2,
      alpha: rand.nextDouble() * 0.6 + 0.4,
    );
  }

  final double radiusOffset;
  final double speed;
  double angle;
  final double size;
  final double alpha;
}

class _OrganicHaloPainter extends CustomPainter {
  _OrganicHaloPainter({
    required this.progress,
    required this.isPlaying,
    required this.primaryColor,
    required this.secondaryColor,
    required this.particles,
  });

  final double progress;
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;
  final List<_OrbitParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.29;
    final time = progress * math.pi * 2 * 16;

    // Sharp, ultra-responsive audio frequency dynamics
    final bassPulse = isPlaying ? math.pow(math.sin(time * 3.2).abs(), 2.2).toDouble() : 0.05;
    final midDeform = isPlaying ? math.sin(time * 5.8) : 0.02;
    final trebleRipples = isPlaying ? math.cos(time * 8.5) : 0.01;

    // 1. Draw Outer Bass Halo Bloom & Supercharged Energy Glow
    final haloPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18 + bassPulse * 0.24)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + bassPulse * 16);
    canvas.drawCircle(center, baseRadius + 24 + bassPulse * 22, haloPaint);

    // 2. Draw Organic Morphing Deformed Wave Rings
    for (int ring = 0; ring < 4; ring++) {
      final ringRadius = baseRadius + (ring * 14) + (bassPulse * 12);
      final wavePath = Path();
      const numPoints = 140;

      for (int i = 0; i <= numPoints; i++) {
        final theta = (i / numPoints) * math.pi * 2;
        final distortion = math.sin(theta * 7 + time * 1.2 + ring) * (8.0 + midDeform * 14.0) +
            math.cos(theta * 4 - time * 0.9 + ring * 0.5) * (6.0 + bassPulse * 10.0) +
            math.sin(theta * 12 + time * 2.0) * (2.0 + trebleRipples * 4.0);

        final r = ringRadius + distortion;
        final x = center.dx + r * math.cos(theta);
        final y = center.dy + r * math.sin(theta);

        if (i == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      wavePath.close();

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - (ring * 0.4)
        ..color = Color.lerp(primaryColor, secondaryColor, ring / 4.0)!
            .withValues(alpha: (0.85 - (ring * 0.18)) * (isPlaying ? 1.0 : 0.4));

      canvas.drawPath(wavePath, ringPaint);
    }

    // 3. Draw Orbiting Treble Particles & Shimmering Light Trails
    for (final p in particles) {
      if (isPlaying) {
        p.angle += p.speed * (0.018 + trebleRipples * 0.01);
      }
      final r = baseRadius + 30 + p.radiusOffset + (bassPulse * 12);
      final px = center.dx + r * math.cos(p.angle);
      final py = center.dy + r * math.sin(p.angle);

      final pPaint = Paint()
        ..color = primaryColor.withValues(alpha: (p.alpha + bassPulse * 0.3).clamp(0.0, 1.0) * (isPlaying ? 1.0 : 0.3))
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, p.size);

      canvas.drawCircle(Offset(px, py), p.size * (1.0 + bassPulse * 0.4), pPaint);
    }
  }

  @override
  bool shouldRepaint(_OrganicHaloPainter oldDelegate) => true;
}
