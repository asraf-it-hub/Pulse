import 'package:flutter/foundation.dart';

import '../../core/models/media_item.dart';

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.speed = 1,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
  final bool buffering;
  final double speed;
}

abstract interface class PlayerEngine {
  ValueListenable<PlaybackSnapshot> get snapshot;
  Object get platformPlayer;

  Future<void> open(MediaItem item, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}
