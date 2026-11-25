import 'package:flutter/material.dart';

class AuraColors {
  AuraColors._();

  // ==========================================
  // DARK MODE
  // ==========================================
  static const darkBackground = Color(0xFF101210);
  static const darkSurface = Color(0xFF191D19);
  static const darkCard = Color(0xFF222922);
  static const darkPrimary = Color(0xFFC1F36B);
  static const darkSecondary = Color(0xFFA5B4FC);
  static const darkAudio = Color(0xFF80DB78);
  static const darkVideo = Color(0xFFA5B4FC);
  static const darkWarning = Color(0xFFF5BE57);
  static const darkError = Color(0xFFFF6B65);
  static const darkTextPrimary = Color(0xFFF4F7F0);
  static const darkTextSecondary = Color(0xFFA6B0A0);
  static const darkDivider = Color(0xFF30382F);
  static const darkDisabled = Color(0xFF687064);
  static const darkProgressTrack = Color(0xFF343D32);
  static const darkOverlay = Color(0x99000000);

  // ==========================================
  // LIGHT MODE
  // ==========================================
  static const lightBackground = Color(0xFFF5F7F1);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF527B13);
  static const lightSecondary = Color(0xFF555FC1);
  static const lightAudio = Color(0xFF26834B);
  static const lightVideo = Color(0xFF555FC1);
  static const lightWarning = Color(0xFF956100);
  static const lightError = Color(0xFFC13E3A);
  static const lightTextPrimary = Color(0xFF171D15);
  static const lightTextSecondary = Color(0xFF697365);
  static const lightDivider = Color(0xFFDFE5D9);
  static const lightDisabled = Color(0xFFA1A99B);
  static const lightProgressTrack = Color(0xFFE1E8D9);
  static const lightOverlay = Color(0x66000000);

  // ==========================================
  // BRAND
  // ==========================================
  static const brandLime = Color(0xFFC1F36B);
  static const brandGraphite = Color(0xFF101210);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // ==========================================
  // THEME-AWARE HELPERS
  // ==========================================
  static Color background(bool isDark) =>
      isDark ? darkBackground : lightBackground;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color primary(bool isDark) => isDark ? darkPrimary : lightPrimary;
  static Color secondary(bool isDark) =>
      isDark ? darkSecondary : lightSecondary;
  static Color audio(bool isDark) => isDark ? darkAudio : lightAudio;
  static Color video(bool isDark) => isDark ? darkVideo : lightVideo;
  static Color warning(bool isDark) => isDark ? darkWarning : lightWarning;
  static Color error(bool isDark) => isDark ? darkError : lightError;
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;
  static Color divider(bool isDark) => isDark ? darkDivider : lightDivider;
  static Color disabled(bool isDark) => isDark ? darkDisabled : lightDisabled;
  static Color progressTrack(bool isDark) =>
      isDark ? darkProgressTrack : lightProgressTrack;
  static Color overlay(bool isDark) => isDark ? darkOverlay : lightOverlay;
}
