import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/bookmark_model.dart';

class HistoryController extends ChangeNotifier {
  HistoryController() {
    load();
  }

  final List<Bookmark> _bookmarks = [];
  bool _loading = false;

  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);
  bool get loading => _loading;

  List<Bookmark> getBookmarksForMedia(String mediaId) {
    return _bookmarks.where((b) => b.mediaId == mediaId).toList();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('pulse_bookmarks') ?? [];
      _bookmarks.clear();
      for (final jsonStr in raw) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        _bookmarks.add(Bookmark.fromJson(map));
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addBookmark({
    required String mediaId,
    required Duration position,
    required String note,
  }) async {
    final newBookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mediaId: mediaId,
      position: position,
      note: note.isEmpty ? 'Bookmark' : note,
      createdAt: DateTime.now(),
    );
    _bookmarks.insert(0, newBookmark);
    notifyListeners();
    await _save();
  }

  Future<void> removeBookmark(String id) async {
    _bookmarks.removeWhere((b) => b.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _bookmarks.map((b) => json.encode(b.toJson())).toList();
      await prefs.setStringList('pulse_bookmarks', rawList);
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }
}
