import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/media_item.dart';
import '../../../services/media_scanner/media_scanner.dart';
import '../../../services/permissions/media_permission_service.dart';
import '../data/media_library_store.dart';

enum LibraryFilter { all, videos, music, favorites, recent }

enum LibrarySort { title, recentlyAdded, recentlyPlayed }

class LibraryController extends ChangeNotifier {
  LibraryController({
    required MediaScanner scanner,
    MediaLibraryStore store = const MediaLibraryStore(),
    MediaPermissionService permissionService = const PermissionHandlerMediaPermissionService(),
  })  : _scanner = scanner,
        _store = store,
        _permissionService = permissionService;

  final MediaScanner _scanner;
  final MediaLibraryStore _store;
  final MediaPermissionService _permissionService;

  List<MediaItem> _items = [];
  List<Playlist> _playlists = [];
  LibraryFilter _filter = LibraryFilter.all;
  LibrarySort _sort = LibrarySort.recentlyAdded;
  String _query = '';
  bool _loading = true;
  String? _error;

  bool _syncing = false;
  bool get syncing => _syncing;
  Timer? _saveDebouncer;

  List<MediaItem> get items => List.unmodifiable(_items);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  LibraryFilter get filter => _filter;
  LibrarySort get sort => _sort;
  String get query => _query;
  bool get loading => _loading;
  String? get error => _error;

  List<MediaItem> get visibleItems {
    final normalizedQuery = _query.trim().toLowerCase();
    Iterable<MediaItem> output = _items;
    output = switch (_filter) {
      LibraryFilter.all => output,
      LibraryFilter.videos => output.where((item) => item.kind == MediaKind.video),
      LibraryFilter.music => output.where((item) => item.kind == MediaKind.audio),
      LibraryFilter.favorites => output.where((item) => item.isFavorite),
      LibraryFilter.recent => output.where((item) => item.lastPlayedAt != null),
    };
    if (normalizedQuery.isNotEmpty) {
      output = output.where((item) {
        return item.title.toLowerCase().contains(normalizedQuery) ||
            (item.artist?.toLowerCase().contains(normalizedQuery) ?? false) ||
            (item.album?.toLowerCase().contains(normalizedQuery) ?? false) ||
            (item.genre?.toLowerCase().contains(normalizedQuery) ?? false);
      });
    }
    final sorted = output.toList();
    sorted.sort((a, b) {
      return switch (_sort) {
        LibrarySort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        LibrarySort.recentlyAdded => (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)),
        LibrarySort.recentlyPlayed => (b.lastPlayedAt ?? DateTime(0)).compareTo(a.lastPlayedAt ?? DateTime(0)),
      };
    });
    return sorted;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _store.load();
      _playlists = await _store.loadPlaylists();
      _loading = false;
      notifyListeners();
      
