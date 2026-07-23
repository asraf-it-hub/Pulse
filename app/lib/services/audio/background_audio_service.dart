import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';

class BackgroundAudioService {
  BackgroundAudioService({
    required VoidCallback onPause,
    required VoidCallback onPlay,
  })  : _onPause = onPause,
        _onPlay = onPlay;

  final VoidCallback _onPause;
  final VoidCallback _onPlay;

  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _noisySubscription;

  /// Initializes the background audio session and registers focus state listeners.
  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to incoming calls and priority media focus events
    _interruptionSubscription = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // For now-playing local music, we pause on duck
            _onPause();
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _onPause();
            break;
        }
      } else {
        if (event.type == AudioInterruptionType.duck || event.type == AudioInterruptionType.pause) {
          _onPlay();
        }
      }
    });

    // Listen to headphone jack pullout/unplug events
    _noisySubscription = session.becomingNoisyEventStream.listen((_) {
      _onPause();
    });
  }

  /// Releases resources and unregisters stream subscriptions.
  Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _noisySubscription?.cancel();
  }
}
