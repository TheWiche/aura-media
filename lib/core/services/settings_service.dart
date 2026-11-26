import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../theme/aura_colors.dart';
import '../../features/downloader/data/models/download_task.dart';

enum ShareBehavior {
  modal,
  autoDownload,
  openApp,
}

enum AudioFileFormat {
  mp3,
  m4a,
  webm,
}

extension AudioFileFormatExtension on AudioFileFormat {
  String get shortLabel => switch (this) {
        AudioFileFormat.mp3 => 'MP3',
        AudioFileFormat.m4a => 'M4A',
        AudioFileFormat.webm => 'OPUS',
      };

  String get extensionName => name; // 'mp3', 'm4a', 'webm'

  String get description => switch (this) {
        AudioFileFormat.mp3 => 'Compatible en todos los reproductores',
        AudioFileFormat.m4a => 'AAC nativo para Android e iOS',
        AudioFileFormat.webm => 'Opus directo de YouTube (apps modernas)',
      };
}

enum VideoFormatPreference {
  auto,
  mp4,
  webm,
}

extension VideoFormatPreferenceExtension on VideoFormatPreference {
  String get label => switch (this) {
        VideoFormatPreference.auto => 'Auto (óptimo según resolución)',
        VideoFormatPreference.mp4 => 'MP4 (H.264 / AV1 · más compatible)',
        VideoFormatPreference.webm => 'WEBM (VP9 + Opus · reproductor moderno)',
      };

  String get shortLabel => switch (this) {
        VideoFormatPreference.auto => 'Auto',
        VideoFormatPreference.mp4 => 'MP4',
        VideoFormatPreference.webm => 'WEBM',
      };
}

enum DuplicateFilePolicy {
  rename,
  overwrite,
}

