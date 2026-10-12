import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();
  PermissionService._();

  /// Request notification permission (Required on Android 13+ and iOS)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Request storage permissions based on platform and OS version
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      // iOS manages its sandbox via Info.plist and Documents directory
      return true;
    }

    // Android: check legacy storage or media permissions
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    // Check media permissions (Android 13+)
    final audioStatus = await Permission.audio.status;
    final videoStatus = await Permission.videos.status;
    if (audioStatus.isGranted && videoStatus.isGranted) return true;

    // Try requesting storage & media
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.audio,
      Permission.videos,
    ].request();

    final granted = statuses[Permission.storage]?.isGranted == true ||
        (statuses[Permission.audio]?.isGranted == true &&
            statuses[Permission.videos]?.isGranted == true);

    if (granted) return true;

    // Optional check for MANAGE_EXTERNAL_STORAGE on Android 11+ (API 30+)
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) return true;

    return false;
  }

  /// Check whether all necessary permissions are granted
  Future<bool> hasAllPermissions() async {
    final notifGranted = await Permission.notification.isGranted;
    if (Platform.isAndroid) {
      final storageGranted = await Permission.storage.isGranted ||
          (await Permission.audio.isGranted && await Permission.videos.isGranted) ||
          await Permission.manageExternalStorage.isGranted;
      return notifGranted && storageGranted;
    }
    return notifGranted;
  }
}

