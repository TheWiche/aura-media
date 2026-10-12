import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../constants/app_constants.dart';

class BackgroundService {
  static BackgroundService? _instance;
  static BackgroundService get instance => _instance ??= BackgroundService._();
  BackgroundService._();

  bool _initialized = false;

  /// Initialize foreground task settings
  void initialize() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'media_download_fg_service',
        channelName: 'Servicio de Descarga en Segundo Plano',
        channelDescription: 'Mantiene las descargas activas en segundo plano',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
  }

  /// Start foreground task to prevent OS from killing downloads
  Future<void> startService({String? statusText}) async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        if (statusText != null) {
          await FlutterForegroundTask.updateService(
            notificationTitle: AppConstants.foregroundNotificationTitle,
            notificationText: statusText,
          );
        }
        return;
      }

      await FlutterForegroundTask.startService(
        notificationTitle: AppConstants.foregroundNotificationTitle,
        notificationText: statusText ?? AppConstants.foregroundNotificationBody,
        notificationIcon: null,
      );
    } catch (_) {
      // Foreground service error handled gracefully
    }
  }

  /// Update foreground service notification status text
  Future<void> updateService(String statusText) async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: AppConstants.foregroundNotificationTitle,
          notificationText: statusText,
        );
      }
    } catch (_) {}
  }

  /// Stop foreground task when all downloads are completed
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}

