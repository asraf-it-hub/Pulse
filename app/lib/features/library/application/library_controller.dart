import 'package:flutter/foundation.dart';

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
  LibraryFilter _filter = LibraryFilter.all;
  LibrarySort _sort = LibrarySort.recentlyAdded;
  String _query = '';
  bool _loading = true;
  String? _error;

  List<MediaItem> get items => List.unmodifiable(_items);
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
    } catch (error) {
      _error = 'Could not load the media library: $error';
    } finally {
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
    await _store.save(_items);
  }

  Future<void> toggleFavorite(MediaItem item) async {
    _replace(item.copyWith(isFavorite: !item.isFavorite));
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
}

