import 'package:flutter/material.dart';
import 'aura_colors.dart';
import 'aura_dimensions.dart';
import 'aura_typography.dart';

class AuraTheme {
  AuraTheme._();

  static ThemeData get dark => buildDark();
  static ThemeData get light => buildLight();

  static ThemeData buildDark({
    bool amoled = false,
    AuraAccentPreset accent = AuraAccentPreset.lime,
    bool reduceAnimations = false,
  }) {
    final background =
        amoled ? AuraColors.amoledBackground : AuraColors.darkBackground;
    final surface = amoled ? AuraColors.amoledSurface : AuraColors.darkSurface;
    final card = amoled ? AuraColors.amoledCard : AuraColors.darkCard;
    final divider = amoled ? AuraColors.amoledDivider : AuraColors.darkDivider;
    final progressTrack =
        amoled ? AuraColors.amoledProgressTrack : AuraColors.darkProgressTrack;

    final primary = accent.primary(true);
    final onPrimary = accent.onPrimary(true);

    final scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      secondary: AuraColors.darkSecondary,
      onSecondary: const Color(0xFF14151A),
      surface: surface,
      onSurface: AuraColors.darkTextPrimary,
      error: AuraColors.darkError,
      onError: AuraColors.white,
      outline: divider,
    );

    final tokens = AuraThemeTokens(
      background: background,
      surface: surface,
      card: card,
      primary: primary,
      onPrimary: onPrimary,
      secondary: AuraColors.darkSecondary,
      audio: AuraColors.darkAudio,
      video: AuraColors.darkVideo,
      warning: AuraColors.darkWarning,
      error: AuraColors.darkError,
      textPrimary: AuraColors.darkTextPrimary,
      textSecondary: AuraColors.darkTextSecondary,
      divider: divider,
      disabled: AuraColors.darkDisabled,
      progressTrack: progressTrack,
      isDark: true,
      isAmoled: amoled,
      reduceAnimations: reduceAnimations,
      accentPreset: accent,
    );

    return _buildTheme(
      scheme: scheme,
      tokens: tokens,
    );
  }

  static ThemeData buildLight({
    AuraAccentPreset accent = AuraAccentPreset.lime,
    bool reduceAnimations = false,
  }) {
    final primary = accent.primary(false);
    final onPrimary = accent.onPrimary(false);

    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      secondary: AuraColors.lightSecondary,
      onSecondary: AuraColors.white,
      surface: AuraColors.lightSurface,
      onSurface: AuraColors.lightTextPrimary,
      error: AuraColors.lightError,
      onError: AuraColors.white,
      outline: AuraColors.lightDivider,
    );

    final tokens = AuraThemeTokens(
      background: AuraColors.lightBackground,
      surface: AuraColors.lightSurface,
      card: AuraColors.lightCard,
      primary: primary,
      onPrimary: onPrimary,
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
      reduceAnimations: reduceAnimations,
      accentPreset: accent,
    );

    return _buildTheme(
      scheme: scheme,
      tokens: tokens,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required AuraThemeTokens tokens,
  }) {
    final typography = ThemeData(useMaterial3: true).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: tokens.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      dividerColor: tokens.divider,
      disabledColor: tokens.disabled,
      extensions: [tokens],
      pageTransitionsTheme: tokens.reduceAnimations
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
      textTheme: typography.copyWith(
        headlineLarge:
            AuraTypography.headingLarge.copyWith(color: tokens.textPrimary),
        headlineMedium:
            AuraTypography.headingMedium.copyWith(color: tokens.textPrimary),
        titleLarge:
            AuraTypography.headingMedium.copyWith(color: tokens.textPrimary),
        titleMedium:
            AuraTypography.headingSmall.copyWith(color: tokens.textPrimary),
        bodyLarge: AuraTypography.bodyLarge.copyWith(color: tokens.textPrimary),
        bodyMedium:
            AuraTypography.bodyMedium.copyWith(color: tokens.textPrimary),
        bodySmall:
            AuraTypography.bodySmall.copyWith(color: tokens.textSecondary),
        labelLarge: AuraTypography.label.copyWith(color: tokens.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle:
            AuraTypography.headingMedium.copyWith(color: tokens.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraDimensions.space4,
          vertical: AuraDimensions.space4,
        ),
        hintStyle:
            AuraTypography.bodyMedium.copyWith(color: tokens.textSecondary),
        border: const OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide(color: tokens.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, AuraDimensions.buttonHeight),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AuraDimensions.radiusMedium,
          ),
          textStyle: AuraTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.divider),
          minimumSize: const Size(0, AuraDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AuraDimensions.space4),
          shape: const RoundedRectangleBorder(
            borderRadius: AuraDimensions.radiusMedium,
          ),
          textStyle: AuraTypography.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AuraTypography.label,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: tokens.progressTrack,
        circularTrackColor: tokens.progressTrack,
        linearMinHeight: 6,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        height: AuraDimensions.navigationHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return AuraTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? scheme.primary : tokens.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? scheme.primary : tokens.textSecondary,
            size: AuraDimensions.iconSize,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusLarge,
          side: BorderSide(color: Colors.transparent),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusExtraLarge,
        ),
        elevation: tokens.isDark ? 0 : AuraDimensions.modalElevation,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.card,
        contentTextStyle:
            AuraTypography.bodyMedium.copyWith(color: tokens.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusMedium,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return tokens.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return tokens.divider;
        }),
      ),
      iconTheme: IconThemeData(
        color: tokens.textSecondary,
        size: AuraDimensions.iconSize,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
