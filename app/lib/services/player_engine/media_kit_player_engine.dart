import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../../core/models/media_item.dart';
import 'player_engine.dart';

class MediaKitPlayerEngine implements PlayerEngine {
  MediaKitPlayerEngine() {
    _subscriptions = [
      _player.stream.position.listen((position) => _update(position: position)),
      _player.stream.duration.listen((duration) => _update(duration: duration)),
      _player.stream.playing.listen((playing) => _update(playing: playing)),
      _player.stream.buffering.listen((buffering) => _update(buffering: buffering)),
      _player.stream.rate.listen((speed) => _update(speed: speed)),
    ];
  }

  final mk.Player _player = mk.Player();
  final ValueNotifier<PlaybackSnapshot> _snapshot = ValueNotifier(const PlaybackSnapshot());
  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => _snapshot;

  @override
  Object get platformPlayer => _player;

  @override
  Future<void> open(MediaItem item, {bool play = true}) async {
    await _player.open(mk.Media(item.uri), play: play);
    if (item.subtitleTracks.isNotEmpty) {
      await setSubtitleTrack(item.subtitleTracks.first);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> setSubtitleTrack(SubtitleTrack? track) {
    if (track == null) {
      return _player.setSubtitleTrack(mk.SubtitleTrack.no());
    }
    return _player.setSubtitleTrack(mk.SubtitleTrack.uri(track.uri, title: track.label, language: track.language));
  }

  void _update({
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? buffering,
    double? speed,
  }) {
    final current = _snapshot.value;
    _snapshot.value = PlaybackSnapshot(
      position: position ?? current.position,
      duration: duration ?? current.duration,
      playing: playing ?? current.playing,
      buffering: buffering ?? current.buffering,
      speed: speed ?? current.speed,
    );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _snapshot.dispose();
    await _player.dispose();
  }
}
