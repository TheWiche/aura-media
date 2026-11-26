import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuraTypography {
  AuraTypography._();

  static TextStyle? _headingLarge;
  static TextStyle? _headingMedium;
  static TextStyle? _headingSmall;
  static TextStyle? _bodyLarge;
  static TextStyle? _bodyMedium;
  static TextStyle? _bodySmall;
  static TextStyle? _label;
  static TextStyle? _button;
  static TextStyle? _metricLarge;
  static TextStyle? _metricMedium;
  static TextStyle? _metricSmall;

  // Titles — Plus Jakarta Sans (cached for zero per-frame resolution overhead)
  static TextStyle get headingLarge =>
      _headingLarge ??= GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      );

  static TextStyle get headingMedium =>
      _headingMedium ??= GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle get headingSmall =>
      _headingSmall ??= GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  // Body — Inter
  static TextStyle get bodyLarge => _bodyLarge ??= GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => _bodyMedium ??= GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => _bodySmall ??= GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  // Labels and buttons
  static TextStyle get label => _label ??= GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get button => _button ??= GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      );

  // Download metrics — JetBrains Mono
  static TextStyle get metricLarge =>
      _metricLarge ??= GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      );

  static TextStyle get metricMedium =>
      _metricMedium ??= GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get metricSmall =>
      _metricSmall ??= GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
}
