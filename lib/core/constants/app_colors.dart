import 'package:flutter/material.dart';

/// Aura Media — Premium Dark & Light color palette
class AppColors {
  // ─── Dark Theme ────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF080A0F);
  static const Color darkSurface = Color(0xFF111318);
  static const Color darkSurfaceVariant = Color(0xFF191C24);
  static const Color darkCard = Color(0xFF14171F);
  static const Color darkBorder = Color(0xFF1E2330);

  // ─── Light Theme ───────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF0F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E6EF);

  // ─── Brand / Accent (shared) ───────────────────────────────────────────────
  static const Color primary = Color(0xFF7C6FE0);      // Soft violet — premium
  static const Color primaryLight = Color(0xFF9D94E8);
  static const Color secondary = Color(0xFF4ECDC4);    // Teal accent
  static const Color accent = Color(0xFF3DDC84);       // Emerald success
  static const Color warning = Color(0xFFFFA63E);      // Warm amber
  static const Color error = Color(0xFFFF5C72);        // Soft rose

  // ─── Typography — Dark ─────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF0F2FF);
  static const Color darkTextSecondary = Color(0xFF8B92AB);
  static const Color darkTextMuted = Color(0xFF4D5570);

  // ─── Typography — Light ────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0D0F1A);
  static const Color lightTextSecondary = Color(0xFF505573);
  static const Color lightTextMuted = Color(0xFFA0A5C0);

  // ─── Status badges (shared) ────────────────────────────────────────────────
  static const Color statusQueued = Color(0xFF9C8FEB);
  static const Color statusDownloading = Color(0xFF4ECDC4);
  static const Color statusPaused = Color(0xFFFFA63E);
  static const Color statusCompleted = Color(0xFF3DDC84);
  static const Color statusFailed = Color(0xFFFF5C72);

  // ─── Legacy aliases (for backward compat) ─────────────────────────────────
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color surfaceVariant = darkSurfaceVariant;
  static const Color card = darkCard;
  static const Color border = darkBorder;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
}
