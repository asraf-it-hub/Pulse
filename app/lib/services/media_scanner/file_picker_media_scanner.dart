import 'dart:io' as io;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../thumbnails/video_thumbnail_service_stub.dart'
    if (dart.library.io) '../thumbnails/video_thumbnail_service_io.dart';

import '../../core/models/media_item.dart';
import '../web/media_object_url_stub.dart'
    if (dart.library.html) '../web/media_object_url_web.dart';
import 'media_scanner.dart';
import 'platform/media_file_discovery_stub.dart'
    if (dart.library.io) 'platform/media_file_discovery_io.dart';

class FilePickerMediaScanner implements MediaScanner {
  const FilePickerMediaScanner();

  static const _extensions = [
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'mp4',
    'mkv',
    'mov',
    'webm',
    'avi',
    'm4v',
  ];
  static const _mediaExtensionSet = {..._extensions};
  static const _subtitleExtensions = {'srt', 'vtt', 'ass', 'ssa'};

  @override
  Future<List<MediaItem>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [..._extensions, ..._subtitleExtensions],
      withData: kIsWeb,
      withReadStream: false,
      lockParentWindow: true,
    );
    final files = result?.files ?? const <PlatformFile>[];
    final now = DateTime.now();
    final items = <MediaItem>[];
    for (final file in files) {
      final item = await _toMediaItem(file, now);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  @override
  Future<List<MediaItem>> pickFolder() async {
    if (kIsWeb) {
      return pickFiles();
    }
    final folder = await FilePicker.platform.getDirectoryPath(lockParentWindow: true);
    if (folder == null || folder.trim().isEmpty) {
      return const [];
    }
    final discovered = await discoverMediaFilesInFolder(
      folderPath: folder,
      mediaExtensions: _mediaExtensionSet,
      subtitleExtensions: _subtitleExtensions,
    );
    return _itemsFromDiscovered(discovered, DateTime.now());
  }

  @override
  Future<List<MediaItem>> fromPaths(List<String> paths) async {
    if (kIsWeb) {
      return const [];
    }
    final discovered = <DiscoveredMediaFile>[];
    for (final path in paths.where((path) => path.trim().isNotEmpty)) {
      final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
      if (_mediaExtensionSet.contains(extension)) {
        discovered.add(DiscoveredMediaFile(path: path));
      } else {
        discovered.addAll(await discoverMediaFilesInFolder(
          folderPath: path,
          mediaExtensions: _mediaExtensionSet,
          subtitleExtensions: _subtitleExtensions,
        ));
      }
    }
    return _itemsFromDiscovered(discovered, DateTime.now());
  }

  static Future<List<MediaItem>> _itemsFromDiscovered(List<DiscoveredMediaFile> files, DateTime addedAt) async {
    final items = <MediaItem>[];
    for (final file in files) {
      final extension = p.extension(file.path).replaceFirst('.', '').toLowerCase();
      final item = await _nativePathToMediaItem(
        path: file.path,
        displayName: displayNameForPath(file.path),
        extension: extension,
        addedAt: addedAt,
        subtitlePaths: file.subtitlePaths,
      );
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  static Future<MediaItem?> _toMediaItem(PlatformFile file, DateTime addedAt) async {
    final displayName = file.name.trim().isNotEmpty ? file.name : 'Untitled media';
    final extension = p.extension(displayName).replaceFirst('.', '').toLowerCase();
    if (!_mediaExtensionSet.contains(extension)) {
      return null;
    }

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final uri = createMediaObjectUrl(bytes, _mimeTypeFor(extension));
      final title = p.basenameWithoutExtension(displayName).trim();
      return MediaItem(
        id: 'web:${file.name}:${file.size}:${addedAt.microsecondsSinceEpoch}',
        title: title.isEmpty ? displayName : title,
        uri: uri,
        kind: _isVideo(extension) ? MediaKind.video : MediaKind.audio,
        addedAt: addedAt,
      );
    }

    final path = file.path ?? file.identifier;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return _nativePathToMediaItem(
      path: path,
      displayName: displayName,
      extension: extension,
      addedAt: addedAt,
    );
  }

  static Future<MediaItem?> _nativePathToMediaItem({
    required String path,
    required String displayName,
    required String extension,
    required DateTime addedAt,
    List<String> subtitlePaths = const [],
  }) async {
    if (!_mediaExtensionSet.contains(extension)) {
      return null;
    }

    final kind = _isVideo(extension) ? MediaKind.video : MediaKind.audio;
    final fallbackTitle = p.basenameWithoutExtension(displayName).trim();

    String title = fallbackTitle;
    String? artist;
    String? album;
    String? genre;
    Duration? duration;
    String? thumbnailUri;

    if (!kIsWeb && kind == MediaKind.audio) {
      try {
        final file = io.File(path);
        final meta = readMetadata(file, getImage: true);
        if (meta.title != null && meta.title!.trim().isNotEmpty) {
          title = meta.title!.trim();
        } else {
          final inferred = _inferAudioMetadata(fallbackTitle);
          title = inferred?.title ?? fallbackTitle;
          artist = inferred?.artist;
        }
        if (meta.artist != null && meta.artist!.trim().isNotEmpty) {
          artist = meta.artist!.trim();
        }
        if (meta.album != null && meta.album!.trim().isNotEmpty) {
          album = meta.album!.trim();
        }
        if (meta.genres.isNotEmpty) {
          genre = meta.genres.join(', ');
        }
        duration = meta.duration;

        if (meta.pictures.isNotEmpty) {
          try {
            final artBytes = meta.pictures.first.bytes;
            final fileName = 'pulse_art_${path.hashCode}.jpg';
            final destFile = p.join(io.Directory.systemTemp.path, fileName);
            final artFile = io.File(destFile);
            await artFile.writeAsBytes(artBytes);
            thumbnailUri = destFile;
          } catch (_) {}
        }
      } catch (_) {
        final inferred = _inferAudioMetadata(fallbackTitle);
        title = inferred?.title ?? fallbackTitle;
        artist = inferred?.artist;
      }
    } else {
      final inferred = _inferAudioMetadata(fallbackTitle);
      title = inferred?.title ?? fallbackTitle;
      artist = inferred?.artist;
    }

    if (kind == MediaKind.video) {
      thumbnailUri = await createVideoThumbnail(path);
    }

    return MediaItem(
      id: path,
      title: title,
      uri: path,
      kind: kind,
      artist: artist,
      album: album,
      genre: genre,
      duration: duration,
      addedAt: addedAt,
      folderPath: parentFolderOf(path),
      thumbnailUri: thumbnailUri,
      subtitleTracks: [
        for (final subtitlePath in subtitlePaths)
          SubtitleTrack(label: p.basename(subtitlePath), uri: subtitlePath),
      ],
    );
  }

  static _InferredMetadata? _inferAudioMetadata(String fallbackTitle) {
    final parts = fallbackTitle.split(' - ');
    if (parts.length >= 2) {
      return _InferredMetadata(
        artist: parts.first.trim(),
        title: parts.sublist(1).join(' - ').trim(),
      );
    }
    return _InferredMetadata(title: fallbackTitle);
  }

  static String _mimeTypeFor(String extension) {
    return switch (extension) {
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'mp4' || 'm4v' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'avi' => 'video/x-msvideo',
      _ => 'application/octet-stream',
    };
  }

  static bool _isVideo(String extension) {
    return const {'mp4', 'mkv', 'mov', 'webm', 'avi', 'm4v'}.contains(extension);
  }
}


class _InferredMetadata {
  const _InferredMetadata({this.title, this.artist});

  final String? title;
  final String? artist;
}


