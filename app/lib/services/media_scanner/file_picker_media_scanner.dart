import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/models/media_item.dart';
import '../web/media_object_url_stub.dart'
    if (dart.library.html) '../web/media_object_url_web.dart';
import 'media_scanner.dart';

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

  @override
  Future<List<MediaItem>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: kIsWeb,
      withReadStream: false,
      lockParentWindow: true,
    );
    final files = result?.files ?? const <PlatformFile>[];
    final now = DateTime.now();
    return files.map((file) => _toMediaItem(file, now)).whereType<MediaItem>().toList(growable: false);
  }

  static MediaItem? _toMediaItem(PlatformFile file, DateTime addedAt) {
    final displayName = file.name.trim().isNotEmpty ? file.name : 'Untitled media';
    final extension = p.extension(displayName).replaceFirst('.', '').toLowerCase();
    if (!_extensions.contains(extension)) {
      return null;
    }

    final source = _sourceFor(file, displayName, extension);
    if (source == null || source.trim().isEmpty) {
      return null;
    }

    final title = p.basenameWithoutExtension(displayName).trim();
    return MediaItem(
      id: kIsWeb ? 'web:${file.name}:${file.size}:${addedAt.microsecondsSinceEpoch}' : source,
      title: title.isEmpty ? displayName : title,
      uri: source,
      kind: _isVideo(extension) ? MediaKind.video : MediaKind.audio,
      addedAt: addedAt,
    );
  }

  static String? _sourceFor(PlatformFile file, String displayName, String extension) {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return createMediaObjectUrl(bytes, _mimeTypeFor(extension));
    }
    return file.path ?? file.identifier ?? displayName;
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
