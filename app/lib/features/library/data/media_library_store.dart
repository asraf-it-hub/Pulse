import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/media_item.dart';

class MediaLibraryStore {
  const MediaLibraryStore();

  static const _itemsKey = 'pulse.media.items';
  static const _playlistsKey = 'pulse.media.playlists';

  Future<List<MediaItem>> load() async {
    if (kIsWeb) {
      return const [];
    }
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_itemsKey) ?? const [];
    return rawItems
        .map((raw) => MediaItem.fromJson(jsonDecode(raw) as Map<String, Object?>))
        .toList();
  }

  Future<void> save(List<MediaItem> items) async {
    if (kIsWeb) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _itemsKey,
      items.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
  }

  Future<List<Playlist>> loadPlaylists() async {
    if (kIsWeb) {
      return const [];
    }
    final prefs = await SharedPreferences.getInstance();
    final rawPlaylists = prefs.getStringList(_playlistsKey) ?? const [];
    return rawPlaylists
        .map((raw) => Playlist.fromJson(jsonDecode(raw) as Map<String, Object?>))
        .toList();
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    if (kIsWeb) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _playlistsKey,
      playlists.map((playlist) => jsonEncode(playlist.toJson())).toList(growable: false),
    );
  }
}
