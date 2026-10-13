import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../features/downloader/data/models/download_task.dart';

/// SettingsService — singleton wrapper around SharedPreferences.
/// Stores and retrieves user-facing app preferences.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'SettingsService.initialize() must be called first');
    return _prefs!;
  }

  // ─── Theme ─────────────────────────────────────────────────────────────────

  ThemeMode getThemeMode() {
    final raw = _p.getString(AppConstants.prefThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark, // default: dark
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _p.setString(AppConstants.prefThemeMode, raw);
  }

  // ─── Default Quality ────────────────────────────────────────────────────────

  VideoQuality getDefaultQuality() {
    final raw = _p.getString(AppConstants.prefDefaultQuality);
    return switch (raw) {
      'best' => VideoQuality.best,
      'p1080' => VideoQuality.p1080,
      'p720' => VideoQuality.p720,
      'p480' => VideoQuality.p480,
      'p360' => VideoQuality.p360,
      _ => VideoQuality.best,
    };
  }

  Future<void> setDefaultQuality(VideoQuality quality) async {
    final raw = switch (quality) {
      VideoQuality.best => 'best',
      VideoQuality.p1080 => 'p1080',
      VideoQuality.p720 => 'p720',
      VideoQuality.p480 => 'p480',
      VideoQuality.p360 => 'p360',
    };
    await _p.setString(AppConstants.prefDefaultQuality, raw);
  }
}

