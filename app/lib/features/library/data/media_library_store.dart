import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/media_item.dart';

class MediaLibraryStore {
  const MediaLibraryStore();

  static const _itemsKey = 'pulse.media.items';

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
}
