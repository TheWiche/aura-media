import 'package:flutter/material.dart';
import 'aura_colors.dart';
import 'aura_dimensions.dart';
import 'aura_typography.dart';

class AuraTheme {
  AuraTheme._();

  // ==========================================
  // DARK THEME
  // ==========================================
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AuraColors.darkPrimary,
      onPrimary: Color(0xFF171D15),
      secondary: AuraColors.darkSecondary,
      onSecondary: Color(0xFF171D15),
      surface: AuraColors.darkSurface,
      onSurface: AuraColors.darkTextPrimary,
      error: AuraColors.darkError,
      onError: Color(0xFFFFFFFF),
      outline: AuraColors.darkDivider,
    );

    return _buildTheme(
      scheme: scheme,
      background: AuraColors.darkBackground,
      card: AuraColors.darkCard,
      textPrimary: AuraColors.darkTextPrimary,
      textSecondary: AuraColors.darkTextSecondary,
      divider: AuraColors.darkDivider,
      progressTrack: AuraColors.darkProgressTrack,
      disabled: AuraColors.darkDisabled,
      isDark: true,
    );
  }

  // ==========================================
  // LIGHT THEME
  // ==========================================
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AuraColors.lightPrimary,
      onPrimary: Color(0xFFFFFFFF),
      secondary: AuraColors.lightSecondary,
      onSecondary: Color(0xFFFFFFFF),
      surface: AuraColors.lightSurface,
      onSurface: AuraColors.lightTextPrimary,
      error: AuraColors.lightError,
      onError: Color(0xFFFFFFFF),
      outline: AuraColors.lightDivider,
    );

    return _buildTheme(
      scheme: scheme,
      background: AuraColors.lightBackground,
      card: AuraColors.lightCard,
      textPrimary: AuraColors.lightTextPrimary,
      textSecondary: AuraColors.lightTextSecondary,
      divider: AuraColors.lightDivider,
      progressTrack: AuraColors.lightProgressTrack,
      disabled: AuraColors.lightDisabled,
      isDark: false,
    );
  }

  // ==========================================
  // SHARED THEME BUILDER
  // ==========================================
  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color background,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
    required Color progressTrack,
    required Color disabled,
    required bool isDark,
  }) {
    final typography = ThemeData(useMaterial3: true).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      disabledColor: disabled,
      textTheme: typography.copyWith(
        headlineLarge: AuraTypography.headingLarge.copyWith(color: textPrimary),
        headlineMedium: AuraTypography.headingMedium.copyWith(color: textPrimary),
        titleLarge: AuraTypography.headingMedium.copyWith(color: textPrimary),
        titleMedium: AuraTypography.headingSmall.copyWith(color: textPrimary),
        bodyLarge: AuraTypography.bodyLarge.copyWith(color: textPrimary),
        bodyMedium: AuraTypography.bodyMedium.copyWith(color: textPrimary),
        bodySmall: AuraTypography.bodySmall.copyWith(color: textSecondary),
        labelLarge: AuraTypography.label.copyWith(color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AuraTypography.headingMedium.copyWith(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraDimensions.space4,
          vertical: AuraDimensions.space4,
        ),
        hintStyle: AuraTypography.bodyMedium.copyWith(color: textSecondary),
        border: const OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AuraDimensions.radiusMedium,
          borderSide: BorderSide(color: divider, width: 1),
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
          foregroundColor: textPrimary,
          side: BorderSide(color: divider),
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
        linearTrackColor: progressTrack,
        circularTrackColor: progressTrack,
        linearMinHeight: 6,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        height: AuraDimensions.navigationHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return AuraTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? scheme.primary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? scheme.primary : textSecondary,
            size: AuraDimensions.iconSize,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusLarge,
          side: BorderSide(color: Colors.transparent),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AuraColors.darkSurface : AuraColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusExtraLarge,
        ),
        elevation: isDark ? 0 : AuraDimensions.modalElevation,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: AuraTypography.bodyMedium.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusMedium,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
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
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return divider;
        }),
      ),
      iconTheme: IconThemeData(
        color: textSecondary,
        size: AuraDimensions.iconSize,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
