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
    final statuses = await [
      Permission.audio,
      Permission.videos,
      Permission.storage,
    ].request();
    return statuses.values.any((status) => status.isGranted || status.isLimited) || statuses.values.every((status) => status.isPermanentlyDenied);
  }
}
