import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize local notification plugin and channels
  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationResponse,
  }) async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: onNotificationResponse,
    );

    _initialized = true;
  }

  /// Show or update a download progress notification
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int progress,
    int maxProgress = 100,
    String? subText,
  }) async {
    if (!_initialized) return;
    final androidDetails = AndroidNotificationDetails(
      AppConstants.downloadChannelId,
      AppConstants.downloadChannelName,
      channelDescription: AppConstants.downloadChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress.clamp(0, maxProgress),
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      subText: subText,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: subText ?? 'Descargando: $progress%',
      notificationDetails: details,
    );
  }

  /// Show download completed notification
  Future<void> showCompletedNotification({
    required int id,
    required String title,
    required String filePath,
  }) async {
    if (!_initialized) return;
    // Cancel the ongoing progress notification first
    await cancelNotification(id);

    final androidDetails = AndroidNotificationDetails(
      AppConstants.completeChannelId,
      AppConstants.completeChannelName,
      channelDescription: AppConstants.completeChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: '¡Descarga completada!',
      body: title,
      notificationDetails: details,
      payload: filePath,
    );
  }

  /// Show download error notification
  Future<void> showErrorNotification({
    required int id,
    required String title,
    required String error,
  }) async {
    if (!_initialized) return;
    await cancelNotification(id);

    final androidDetails = AndroidNotificationDetails(
      AppConstants.completeChannelId,
      AppConstants.completeChannelName,
      channelDescription: AppConstants.completeChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: 'Error en la descarga',
      body: '$title: $error',
      notificationDetails: details,
    );
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    await _notificationsPlugin.cancel(id: id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _notificationsPlugin.cancelAll();
  }
}

