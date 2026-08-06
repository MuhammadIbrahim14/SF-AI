import 'package:flutter/material.dart';

/// Centralized typography for SkillForge AI.
///
/// Uses a system font stack so Flutter Web does not need runtime requests to
/// fonts.gstatic.com. That keeps local/offline development stable on Chrome.
abstract final class AppTypography {
  static const String _displayFont = 'Segoe UI';
  static const String _bodyFont = 'Segoe UI';
  static const List<String> _fallbackFonts = <String>[
    'Arial',
    'Helvetica',
    'sans-serif',
  ];

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _displayFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _displayFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 45,
    fontWeight: FontWeight.w600,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _displayFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.22,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _displayFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _displayFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _displayFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.33,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _bodyFont,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  static TextTheme get textTheme => const TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
