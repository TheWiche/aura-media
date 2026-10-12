class AppConstants {
  static const String appName = "Media's Download";
  static const int defaultMaxConcurrentDownloads = 2;

  // Notification Channel Constants
  static const String downloadChannelId = 'media_download_progress_channel';
  static const String downloadChannelName = 'Progreso de Descargas';
  static const String downloadChannelDesc = 'Notificaciones con progreso en tiempo real de descargas activas';

  static const String completeChannelId = 'media_download_complete_channel';
  static const String completeChannelName = 'Descargas Finalizadas';
  static const String completeChannelDesc = 'Notificaciones al finalizar o fallar descargas';

  // Foreground Task
  static const String foregroundNotificationTitle = "Media's Download en ejecución";
  static const String foregroundNotificationBody = "Administrando descargas en segundo plano";

  // Public Download Folder Name
  static const String appDownloadFolderName = "MediasDownload";
}