      unawaited(autoScanMedia());
    } catch (error) {
      _error = 'Could not load the media library: $error';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> importFiles() => _importWith(_scanner.pickFiles, label: 'import media files');

  Future<void> importFolder() => _importWith(_scanner.pickFolder, label: 'scan folder');

  Future<void> importPaths(List<String> paths) => _importWith(() => _scanner.fromPaths(paths), label: 'import dropped media');

  Future<void> _importWith(Future<List<MediaItem>> Function() importAction, {required String label}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final allowed = await _permissionService.ensureMediaAccess();
      if (!allowed) {
        _error = 'Media permission is required to $label.';
        return;
      }
      final picked = await importAction();
      if (picked.isEmpty) {
        return;
      }
      _mergeItems(picked);
      _saveDebouncer?.cancel();
      await _store.save(_items);
    } catch (error) {
      _error = 'Could not $label: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markPlayed(MediaItem item, Duration position) async {
    _replace(item.copyWith(lastPlayedAt: DateTime.now(), resumePosition: position));
    _scheduleLibrarySave();
  }

  Future<void> updateItem(MediaItem updatedItem) async {
    final index = _items.indexWhere((i) => i.id == updatedItem.id);
    if (index != -1) {
      _items = List.from(_items)..[index] = updatedItem;
      notifyListeners();
      await _store.save(_items);
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    _replace(item.copyWith(isFavorite: !item.isFavorite));
    _saveDebouncer?.cancel();
    await _store.save(_items);
  }

  void setFilter(LibraryFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSort(LibrarySort sort) {
    _sort = sort;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void _mergeItems(List<MediaItem> incoming) {
    final merged = {for (final item in _items) item.id: item};
    for (final item in incoming) {
      final existing = merged[item.id];
      merged[item.id] = existing == null
          ? item
          : existing.copyWith(
              title: item.title,
              uri: item.uri,
              kind: item.kind,
              artist: item.artist,
              album: item.album,
              genre: item.genre,
              duration: item.duration,
              folderPath: item.folderPath,
              artworkUri: item.artworkUri,
              thumbnailUri: item.thumbnailUri,
              subtitleTracks: item.subtitleTracks,
            );
    }
    _items = merged.values.toList(growable: false);
  }

  void _replace(MediaItem replacement) {
    _items = [
      for (final item in _items) item.id == replacement.id ? replacement : item,
    ];
    notifyListeners();
  }



  Future<List<String>> _getDefaultScanPaths() async {
    final paths = <String>[];
    if (kIsWeb) return paths;

    if (io.Platform.isWindows) {
      final userProfile = io.Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        for (final folder in ['Music', 'Videos', 'Downloads']) {
          final dir = io.Directory(p.join(userProfile, folder));
          if (dir.existsSync()) {
            paths.add(dir.path);
          }
        }
      }
    } else if (io.Platform.isAndroid) {
      for (final folder in ['Music', 'Movies', 'Download', 'DCIM', 'Podcasts']) {
        final dir = io.Directory('/storage/emulated/0/$folder');
        if (dir.existsSync()) {
          paths.add(dir.path);
        }
      }
    } else if (io.Platform.isMacOS) {
      final home = io.Platform.environment['HOME'];
      if (home != null) {
        for (final folder in ['Music', 'Movies', 'Downloads']) {
          final dir = io.Directory(p.join(home, folder));
          if (dir.existsSync()) {
            paths.add(dir.path);
          }
        }
      }
    } else if (io.Platform.isLinux) {
      final home = io.Platform.environment['HOME'];
      if (home != null) {
        for (final folder in ['Music', 'Videos', 'Downloads']) {
          final dir = io.Directory(p.join(home, folder));
          if (dir.existsSync()) {
            paths.add(dir.path);
          }
        }
      }
    }
    return paths;
  }

  void _syncDiscoveredMedia(List<MediaItem> discovered) {
    final discoveredIds = discovered.map((item) => item.id).toSet();

    final cleanedItems = <MediaItem>[];
    for (final item in _items) {
      if (!item.uri.startsWith('http') && !item.uri.startsWith('blob')) {
        final file = io.File(item.uri);
        if (!file.existsSync() && !discoveredIds.contains(item.id)) {
          continue; // File deleted from disk, remove from library!
        }
      }
      cleanedItems.add(item);
    }

    _items = cleanedItems;
    _mergeItems(discovered);
  }

  Future<void> autoScanMedia({bool forceScan = false}) async {
    if (kIsWeb) return;
    if (_syncing) return;

    _syncing = true;
    notifyListeners();

    try {
      final allowed = await _permissionService.ensureMediaAccess();
      if (!allowed) {
        _error = 'Storage permission is required to auto-scan media.';
        return;
      }

      final scanPaths = await _getDefaultScanPaths();
      final discoveredItems = <MediaItem>[];

      for (final path in scanPaths) {
        try {
          final scanned = await _scanner.fromPaths([path]);
          discoveredItems.addAll(scanned);
        } catch (_) {}
      }

      _syncDiscoveredMedia(discoveredItems);
      _saveDebouncer?.cancel();
      await _store.save(_items);
    } catch (e) {
      _error = 'Auto-scan failed: $e';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> refreshLibrary({bool forceScan = false}) async {
    await autoScanMedia(forceScan: forceScan);
  }

  void _scheduleLibrarySave() {
    _saveDebouncer?.cancel();
    _saveDebouncer = Timer(const Duration(seconds: 3), () async {
      try {
        await _store.save(_items);
      } catch (_) {}
    });
  }

  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      itemIds: const [],
    );
    _playlists = [..._playlists, playlist];
    notifyListeners();
    await _store.savePlaylists(_playlists);
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists = _playlists.where((p) => p.id != playlistId).toList();
    notifyListeners();
    await _store.savePlaylists(_playlists);
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    _playlists = [
      for (final p in _playlists)
        p.id == playlistId ? p.copyWith(name: newName) : p,
    ];
    notifyListeners();
    await _store.savePlaylists(_playlists);
  }

  Future<void> addTrackToPlaylist(String playlistId, String itemId) async {
    _playlists = [
      for (final p in _playlists)
        if (p.id == playlistId)
          p.copyWith(
            itemIds: p.itemIds.contains(itemId) ? p.itemIds : [...p.itemIds, itemId],
          )
        else
          p,
    ];
    notifyListeners();
    await _store.savePlaylists(_playlists);
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String itemId) async {
    _playlists = [
      for (final p in _playlists)
        if (p.id == playlistId)
          p.copyWith(itemIds: p.itemIds.where((id) => id != itemId).toList())
        else
          p,
    ];
    notifyListeners();
    await _store.savePlaylists(_playlists);
  }

  @override
  void dispose() {
    _saveDebouncer?.cancel();
    _store.save(_items);
    _store.savePlaylists(_playlists);
    super.dispose();
  }
}