/// SettingsService — singleton wrapper around SharedPreferences.
/// Stores and retrieves user-facing app preferences across isolates.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  SharedPreferences? _prefs;

  /// Increments whenever any preference changes so listeners stay synced.
  final ValueNotifier<int> changesNotifier = ValueNotifier<int>(0);

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Reloads preferences from disk (essential when reading from background Isolate).
  Future<void> reload() async {
    await initialize();
    await _prefs?.reload();
  }

  bool get isInitialized => _prefs != null;

  SharedPreferences? get _pOrNull => _prefs;

  void _notifyChanged() {
    changesNotifier.value++;
  }

  // ─── Theme, AMOLED, Accent & Animations ────────────────────────────────────

  ThemeMode getThemeMode() {
    final raw = _pOrNull?.getString(AppConstants.prefThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await initialize();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs!.setString(AppConstants.prefThemeMode, raw);
    _notifyChanged();
  }

  bool getAmoledDark() {
    return _pOrNull?.getBool(AppConstants.prefAmoledDark) ?? false;
  }

  Future<void> setAmoledDark(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefAmoledDark, value);
    _notifyChanged();
  }

  AuraAccentPreset getAccentPreset() {
    final raw = _pOrNull?.getString(AppConstants.prefAccentPreset);
    return AuraAccentPreset.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AuraAccentPreset.lime,
    );
  }

  Future<void> setAccentPreset(AuraAccentPreset preset) async {
    await initialize();
    await _prefs!.setString(AppConstants.prefAccentPreset, preset.name);
    _notifyChanged();
  }

  bool getReduceAnimations() {
    return _pOrNull?.getBool(AppConstants.prefReduceAnimations) ?? false;
  }

  Future<void> setReduceAnimations(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefReduceAnimations, value);
    _notifyChanged();
  }

  // ─── Preferred Media Players ───────────────────────────────────────────────

  String? getAudioPlayerPackage() {
    final val = _pOrNull?.getString(AppConstants.prefAudioPlayerPackage)?.trim();
    return (val == null || val.isEmpty) ? null : val;
  }

  String? getAudioPlayerName() {
    final val = _pOrNull?.getString(AppConstants.prefAudioPlayerName)?.trim();
    return (val == null || val.isEmpty) ? null : val;
  }

  Future<void> setAudioPlayer({String? packageName, String? appName}) async {
    await initialize();
    if (packageName == null || packageName.trim().isEmpty) {
      await _prefs!.remove(AppConstants.prefAudioPlayerPackage);
      await _prefs!.remove(AppConstants.prefAudioPlayerName);
    } else {
      await _prefs!.setString(
        AppConstants.prefAudioPlayerPackage,
        packageName.trim(),
      );
      if (appName != null && appName.trim().isNotEmpty) {
        await _prefs!.setString(
          AppConstants.prefAudioPlayerName,
          appName.trim(),
        );
      }
    }
    _notifyChanged();
  }

  String? getVideoPlayerPackage() {
    final val = _pOrNull?.getString(AppConstants.prefVideoPlayerPackage)?.trim();
    return (val == null || val.isEmpty) ? null : val;
  }

  String? getVideoPlayerName() {
    final val = _pOrNull?.getString(AppConstants.prefVideoPlayerName)?.trim();
    return (val == null || val.isEmpty) ? null : val;
  }

  Future<void> setVideoPlayer({String? packageName, String? appName}) async {
    await initialize();
    if (packageName == null || packageName.trim().isEmpty) {
      await _prefs!.remove(AppConstants.prefVideoPlayerPackage);
      await _prefs!.remove(AppConstants.prefVideoPlayerName);
    } else {
      await _prefs!.setString(
        AppConstants.prefVideoPlayerPackage,
        packageName.trim(),
      );
      if (appName != null && appName.trim().isNotEmpty) {
        await _prefs!.setString(
          AppConstants.prefVideoPlayerName,
          appName.trim(),
        );
      }
    }
    _notifyChanged();
  }

  // ─── Default Format & Quality ──────────────────────────────────────────────

  MediaType getDefaultMediaType() {
    final raw = _pOrNull?.getString(AppConstants.prefDefaultMediaType);
    return switch (raw) {
      'video' => MediaType.video,
      'audio' => MediaType.audio,
      _ => MediaType.audio,
    };
  }

  Future<void> setDefaultMediaType(MediaType type) async {
    await initialize();
    final raw = type == MediaType.video ? 'video' : 'audio';
    await _prefs!.setString(AppConstants.prefDefaultMediaType, raw);
    _notifyChanged();
  }

  VideoQuality getDefaultQuality() {
    final raw = _pOrNull?.getString(AppConstants.prefDefaultQuality);
    return switch (raw) {
      'best' => VideoQuality.best,
      'p2160' => VideoQuality.p2160,
      'p1440' => VideoQuality.p1440,
      'p1080' => VideoQuality.p1080,
      'p720' => VideoQuality.p720,
      'p480' => VideoQuality.p480,
      'p360' => VideoQuality.p360,
      'p240' => VideoQuality.p240,
      'p144' => VideoQuality.p144,
      _ => VideoQuality.best,
    };
  }

  Future<void> setDefaultQuality(VideoQuality quality) async {
    await initialize();
    await _prefs!.setString(AppConstants.prefDefaultQuality, quality.name);
    _notifyChanged();
  }

  VideoFormatPreference getDefaultVideoFormat() {
    final raw = _pOrNull?.getString(AppConstants.prefDefaultVideoFormat);
    return switch (raw) {
      'mp4' => VideoFormatPreference.mp4,
      'webm' => VideoFormatPreference.webm,
      _ => VideoFormatPreference.auto,
    };
  }

  Future<void> setDefaultVideoFormat(VideoFormatPreference format) async {
    await initialize();
    await _prefs!.setString(AppConstants.prefDefaultVideoFormat, format.name);
    _notifyChanged();
  }

  // ─── Share Modal Behavior ──────────────────────────────────────────────────

  ShareBehavior getShareBehavior() {
    final raw = _pOrNull?.getString(AppConstants.prefShareBehavior);
    return switch (raw) {
      'auto_download' => ShareBehavior.autoDownload,
      'open_app' => ShareBehavior.openApp,
      _ => ShareBehavior.modal,
    };
  }

  Future<void> setShareBehavior(ShareBehavior behavior) async {
    await initialize();
    final raw = switch (behavior) {
      ShareBehavior.modal => 'modal',
      ShareBehavior.autoDownload => 'auto_download',
      ShareBehavior.openApp => 'open_app',
    };
    await _prefs!.setString(AppConstants.prefShareBehavior, raw);
    _notifyChanged();
  }

  bool getAutoCloseShareModal() {
    return _pOrNull?.getBool(AppConstants.prefAutoCloseShareModal) ?? true;
  }

  Future<void> setAutoCloseShareModal(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefAutoCloseShareModal, value);
    _notifyChanged();
  }

  // ─── Download Directories (Separate Audio & Video) ─────────────────────────

  String? getAudioDownloadPath() {
    final path = _pOrNull?.getString(AppConstants.prefAudioDownloadPath)?.trim();
    return (path == null || path.isEmpty) ? null : path;
  }

  Future<void> setAudioDownloadPath(String? path) async {
    await initialize();
    if (path == null || path.trim().isEmpty) {
      await _prefs!.remove(AppConstants.prefAudioDownloadPath);
    } else {
      await _prefs!.setString(AppConstants.prefAudioDownloadPath, path.trim());
    }
    _notifyChanged();
  }

  String? getVideoDownloadPath() {
    final path = _pOrNull?.getString(AppConstants.prefVideoDownloadPath)?.trim();
    return (path == null || path.isEmpty) ? null : path;
  }

  Future<void> setVideoDownloadPath(String? path) async {
    await initialize();
    if (path == null || path.trim().isEmpty) {
      await _prefs!.remove(AppConstants.prefVideoDownloadPath);
    } else {
      await _prefs!.setString(AppConstants.prefVideoDownloadPath, path.trim());
    }
    _notifyChanged();
  }

  // ─── File & Naming Options ─────────────────────────────────────────────────

  AudioFileFormat getAudioFormat() {
    final raw = _pOrNull?.getString(AppConstants.prefAudioFormat);
    return switch (raw) {
      'm4a' => AudioFileFormat.m4a,
      'webm' || 'opus' => AudioFileFormat.webm,
      _ => AudioFileFormat.mp3,
    };
  }

  Future<void> setAudioFormat(AudioFileFormat format) async {
    await initialize();
    await _prefs!.setString(AppConstants.prefAudioFormat, format.name);
    _notifyChanged();
  }

  DuplicateFilePolicy getDuplicatePolicy() {
    final raw = _pOrNull?.getString(AppConstants.prefDuplicatePolicy);
    return raw == 'overwrite'
        ? DuplicateFilePolicy.overwrite
        : DuplicateFilePolicy.rename;
  }

  Future<void> setDuplicatePolicy(DuplicateFilePolicy policy) async {
    await initialize();
    await _prefs!.setString(
      AppConstants.prefDuplicatePolicy,
      policy == DuplicateFilePolicy.overwrite ? 'overwrite' : 'rename',
    );
    _notifyChanged();
  }

  bool getIncludeAuthorInFilename() {
    return _pOrNull?.getBool(AppConstants.prefIncludeAuthorInFilename) ?? false;
  }

  Future<void> setIncludeAuthorInFilename(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefIncludeAuthorInFilename, value);
    _notifyChanged();
  }

  bool getScanMediaLibrary() {
    return _pOrNull?.getBool(AppConstants.prefScanMediaLibrary) ?? true;
  }

  Future<void> setScanMediaLibrary(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefScanMediaLibrary, value);
    _notifyChanged();
  }

  // ─── Queue, Network & History ──────────────────────────────────────────────

  bool getWifiOnly() {
    return _pOrNull?.getBool(AppConstants.prefWifiOnly) ?? false;
  }

  Future<void> setWifiOnly(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefWifiOnly, value);
    _notifyChanged();
  }

  int getMaxConcurrentDownloads() {
    final val = _pOrNull?.getInt(AppConstants.prefMaxConcurrentDownloads) ??
        AppConstants.defaultMaxConcurrentDownloads;
    return val.clamp(1, 4);
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    await initialize();
    await _prefs!.setInt(AppConstants.prefMaxConcurrentDownloads, value.clamp(1, 4));
    _notifyChanged();
  }

  bool getSaveDownloadHistory() {
    return _pOrNull?.getBool(AppConstants.prefSaveDownloadHistory) ?? true;
  }

  Future<void> setSaveDownloadHistory(bool value) async {
    await initialize();
    await _prefs!.setBool(AppConstants.prefSaveDownloadHistory, value);
    _notifyChanged();
  }
}
