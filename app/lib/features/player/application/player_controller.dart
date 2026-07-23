import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/audio/notification_service.dart';
import '../../../services/audio/media_session_service.dart';
import '../../../services/audio/background_audio_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/models/media_item.dart';
import '../../../main.dart';
import '../../../services/player_engine/player_engine.dart';
import '../../library/application/library_controller.dart';

enum PulseRepeatMode { off, one, all }

class PlayerController extends ChangeNotifier {
  PlayerController({
    required PlayerEngine engine,
    required LibraryController libraryController,
  })  : _engine = engine,
        _libraryController = libraryController {
    try {
      _notificationService = NotificationService(globalAudioHandler);
      _mediaSessionService = MediaSessionService(globalAudioHandler);
      _backgroundAudioService = BackgroundAudioService(
        onPause: pause,
        onPlay: play,
      );
      _backgroundAudioService?.initialize();

      _mediaSessionService?.registerCallbacks(
        onPlay: play,
        onPause: pause,
        onSeek: seekTo,
        onNext: next,
        onPrevious: previous,
        onCustomAction: _onCustomAction,
      );
    } catch (e) {
      debugPrint('Failed to initialize audio notification services: $e');
    }

    videoController = VideoController(_engine.platformPlayer as mk.Player);

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'pipModeChanged') {
        _isInPip = call.arguments as bool;
        notifyListeners();
      }
    });

    _engine.snapshot.addListener(_onSnapshotChanged);

    _completedSubscription = _engine.completedStream.listen((completed) {
      if (completed) {
        _onTrackCompleted();
      }
    });
  }

  static const _pipChannel = MethodChannel('com.example.pulse/pip');

  final PlayerEngine _engine;
  final LibraryController _libraryController;
  NotificationService? _notificationService;
  MediaSessionService? _mediaSessionService;
  BackgroundAudioService? _backgroundAudioService;
  StreamSubscription<bool>? _completedSubscription;

  List<MediaItem> _queue = [];
  MediaItem? _current;
  bool _shuffle = false;
  PulseRepeatMode _repeatMode = PulseRepeatMode.off;
  Timer? _sleepTimer;
  bool _isInPip = false;
  BoxFit _videoFit = BoxFit.contain;
  double? _videoAspectRatio;

  List<double> _equalizerGains = List.filled(10, 0.0);
  double _equalizerPreamp = 0.0;
  String _equalizerPreset = 'Flat';

  List<double> get equalizerGains => List.unmodifiable(_equalizerGains);
  double get equalizerPreamp => _equalizerPreamp;
  String get equalizerPreset => _equalizerPreset;

  void setEqualizer(String preset, List<double> gains, double preamp) {
    _equalizerPreset = preset;
    _equalizerGains = List.from(gains);
    _equalizerPreamp = preamp;
    _engine.setEqualizer(gains, preamp);
    notifyListeners();
  }

  BoxFit get videoFit => _videoFit;
  double? get videoAspectRatio => _videoAspectRatio;

  void setVideoFit(BoxFit fit) {
    _videoFit = fit;
    notifyListeners();
  }

  void setVideoAspectRatio(double? ratio) {
    _videoAspectRatio = ratio;
    notifyListeners();
  }

  late final VideoController videoController;
  final ValueNotifier<String?> playerToast = ValueNotifier(null);
  Timer? _toastTimer;

  ValueListenable<PlaybackSnapshot> get snapshot => _engine.snapshot;
  Object get platformPlayer => _engine.platformPlayer;
  List<MediaItem> get queue => List.unmodifiable(_queue);
  MediaItem? get current => _current;
  bool get shuffle => _shuffle;
  PulseRepeatMode get repeatMode => _repeatMode;
  bool get sleepTimerActive => _sleepTimer?.isActive ?? false;
  bool get isInPip => _isInPip;

  void showToast(String message) {
    playerToast.value = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 700), () {
      playerToast.value = null;
    });
  }

  Future<void> playItem(MediaItem item, List<MediaItem> contextQueue) async {
    _queue = contextQueue.isEmpty ? [item] : contextQueue;
    _current = item;
    notifyListeners();

    unawaited(updateSystemNotification());

    await _engine.open(item);
    await play();
  }

  Future<void> resumeItemAtPosition(MediaItem item, List<MediaItem> contextQueue, Duration position) async {
    await playItem(item, contextQueue);
    if (position > Duration.zero) {
      int elapsed = 0;
      while (_engine.snapshot.value.duration == Duration.zero && elapsed < 400) {
        await Future.delayed(const Duration(milliseconds: 50));
        elapsed += 50;
      }
      await _engine.seek(position);
    }
  }

  Future<void> play() => _engine.play();
  Future<void> pause() => _engine.pause();

  Future<void> enterPip() async {
    if (kIsWeb) return;
    try {
      await _pipChannel.invokeMethod('enterPip');
    } catch (_) {}
  }

  Future<void> setWantsPip(bool wants) async {
    if (kIsWeb) return;
    try {
      await _pipChannel.invokeMethod('setWantsPip', wants);
    } catch (_) {}
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
    showToast(offset.isNegative ? 'Back ${offset.inSeconds.abs()}s' : 'Forward ${offset.inSeconds}s');
  }

  Future<void> seekTo(Duration position) => _engine.seek(position);

  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);

  double _volumeBeforeMute = 1.0;

  Future<void> setVolume(double volume) async {
    await _engine.setVolume(volume);
    showToast('Volume: ${(volume * 100).round()}%');
  }

  Future<void> toggleMute() async {
    final current = _engine.snapshot.value.volume;
    if (current > 0.0) {
      _volumeBeforeMute = current;
      await _engine.setVolume(0.0);
      showToast('Muted');
    } else {
      final restored = _volumeBeforeMute == 0.0 ? 1.0 : _volumeBeforeMute;
      await setVolume(restored);
    }
  }

  Future<void> setSubtitleTrack(SubtitleTrack? track) => _engine.setSubtitleTrack(track);

  Future<void> setAudioTrack(AudioTrack? track) => _engine.setAudioTrack(track);

  Future<void> loadExternalSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final track = SubtitleTrack(
          label: 'External: $name',
          uri: path,
        );
        await setSubtitleTrack(track);
        showToast('Subtitles loaded');
      }
    } catch (_) {
      showToast('Failed to load subtitle');
    }
  }

  void addToQueue(MediaItem item) {
    if (_queue.any((q) => q.id == item.id)) {
      showToast('Already in queue');
      return;
    }
    _queue = [..._queue, item];
    notifyListeners();
    showToast('Added to queue');
  }

  void playNext(MediaItem item) {
    final list = _queue.where((q) => q.id != item.id).toList();
    if (_current == null) {
      _queue = [item, ...list];
      playItem(item, _queue);
      return;
    }
    final currentIndex = list.indexWhere((q) => q.id == _current!.id);
    if (currentIndex == -1) {
      _queue = [_current!, item, ...list];
    } else {
      list.insert(currentIndex + 1, item);
      _queue = list;
    }
    notifyListeners();
    showToast('Will play next');
  }

  void removeFromQueue(String itemId) {
    if (_current?.id == itemId) {
      showToast('Cannot remove active track');
      return;
    }
    _queue = _queue.where((item) => item.id != itemId).toList();
    notifyListeners();
    showToast('Removed from queue');
  }

  void clearQueue() {
    if (_current != null) {
      _queue = [_current!];
    } else {
      _queue = [];
    }
    notifyListeners();
    showToast('Queue cleared');
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex > _queue.length) return;
    final list = List<MediaItem>.from(_queue);
    int targetIndex = newIndex;
    if (oldIndex < newIndex) {
      targetIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(targetIndex, item);
    _queue = list;
    notifyListeners();
  }

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

  Timer? _fadeTimer;

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();

    final fadeStart = duration - const Duration(seconds: 30);
    if (fadeStart > Duration.zero) {
      _fadeTimer = Timer(fadeStart, () {
        final startVol = _engine.snapshot.value.volume;
        var step = 0;
        Timer.periodic(const Duration(seconds: 1), (timer) {
          step++;
          final currentVol = (startVol * (1.0 - (step / 30))).clamp(0.0, 1.0);
          _engine.setVolume(currentVol);
          if (step >= 30) timer.cancel();
        });
      });
    }

    _sleepTimer = Timer(duration, () {
      _engine.pause();
      showToast('Sleep timer finished');
    });
    notifyListeners();
    showToast('Sleep timer set for ${duration.inMinutes}m');
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer = null;
    notifyListeners();
    showToast('Sleep timer cancelled');
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

  Future<void> _onTrackCompleted() async {
    if (_current == null || _queue.isEmpty) return;

    if (_repeatMode == PulseRepeatMode.one) {
      await seekTo(Duration.zero);
      await play();
    } else {
      final nextTrack = _nextItem();
      if (nextTrack != null) {
        await playItem(nextTrack, _queue);
      } else {
        await pause();
      }
    }
  }

  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);

  void _onSnapshotChanged() {
    final item = _current;
    final snap = _engine.snapshot.value;
    if (item != null) {
      final now = DateTime.now();
      final shouldUpdatePosition =
          now.difference(_lastPositionSave).inSeconds >= 3 || !snap.playing;

      if (shouldUpdatePosition) {
        _lastPositionSave = now;
        _libraryController.markPlayed(item, snap.position);
        if (snap.position.inSeconds > 5 && snap.duration.inSeconds > 20) {
          unawaited(_saveLastPlayed(
            item.id,
            item.title,
            snap.position.inMilliseconds,
            item.isVideo,
          ));
        }
      }

      final isFav = item.isFavorite;
      final notifState = snap.buffering
          ? NotificationPlaybackState.buffering
          : snap.playing
              ? NotificationPlaybackState.playing
              : NotificationPlaybackState.paused;

      _notificationService?.updatePlaybackState(
        playing: snap.playing,
        position: snap.position,
        duration: snap.duration,
        speed: snap.speed,
        buffering: snap.buffering,
        state: notifState,
        isFavorite: isFav,
      );
    }
    notifyListeners();
  }

  Future<void> _onCustomAction(String name) async {
    if (name == 'favorite') {
      final currentItem = _current;
      if (currentItem != null) {
        await _libraryController.toggleFavorite(currentItem);
        _current = currentItem.copyWith(isFavorite: !currentItem.isFavorite);
        await updateSystemNotification();
      }
    } else if (name == 'queue') {
      showToast('Viewing Queue');
    } else if (name == 'rewind') {
      await seekRelative(const Duration(seconds: -10));
    } else if (name == 'fastForward') {
      await seekRelative(const Duration(seconds: 10));
    }
  }

  Future<void> updateSystemNotification() async {
    final item = _current;
    if (item == null) return;

    final isFav = item.isFavorite;
    await _notificationService?.updateMetadata(
      item: item,
      isFavorite: isFav,
    );

    final snap = _engine.snapshot.value;
    final notifState = snap.playing
        ? NotificationPlaybackState.playing
        : NotificationPlaybackState.paused;

    _notificationService?.updatePlaybackState(
      playing: snap.playing,
      position: snap.position,
      duration: snap.duration,
      speed: snap.speed,
      buffering: snap.buffering,
      state: notifState,
      isFavorite: isFav,
    );
  }

  Future<void> _saveLastPlayed(String id, String title, int positionMs, bool isVideo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('resume_id', id);
      await prefs.setString('resume_title', title);
      await prefs.setInt('resume_position', positionMs);
      await prefs.setBool('resume_is_video', isVideo);
    } catch (_) {}
  }

  Future<void> clearResumeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('resume_id');
      await prefs.remove('resume_title');
      await prefs.remove('resume_position');
      await prefs.remove('resume_is_video');
    } catch (_) {}
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _completedSubscription?.cancel();
    _engine.snapshot.removeListener(_onSnapshotChanged);
    _backgroundAudioService?.dispose();
    unawaited(_engine.dispose());
    super.dispose();
  }
}

