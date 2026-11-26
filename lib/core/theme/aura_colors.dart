import 'package:flutter/material.dart';

/// Curated accent color presets (Musicolet-style full app & logo recoloring).
enum AuraAccentPreset {
  lime(
    label: 'Lima',
    darkColor: Color(0xFFC1F36B),
    darkOnColor: Color(0xFF141810),
    lightColor: Color(0xFF527B13),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  emerald(
    label: 'Esmeralda',
    darkColor: Color(0xFF34D399),
    darkOnColor: Color(0xFF062118),
    lightColor: Color(0xFF059669),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  cyan(
    label: 'Cian',
    darkColor: Color(0xFF22D3EE),
    darkOnColor: Color(0xFF071E24),
    lightColor: Color(0xFF0E7490),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  blue(
    label: 'Azul',
    darkColor: Color(0xFF60A5FA),
    darkOnColor: Color(0xFF0B182E),
    lightColor: Color(0xFF2563EB),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  violet(
    label: 'Violeta',
    darkColor: Color(0xFFA78BFA),
    darkOnColor: Color(0xFF170F2E),
    lightColor: Color(0xFF6D28D9),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  pink(
    label: 'Rosa',
    darkColor: Color(0xFFF472B6),
    darkOnColor: Color(0xFF2B0B1B),
    lightColor: Color(0xFFDB2777),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  red(
    label: 'Carmesí',
    darkColor: Color(0xFFFB7185),
    darkOnColor: Color(0xFF2B0910),
    lightColor: Color(0xFFE11D48),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  amber(
    label: 'Ámbar',
    darkColor: Color(0xFFFBBF24),
    darkOnColor: Color(0xFF241904),
    lightColor: Color(0xFFD97706),
    lightOnColor: Color(0xFFFFFFFF),
  ),
  monochrome(
    label: 'Monocromo',
    darkColor: Color(0xFFF4F4F7),
    darkOnColor: Color(0xFF0E0E11),
    lightColor: Color(0xFF18181D),
    lightOnColor: Color(0xFFFFFFFF),
  );

  final String label;
  final Color darkColor;
  final Color darkOnColor;
  final Color lightColor;
  final Color lightOnColor;

  const AuraAccentPreset({
    required this.label,
    required this.darkColor,
    required this.darkOnColor,
    required this.lightColor,
    required this.lightOnColor,
  });

  Color primary(bool isDark) => isDark ? darkColor : lightColor;
  Color onPrimary(bool isDark) => isDark ? darkOnColor : lightOnColor;
}

class AuraColors {
  AuraColors._();

  // ==========================================
  // DARK MODE (Clean neutral charcoal — zero green tint)
  // ==========================================
  static const darkBackground = Color(0xFF0E0E11);
  static const darkSurface = Color(0xFF16161B);
  static const darkCard = Color(0xFF1E1E24);
  static const darkPrimary = Color(0xFFC1F36B);
  static const darkSecondary = Color(0xFFA5B4FC);
  static const darkAudio = Color(0xFF4ADE80);
  static const darkVideo = Color(0xFF818CF8);
  static const darkWarning = Color(0xFFF5BE57);
  static const darkError = Color(0xFFFF6B65);
  static const darkTextPrimary = Color(0xFFF4F4F6);
  static const darkTextSecondary = Color(0xFFA1A1AC);
  static const darkDivider = Color(0xFF2B2B33);
  static const darkDisabled = Color(0xFF656572);
  static const darkProgressTrack = Color(0xFF2A2A32);
  static const darkOverlay = Color(0x99000000);

  // ==========================================
  // AMOLED PURE BLACK MODE
  // ==========================================
  static const amoledBackground = Color(0xFF000000);
  static const amoledSurface = Color(0xFF09090B);
  static const amoledCard = Color(0xFF121216);
  static const amoledDivider = Color(0xFF23232A);
  static const amoledProgressTrack = Color(0xFF23232A);

  // ==========================================
  // LIGHT MODE (Clean neutral light)
  // ==========================================
  static const lightBackground = Color(0xFFF5F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF527B13);
  static const lightSecondary = Color(0xFF555FC1);
  static const lightAudio = Color(0xFF16A34A);
  static const lightVideo = Color(0xFF4F46E5);
  static const lightWarning = Color(0xFFB45309);
  static const lightError = Color(0xFFC13E3A);
  static const lightTextPrimary = Color(0xFF14151A);
  static const lightTextSecondary = Color(0xFF666974);
  static const lightDivider = Color(0xFFE2E4EA);
  static const lightDisabled = Color(0xFFA1A4AE);
  static const lightProgressTrack = Color(0xFFE4E6EC);
  static const lightOverlay = Color(0x66000000);

  // ==========================================
  // BRAND
  // ==========================================
  static const brandLime = Color(0xFFC1F36B);
  static const brandGraphite = Color(0xFF0E0E11);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // ==========================================
  // STATIC HELPERS (Fallback when no context tokens needed)
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

/// ThemeExtension carrying live background, AMOLED, accent, and animation settings.
@immutable
class AuraThemeTokens extends ThemeExtension<AuraThemeTokens> {
  final Color background;
  final Color surface;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color audio;
  final Color video;
  final Color warning;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color disabled;
  final Color progressTrack;
  final bool isDark;
  final bool isAmoled;
  final bool reduceAnimations;
  final AuraAccentPreset accentPreset;

  const AuraThemeTokens({
    required this.background,
    required this.surface,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.audio,
    required this.video,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.disabled,
    required this.progressTrack,
    required this.isDark,
    required this.isAmoled,
    required this.reduceAnimations,
    required this.accentPreset,
  });

  static AuraThemeTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<AuraThemeTokens>();
    if (ext != null) return ext;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? defaultDark : defaultLight;
  }

  static const AuraThemeTokens defaultDark = AuraThemeTokens(
    background: AuraColors.darkBackground,
    surface: AuraColors.darkSurface,
    card: AuraColors.darkCard,
    primary: AuraColors.darkPrimary,
    onPrimary: Color(0xFF141810),
    secondary: AuraColors.darkSecondary,
    audio: AuraColors.darkAudio,
    video: AuraColors.darkVideo,
    warning: AuraColors.darkWarning,
    error: AuraColors.darkError,
    textPrimary: AuraColors.darkTextPrimary,
    textSecondary: AuraColors.darkTextSecondary,
    divider: AuraColors.darkDivider,
    disabled: AuraColors.darkDisabled,
    progressTrack: AuraColors.darkProgressTrack,
    isDark: true,
    isAmoled: false,
    reduceAnimations: false,
    accentPreset: AuraAccentPreset.lime,
  );

  static const AuraThemeTokens defaultLight = AuraThemeTokens(
    background: AuraColors.lightBackground,
    surface: AuraColors.lightSurface,
    card: AuraColors.lightCard,
    primary: AuraColors.lightPrimary,
    onPrimary: AuraColors.white,
    secondary: AuraColors.lightSecondary,
    audio: AuraColors.lightAudio,
    video: AuraColors.lightVideo,
    warning: AuraColors.lightWarning,
    error: AuraColors.lightError,
    textPrimary: AuraColors.lightTextPrimary,
    textSecondary: AuraColors.lightTextSecondary,
    divider: AuraColors.lightDivider,
    disabled: AuraColors.lightDisabled,
    progressTrack: AuraColors.lightProgressTrack,
    isDark: false,
    isAmoled: false,
    reduceAnimations: false,
    accentPreset: AuraAccentPreset.lime,
  );

  @override
  AuraThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? audio,
    Color? video,
    Color? warning,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? disabled,
    Color? progressTrack,
    bool? isDark,
    bool? isAmoled,
    bool? reduceAnimations,
    AuraAccentPreset? accentPreset,
  }) {
    return AuraThemeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      audio: audio ?? this.audio,
      video: video ?? this.video,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      disabled: disabled ?? this.disabled,
      progressTrack: progressTrack ?? this.progressTrack,
      isDark: isDark ?? this.isDark,
      isAmoled: isAmoled ?? this.isAmoled,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      accentPreset: accentPreset ?? this.accentPreset,
    );
  }

  @override
  AuraThemeTokens lerp(ThemeExtension<AuraThemeTokens>? other, double t) {
    if (other is! AuraThemeTokens) return this;
    return AuraThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      audio: Color.lerp(audio, other.audio, t)!,
      video: Color.lerp(video, other.video, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
      isAmoled: t < 0.5 ? isAmoled : other.isAmoled,
      reduceAnimations: t < 0.5 ? reduceAnimations : other.reduceAnimations,
      accentPreset: t < 0.5 ? accentPreset : other.accentPreset,
    );
  }
}
