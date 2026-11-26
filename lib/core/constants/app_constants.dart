/// AppConstants — Aura Media
class AppConstants {
  static const String appName = 'Aura';
  static const String appFullName = 'Aura Media';
  static const String appTagline = 'Download. Listen. Watch.';
  static const int defaultMaxConcurrentDownloads = 2;

  // Notification Channel Constants
  static const String downloadChannelId = 'aura_download_progress_channel';
  static const String downloadChannelName = 'Download Progress';
  static const String downloadChannelDesc =
      'Real-time download progress notifications';

  static const String completeChannelId = 'aura_download_complete_channel';
  static const String completeChannelName = 'Download Complete';
  static const String completeChannelDesc =
      'Notifications when downloads finish or fail';

  // Foreground Task
  static const String foregroundNotificationTitle =
      'Aura ejecutándose en segundo plano';
  static const String foregroundNotificationBody =
      'Gestionando descargas activas';

  // Download folder names
  static const String appDownloadFolderName = 'AuraMedia';
  static const String defaultAudioSubfolder = 'Audio';
  static const String defaultVideoSubfolder = 'Video';

  // SharedPreferences keys
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefAmoledDark = 'pref_amoled_dark';
  static const String prefAccentPreset = 'pref_accent_preset';
  static const String prefReduceAnimations = 'pref_reduce_animations';
  static const String prefAudioPlayerPackage = 'pref_audio_player_package';
  static const String prefAudioPlayerName = 'pref_audio_player_name';
  static const String prefVideoPlayerPackage = 'pref_video_player_package';
  static const String prefVideoPlayerName = 'pref_video_player_name';

  static const String prefDefaultQuality = 'pref_default_quality';
  static const String prefDefaultMediaType = 'pref_default_media_type';
  static const String prefAudioDownloadPath = 'pref_audio_download_path';
  static const String prefVideoDownloadPath = 'pref_video_download_path';
  static const String prefShareBehavior = 'pref_share_behavior';
  static const String prefAutoCloseShareModal = 'pref_auto_close_share_modal';
  static const String prefAudioFormat = 'pref_audio_format';
  static const String prefDuplicatePolicy = 'pref_duplicate_policy';
  static const String prefIncludeAuthorInFilename =
      'pref_include_author_in_filename';
  static const String prefScanMediaLibrary = 'pref_scan_media_library';
  static const String prefWifiOnly = 'pref_wifi_only';
  static const String prefMaxConcurrentDownloads =
      'pref_max_concurrent_downloads';
  static const String prefSaveDownloadHistory = 'pref_save_download_history';

  // Task persistence & IPC keys
  static const String prefTasksHistory = 'aura_download_tasks_v1';
  static const String prefPendingEnqueueTasks = 'aura_pending_enqueue_tasks_v1';
  static const String prefPendingMainOpenUrl = 'aura_pending_main_open_url';
}
