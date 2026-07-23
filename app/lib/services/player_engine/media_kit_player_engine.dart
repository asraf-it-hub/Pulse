import 'dart:async';
import 'dart:io' as io;

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
      _player.stream.volume.listen((volume) => _update(volume: volume / 100.0)),
      _player.stream.tracks.listen((_) => _updateTracks()),
    ];
  }

  final mk.Player _player = mk.Player();
  final ValueNotifier<PlaybackSnapshot> _snapshot = ValueNotifier(const PlaybackSnapshot());
  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => _snapshot;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Object get platformPlayer => _player;

  @override
  Future<void> open(MediaItem item, {bool play = true}) async {
    await _player.open(mk.Media(item.uri), play: play);
    if (item.subtitleTracks.isNotEmpty) {
      await setSubtitleTrack(item.subtitleTracks.first);
    }
    _updateTracks();
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
  Future<void> setVolume(double volume) => _player.setVolume(volume * 100.0);

  @override
  Future<void> setSubtitleTrack(SubtitleTrack? track) async {
    if (track == null) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
    } else {
      final isUri = track.uri.startsWith('http') || track.uri.startsWith('file') || io.File(track.uri).existsSync();
      if (isUri) {
        await _player.setSubtitleTrack(mk.SubtitleTrack.uri(track.uri, title: track.label, language: track.language));
      } else {
        final matched = _player.state.tracks.subtitle.firstWhere(
          (t) => t.id == track.uri,
          orElse: () => _player.state.tracks.subtitle.first,
        );
        await _player.setSubtitleTrack(matched);
      }
    }
    _updateTracks();
  }

  @override
  Future<void> setAudioTrack(AudioTrack? track) async {
    if (track == null) {
      await _player.setAudioTrack(mk.AudioTrack.no());
    } else {
      final matched = _player.state.tracks.audio.firstWhere(
        (t) => t.id == track.id,
        orElse: () => _player.state.tracks.audio.first,
      );
      await _player.setAudioTrack(matched);
    }
    _updateTracks();
  }

  void _updateTracks() {
    final tracks = _player.state.tracks;
    final active = _player.state.track;

    final audioTracks = tracks.audio
        .map((t) => AudioTrack(
              label: t.title ?? t.language ?? t.id,
              id: t.id,
              language: t.language,
            ))
        .toList();

    final subtitleTracks = tracks.subtitle
        .map((t) => SubtitleTrack(
              label: t.title ?? t.language ?? t.id,
              uri: t.id,
              language: t.language,
            ))
        .toList();

    final selectedAudio = active.audio == mk.AudioTrack.no()
        ? null
        : AudioTrack(
            label: active.audio.title ?? active.audio.language ?? active.audio.id,
            id: active.audio.id,
            language: active.audio.language,
          );

    final selectedSubtitle = active.subtitle == mk.SubtitleTrack.no()
        ? null
        : SubtitleTrack(
            label: active.subtitle.title ?? active.subtitle.language ?? active.subtitle.id,
            uri: active.subtitle.id,
            language: active.subtitle.language,
          );

    final current = _snapshot.value;
    _snapshot.value = PlaybackSnapshot(
      position: current.position,
      duration: current.duration,
      playing: current.playing,
      buffering: current.buffering,
      speed: current.speed,
      volume: current.volume,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      selectedAudioTrack: selectedAudio,
      selectedSubtitleTrack: selectedSubtitle,
    );
  }

  void _update({
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? buffering,
    double? speed,
    double? volume,
  }) {
    final current = _snapshot.value;
    _snapshot.value = PlaybackSnapshot(
      position: position ?? current.position,
      duration: duration ?? current.duration,
      playing: playing ?? current.playing,
      buffering: buffering ?? current.buffering,
      speed: speed ?? current.speed,
      volume: volume ?? current.volume,
      audioTracks: current.audioTracks,
      subtitleTracks: current.subtitleTracks,
      selectedAudioTrack: current.selectedAudioTrack,
      selectedSubtitleTrack: current.selectedSubtitleTrack,
    );
  }

  @override
  Future<void> setEqualizer(List<double> gains, double preamp) async {
    try {
      final avgGain = gains.isEmpty ? 0.0 : gains.reduce((a, b) => a + b) / gains.length;
      final boost = (1.0 + (preamp / 12.0) + (avgGain / 24.0)).clamp(0.2, 3.0);
      final baseVol = _snapshot.value.volume;
      await _player.setVolume((baseVol * boost * 100.0).clamp(0.0, 200.0));
    } catch (e) {
      debugPrint('Equalizer error: $e');
    }
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
