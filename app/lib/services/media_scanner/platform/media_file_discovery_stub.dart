import 'package:path/path.dart' as p;

class DiscoveredMediaFile {
  const DiscoveredMediaFile({required this.path, this.subtitlePaths = const []});

  final String path;
  final List<String> subtitlePaths;
}

Future<List<DiscoveredMediaFile>> discoverMediaFilesInFolder({
  required String folderPath,
  required Set<String> mediaExtensions,
  required Set<String> subtitleExtensions,
}) async {
  return const [];
}

String? parentFolderOf(String path) => null;

String displayNameForPath(String path) => p.basename(path);
