import '../../core/models/media_item.dart';

abstract interface class MediaScanner {
  Future<List<MediaItem>> pickFiles();
  Future<List<MediaItem>> pickFolder();
  Future<List<MediaItem>> fromPaths(List<String> paths);
}
