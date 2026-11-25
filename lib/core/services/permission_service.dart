import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  /// Check if the app has full or media storage permission
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    if (await Permission.audio.isGranted && await Permission.videos.isGranted) {
      return true;
    }
    return false;
  }

  /// Check if MANAGE_EXTERNAL_STORAGE is granted (needed for custom folders on Android 11+)
  Future<bool> hasManageExternalStorage() async {
    if (!Platform.isAndroid) return true;
    return await Permission.manageExternalStorage.isGranted;
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission (opens All Files Access on Android 11+)
  Future<bool> requestManageExternalStorage() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  /// Request storage permissions based on platform and OS version
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;

    final audioStatus = await Permission.audio.status;
    final videoStatus = await Permission.videos.status;
    if (audioStatus.isGranted && videoStatus.isGranted) return true;

    final Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.audio,
      Permission.videos,
    ].request();

    final granted = statuses[Permission.storage]?.isGranted == true ||
        (statuses[Permission.audio]?.isGranted == true &&
            statuses[Permission.videos]?.isGranted == true);

    if (granted) return true;

    return await Permission.manageExternalStorage.isGranted;
  }

  /// Check if Android battery optimization is disabled for Aura
  Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return false;
    }
  }

  /// Request exemption from Android battery optimizations so background downloads survive
  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        return true;
      }
      return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {
      return false;
    }
  }

  /// Check whether all necessary permissions are granted
  Future<bool> hasAllPermissions() async {
    final notifGranted = await Permission.notification.isGranted;
    final storageGranted = await hasStoragePermission();
    return notifGranted && storageGranted;
  }
}
