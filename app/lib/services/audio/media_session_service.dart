import 'pulse_audio_handler.dart';

class MediaSessionService {
  MediaSessionService(this._handler);

  final PulseAudioHandler _handler;

  /// Registers core playbacks callbacks onto the global handler.
  void registerCallbacks({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration) onSeek,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
    required Future<void> Function(String) onCustomAction,
  }) {
    _handler.onPlayCallback = () => onPlay();
    _handler.onPauseCallback = () => onPause();
    _handler.onSeekCallback = (pos) => onSeek(pos);
    _handler.onSkipToNextCallback = () => onNext();
    _handler.onSkipToPreviousCallback = () => onPrevious();
    _handler.onCustomActionCallback = (action) => onCustomAction(action);
  }
}
