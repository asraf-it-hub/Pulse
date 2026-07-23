import 'dart:io';

class ArtworkCacheService {
  ArtworkCacheService._();
  static final instance = ArtworkCacheService._();

  final Map<String, String> _cache = {};

  /// Resolves the raw artwork path or URI to a format suitable for the system notification.
  Future<String?> resolveArtwork(String mediaId, String? artPath) async {
    if (artPath == null || artPath.isEmpty) return null;
    if (_cache.containsKey(mediaId)) return _cache[mediaId];

    try {
      if (artPath.startsWith('http://') || artPath.startsWith('https://')) {
        _cache[mediaId] = artPath;
        return artPath;
      }

      final file = File(artPath);
      if (await file.exists()) {
        final uri = file.absolute.uri.toString();
        _cache[mediaId] = uri;
        return uri;
      }
    } catch (_) {}
    return null;
  }
}
