import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';

class PulseAudioHandler extends BaseAudioHandler {
  VoidCallback? onPlayCallback;
  VoidCallback? onPauseCallback;
  ValueSetter<Duration>? onSeekCallback;
  VoidCallback? onSkipToNextCallback;
  VoidCallback? onSkipToPreviousCallback;
  ValueSetter<String>? onCustomActionCallback;

  @override
  Future<void> rewind() async {
    if (onCustomActionCallback != null) onCustomActionCallback!('rewind');
  }

  @override
  Future<void> fastForward() async {
    if (onCustomActionCallback != null) onCustomActionCallback!('fastForward');
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (onCustomActionCallback != null) onCustomActionCallback!(name);
  }

  @override
  Future<void> play() async {
    if (onPlayCallback != null) onPlayCallback!();
  }

  @override
  Future<void> pause() async {
    if (onPauseCallback != null) onPauseCallback!();
  }

  @override
  Future<void> seek(Duration position) async {
    if (onSeekCallback != null) onSeekCallback!(position);
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNextCallback != null) onSkipToNextCallback!();
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPreviousCallback != null) onSkipToPreviousCallback!();
  }

  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
    required double speed,
    required bool buffering,
  }) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: buffering
          ? AudioProcessingState.buffering
          : playing
              ? AudioProcessingState.ready
              : AudioProcessingState.idle,
      playing: playing,
      updatePosition: position,
      bufferedPosition: position,
      speed: speed,
      queueIndex: 0,
    ));
  }

  void updateMetadata({
    required String id,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    String? artUri,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      album: album ?? 'Pulse Library',
      title: title,
      artist: artist ?? 'Unknown Artist',
      duration: duration,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
    ));
  }
}
