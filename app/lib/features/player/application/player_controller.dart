import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/models/media_item.dart';
import '../../../services/player_engine/player_engine.dart';
import '../../library/application/library_controller.dart';

enum PulseRepeatMode { off, one, all }

class PlayerController extends ChangeNotifier {
  PlayerController({
    required PlayerEngine engine,
    required LibraryController libraryController,
  })  : _engine = engine,
        _libraryController = libraryController {
    _engine.snapshot.addListener(_onSnapshotChanged);
  }

  final PlayerEngine _engine;
  final LibraryController _libraryController;

  List<MediaItem> _queue = [];
  MediaItem? _current;
  bool _shuffle = false;
  PulseRepeatMode _repeatMode = PulseRepeatMode.off;
  Timer? _sleepTimer;

  ValueListenable<PlaybackSnapshot> get snapshot => _engine.snapshot;
  Object get platformPlayer => _engine.platformPlayer;
  List<MediaItem> get queue => List.unmodifiable(_queue);
  MediaItem? get current => _current;
  bool get shuffle => _shuffle;
  PulseRepeatMode get repeatMode => _repeatMode;
  bool get sleepTimerActive => _sleepTimer?.isActive ?? false;

  Future<void> playItem(MediaItem item, List<MediaItem> contextQueue) async {
    _queue = contextQueue.isEmpty ? [item] : contextQueue;
    _current = item;
    notifyListeners();
    await _engine.open(item);
    if (item.resumePosition > Duration.zero) {
      await _engine.seek(item.resumePosition);
    }
  }

  Future<void> togglePlay() async {
    if (_engine.snapshot.value.playing) {
      await _engine.pause();
    } else {
      await _engine.play();
    }
  }

  Future<void> seekRelative(Duration offset) async {
    final target = _engine.snapshot.value.position + offset;
    await _engine.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> seekTo(Duration position) => _engine.seek(position);

  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);

  Future<void> setSubtitleTrack(SubtitleTrack? track) => _engine.setSubtitleTrack(track);

  Future<void> next() async {
    final item = _nextItem();
    if (item != null) {
      await playItem(item, _queue);
    }
  }

  Future<void> previous() async {
    if (_current == null || _queue.isEmpty) {
      return;
    }
    final index = _queue.indexWhere((item) => item.id == _current!.id);
    final previousIndex = index <= 0 ? _queue.length - 1 : index - 1;
    await playItem(_queue[previousIndex], _queue);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = switch (_repeatMode) {
      PulseRepeatMode.off => PulseRepeatMode.all,
      PulseRepeatMode.all => PulseRepeatMode.one,
      PulseRepeatMode.one => PulseRepeatMode.off,
    };
    notifyListeners();
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, _engine.pause);
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    notifyListeners();
  }

  MediaItem? _nextItem() {
    if (_current == null || _queue.isEmpty) {
      return null;
    }
    if (_repeatMode == PulseRepeatMode.one) {
      return _current;
    }
    if (_shuffle && _queue.length > 1) {
      final candidates = _queue.where((item) => item.id != _current!.id).toList();
      return candidates[Random().nextInt(candidates.length)];
    }
    final index = _queue.indexWhere((item) => item.id == _current!.id);
    final nextIndex = index + 1;
    if (nextIndex < _queue.length) {
      return _queue[nextIndex];
    }
    return _repeatMode == PulseRepeatMode.all ? _queue.first : null;
  }

  void _onSnapshotChanged() {
    final item = _current;
    if (item != null) {
      _libraryController.markPlayed(item, _engine.snapshot.value.position);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _engine.snapshot.removeListener(_onSnapshotChanged);
    unawaited(_engine.dispose());
    super.dispose();
  }
}

