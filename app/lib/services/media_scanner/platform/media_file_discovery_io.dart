import 'dart:io';

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
  final root = Directory(folderPath);
  if (!root.existsSync()) {
    return const [];
  }

  final mediaPaths = <String>[];
  final subtitlesByStem = <String, List<String>>{};
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final extension = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
    if (mediaExtensions.contains(extension)) {
      mediaPaths.add(entity.path);
    } else if (subtitleExtensions.contains(extension)) {
      final stem = p.join(p.dirname(entity.path), p.basenameWithoutExtension(entity.path)).toLowerCase();
      subtitlesByStem.putIfAbsent(stem, () => []).add(entity.path);
    }
  }

  mediaPaths.sort();
  return [
    for (final mediaPath in mediaPaths)
      DiscoveredMediaFile(
        path: mediaPath,
        subtitlePaths: subtitlesByStem[p.join(p.dirname(mediaPath), p.basenameWithoutExtension(mediaPath)).toLowerCase()] ?? const [],
      ),
  ];
}

String? parentFolderOf(String path) => p.dirname(path);

String displayNameForPath(String path) => p.basename(path);
