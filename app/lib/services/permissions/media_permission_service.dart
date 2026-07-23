import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

abstract interface class MediaPermissionService {
  Future<bool> ensureMediaAccess();
}

class PermissionHandlerMediaPermissionService implements MediaPermissionService {
  const PermissionHandlerMediaPermissionService();

  @override
  Future<bool> ensureMediaAccess() async {
    if (kIsWeb) {
      return true;
    }
    if (io.Platform.isWindows) {
      return true;
    }

    // 1. Check if any media permission is already granted
    final audioStatus = await Permission.audio.status;
    final videoStatus = await Permission.videos.status;
    final storageStatus = await Permission.storage.status;

    if (audioStatus.isGranted || videoStatus.isGranted || storageStatus.isGranted ||
        audioStatus.isLimited || videoStatus.isLimited || storageStatus.isLimited) {
      return true;
    }

    // 2. Request both notifications and media permissions in a single unified batch
    final statuses = await [
      Permission.audio,
      Permission.videos,
      Permission.storage,
      Permission.notification,
    ].request();

    // 3. Determine if media access is allowed
    final isAllowed = [
      statuses[Permission.audio],
      statuses[Permission.videos],
      statuses[Permission.storage],
    ].any((status) => status == PermissionStatus.granted || status == PermissionStatus.limited);

    if (!isAllowed) {
      final hasPermanentlyDenied = [
        statuses[Permission.audio],
        statuses[Permission.videos],
        statuses[Permission.storage],
      ].any((status) => status == PermissionStatus.permanentlyDenied);
      if (hasPermanentlyDenied) {
        await openAppSettings();
      }
    }
    return isAllowed;
  }
}
