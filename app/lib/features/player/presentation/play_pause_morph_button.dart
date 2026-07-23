import 'package:flutter/material.dart';

class PlayPauseMorphButton extends StatefulWidget {
  const PlayPauseMorphButton({
    required this.playing,
    required this.onPressed,
    this.iconSize = 28,
    this.color,
    this.backgroundColor,
    super.key,
  });

  final bool playing;
  final VoidCallback onPressed;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;

  @override
  State<PlayPauseMorphButton> createState() => _PlayPauseMorphButtonState();
}

class _PlayPauseMorphButtonState extends State<PlayPauseMorphButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.playing ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant PlayPauseMorphButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      if (widget.playing) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    final foreground = widget.color ?? (widget.backgroundColor != null ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface);
    
    final iconWidget = AnimatedIcon(
      icon: AnimatedIcons.play_pause,
      progress: _controller,
      size: widget.iconSize,
      color: foreground,
    );

    if (widget.backgroundColor != null) {
      return IconButton.filled(
        iconSize: widget.iconSize,
        onPressed: widget.onPressed,
        icon: iconWidget,
        style: IconButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: foreground,
        ),
      );
    }

    return IconButton(
      iconSize: widget.iconSize,
      onPressed: widget.onPressed,
      icon: iconWidget,
    );
  }
}
