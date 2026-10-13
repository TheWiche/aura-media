/// AppConstants — Aura Media (rebranded from Media's Download)
class AppConstants {
  static const String appName = 'Aura';
  static const String appFullName = 'Aura Media';
  static const String appTagline = 'Download. Listen. Watch.';
  static const int defaultMaxConcurrentDownloads = 2;

  // Notification Channel Constants
  static const String downloadChannelId = 'aura_download_progress_channel';
  static const String downloadChannelName = 'Download Progress';
  static const String downloadChannelDesc = 'Real-time download progress notifications';

  static const String completeChannelId = 'aura_download_complete_channel';
  static const String completeChannelName = 'Download Complete';
  static const String completeChannelDesc = 'Notifications when downloads finish or fail';

  // Foreground Task
  static const String foregroundNotificationTitle = 'Aura running in background';
  static const String foregroundNotificationBody = 'Managing active downloads';

  // Download folder name
  static const String appDownloadFolderName = 'AuraMedia';

  // SharedPreferences keys
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefDefaultQuality = 'pref_default_quality';
}
