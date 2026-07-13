import '../../core/models/media_item.dart';

abstract interface class MediaScanner {
  Future<List<MediaItem>> pickFiles();
}
