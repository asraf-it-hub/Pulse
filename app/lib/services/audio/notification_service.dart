import 'package:audio_service/audio_service.dart';
import '../../core/models/media_item.dart' as model;
import 'artwork_cache_service.dart';
import 'pulse_audio_handler.dart';

enum NotificationPlaybackState {
  idle,
  loading,
  playing,
  paused,
  buffering,
  completed,
  stopped,
  error,
}

class NotificationService {
  NotificationService(this._handler);

  final PulseAudioHandler _handler;

  /// Updates the metadata details in the notification.
  Future<void> updateMetadata({
    required model.MediaItem item,
    bool isFavorite = false,
  }) async {
    final artUri = await ArtworkCacheService.instance.resolveArtwork(item.id, item.artworkUri ?? item.thumbnailUri);
    
    _handler.mediaItem.add(MediaItem(
      id: item.id,
      album: item.album ?? 'Pulse Library',
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      duration: item.duration,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
      extras: {
        'favorite': isFavorite,
      },
    ));
  }

  /// Updates the playback state, controls list, and processing status in the notification.
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
    required double speed,
    required bool buffering,
    required NotificationPlaybackState state,
    bool isFavorite = false,
  }) {
    // Determine the correct processing state mapping
    final processingState = switch (state) {
      NotificationPlaybackState.idle => AudioProcessingState.idle,
      NotificationPlaybackState.loading => AudioProcessingState.loading,
      NotificationPlaybackState.playing => AudioProcessingState.ready,
      NotificationPlaybackState.paused => AudioProcessingState.ready,
      NotificationPlaybackState.buffering => AudioProcessingState.buffering,
      NotificationPlaybackState.completed => AudioProcessingState.completed,
      NotificationPlaybackState.stopped => AudioProcessingState.idle,
      NotificationPlaybackState.error => AudioProcessingState.error,
    };

    // Configure 7 action control options for expanded/collapsed layouts
    final controls = [
      MediaControl.custom(
        name: 'favorite',
        androidIcon: isFavorite ? 'drawable/ic_favorite_active' : 'drawable/ic_favorite_inactive',
        label: 'Favorite',
      ),
      MediaControl.skipToPrevious,
      MediaControl.rewind,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.fastForward,
      MediaControl.skipToNext,
      MediaControl.custom(
        name: 'queue',
        androidIcon: 'drawable/ic_queue',
        label: 'Queue',
      ),
    ];

    _handler.playbackState.add(PlaybackState(
      // Maps to expanded layout buttons list
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // Collapsed layout uses indices: 1 (Previous), 3 (Play/Pause), 5 (Next)
      androidCompactActionIndices: const [1, 3, 5],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: position,
      speed: speed,
      queueIndex: 0,
    ));
  }
}
