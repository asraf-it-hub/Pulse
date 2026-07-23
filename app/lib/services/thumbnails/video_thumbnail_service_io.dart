import 'dart:io';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:path/path.dart' as p;

Future<String?> createVideoThumbnail(String path) async {
  try {
    final thumbnail = FcNativeVideoThumbnail();
    // Cache the thumbnail using a hash of the file path
    final fileName = 'pulse_thumb_${path.hashCode}.jpg';
    final destFile = p.join(Directory.systemTemp.path, fileName);

    final file = File(destFile);
    if (file.existsSync()) {
      return destFile;
    }

    final success = await thumbnail.saveThumbnailToFile(
      srcFile: path,
      destFile: destFile,
      width: 180,
      height: 120,
      format: 'jpeg',
      quality: 80,
    );

    if (success && file.existsSync()) {
      return destFile;
    }
  } catch (_) {}
  return null;
}
