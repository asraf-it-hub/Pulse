import 'package:flutter/foundation.dart';

import '../../core/models/media_item.dart';

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.speed = 1,
    this.volume = 1.0,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioTrack,
    this.selectedSubtitleTrack,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
  final bool buffering;
  final double speed;
  final double volume;
  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final AudioTrack? selectedAudioTrack;
  final SubtitleTrack? selectedSubtitleTrack;
}

abstract interface class PlayerEngine {
  ValueListenable<PlaybackSnapshot> get snapshot;
  Stream<bool> get completedStream;
  Object get platformPlayer;

  Future<void> open(MediaItem item, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> setSubtitleTrack(SubtitleTrack? track);
  Future<void> setAudioTrack(AudioTrack? track);
  Future<void> setEqualizer(List<double> gains, double preamp);
  Future<void> dispose();
}
