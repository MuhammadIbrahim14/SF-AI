import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/data/models/theme_settings_model.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Helper to parse hex colors
Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var hexColor = hex.trim().replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor';
  }
  if (hexColor.length == 8) {
    final value = int.tryParse(hexColor, radix: 16);
    return value == null ? null : Color(value);
  }
  return null;
}

Color _onColor(Color color) =>
    color.computeLuminance() > 0.45 ? Colors.black : Colors.white;

Color _readableSurface(Color color, Brightness brightness) {
  final luminance = color.computeLuminance();
  if (brightness == Brightness.dark && luminance > 0.24) {
    return Color.lerp(color, Colors.black, 0.72)!;
  }
  if (brightness == Brightness.light && luminance < 0.72) {
    return Color.lerp(color, Colors.white, 0.86)!;
  }
  return color;
}

/// SkillForge AI — Master Theme Configuration
/// Assembles colors, typography, and component themes into a single [ThemeData].
/// Now supports both dark and light themes.
abstract final class AppTheme {
  // ─── Design Tokens (Shared) ─────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // ─── Shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> get lightShadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get lightShadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get lightShadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get darkShadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get darkShadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get darkShadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════════

  /// The dark theme used across the entire application.
  static ThemeData darkTheme([ThemeSettingsModel? settings]) {
    final primary = _parseColor(settings?.primaryColor) ?? AppColors.primary;
    final secondary =
        _parseColor(settings?.secondaryColor) ?? AppColors.secondary;
    final accent = _parseColor(settings?.accentColor) ?? AppColors.accent;
    final background = _readableSurface(
      _parseColor(settings?.backgroundColor) ?? AppColors.scaffoldBackground,
      Brightness.dark,
    );
    final surface = _readableSurface(
      _parseColor(settings?.surfaceColor) ?? AppColors.surface,
      Brightness.dark,
    );
    final radius = settings?.borderRadius ?? 20.0;
    final elevation = settings?.cardElevation ?? 0.0;
    final cardSurface = settings?.glassmorphismEnabled == false
        ? surface
        : surface.withValues(alpha: 0.88);

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: _darkColorScheme(
        primary,
        secondary,
        accent,
        surface: surface,
      ),
      textTheme: textTheme,
      appBarTheme: _darkAppBarTheme(textTheme),
      cardTheme: _darkCardTheme(radius, elevation, cardSurface),
      elevatedButtonTheme: _elevatedButtonTheme(
        textTheme,
        _darkColorScheme(primary, secondary, accent, surface: surface),
        radius,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(textTheme, primary),
      textButtonTheme: _textButtonTheme(textTheme, primary),
      inputDecorationTheme: _darkInputDecorationTheme(
        textTheme,
        primary,
        cardSurface,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: _darkSnackBarTheme(textTheme),
      dialogTheme: _darkDialogTheme(textTheme),
      bottomNavigationBarTheme: _bottomNavTheme(
        surface: surface,
        primary: primary,
        unselected: AppColors.textTertiary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: AppColors.cardLight,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════

  /// The light theme used across the entire application.
  static ThemeData lightTheme([ThemeSettingsModel? settings]) {
    final primary = _parseColor(settings?.primaryColor) ?? AppColors.primary;
    final secondary =
        _parseColor(settings?.secondaryColor) ?? AppColors.secondary;
    final accent = _parseColor(settings?.accentColor) ?? AppColors.accent;
    final background = _readableSurface(
      _parseColor(settings?.backgroundColor) ??
          AppColors.lightScaffoldBackground,
      Brightness.light,
    );
    final surface = _readableSurface(
      _parseColor(settings?.surfaceColor) ?? AppColors.lightSurface,
      Brightness.light,
    );
    final radius = settings?.borderRadius ?? 20.0;
    final elevation = settings?.cardElevation ?? 0.0;
    final cardSurface = settings?.glassmorphismEnabled == false
        ? surface
        : surface.withValues(alpha: 0.92);

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: AppColors.lightTextPrimary,
      displayColor: AppColors.lightTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: _lightColorScheme(
        primary,
        secondary,
        accent,
        surface: surface,
      ),
      textTheme: textTheme,
      appBarTheme: _lightAppBarTheme(textTheme),
      cardTheme: _lightCardTheme(radius, elevation, cardSurface),
      elevatedButtonTheme: _elevatedButtonTheme(
        textTheme,
        _lightColorScheme(primary, secondary, accent, surface: surface),
        radius,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(textTheme, primary),
      textButtonTheme: _textButtonTheme(textTheme, primary),
      inputDecorationTheme: _lightInputDecorationTheme(
        textTheme,
        primary,
        cardSurface,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: _lightSnackBarTheme(textTheme),
      dialogTheme: _lightDialogTheme(textTheme),
      bottomNavigationBarTheme: _bottomNavTheme(
        surface: surface,
        primary: primary,
        unselected: AppColors.lightTextTertiary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: AppColors.lightCardLight,
      ),
    );
  }

  // ─── Dark Color Scheme ────────────────────────────────────────────
  static ColorScheme _darkColorScheme(
    Color primary,
    Color secondary,
    Color tertiary, {
    required Color surface,
  }) => ColorScheme.dark(
    primary: primary,
    onPrimary: _onColor(primary),
    secondary: secondary,
    onSecondary: _onColor(secondary),
    tertiary: tertiary,
    onTertiary: _onColor(tertiary),
    surface: surface,
    onSurface: _onColor(surface),
    surfaceContainerHighest: AppColors.cardLight,
    surfaceContainerHigh: AppColors.card,
    surfaceContainer: AppColors.elevatedSurface,
    surfaceContainerLow: surface,
    surfaceContainerLowest: AppColors.background,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.cardBorder,
    outlineVariant: AppColors.cardBorder,
    shadow: Colors.black,
  );

  // ─── Light Color Scheme ───────────────────────────────────────────
  static ColorScheme _lightColorScheme(
    Color primary,
    Color secondary,
    Color tertiary, {
    required Color surface,
  }) => ColorScheme.light(
    primary: primary,
    onPrimary: _onColor(primary),
    secondary: secondary,
    onSecondary: _onColor(secondary),
    tertiary: tertiary,
    onTertiary: _onColor(tertiary),
    surface: surface,
    onSurface: _onColor(surface),
    surfaceContainerHighest: AppColors.lightCardLight,
    surfaceContainerHigh: AppColors.lightCard,
    surfaceContainer: AppColors.lightElevatedSurface,
    surfaceContainerLow: surface,
    surfaceContainerLowest: AppColors.lightBackground,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.lightCardBorder,
    outlineVariant: AppColors.lightCardBorder,
    shadow: Colors.black.withValues(alpha: 0.2),
  );

  // ─── Dark AppBar ──────────────────────────────────────────────────
  static AppBarTheme _darkAppBarTheme(TextTheme textTheme) => AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: textTheme.titleLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  // ─── Light AppBar ─────────────────────────────────────────────────
  static AppBarTheme _lightAppBarTheme(TextTheme textTheme) => AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: textTheme.titleLarge?.copyWith(
      color: AppColors.lightTextPrimary,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  // ─── Dark Card ────────────────────────────────────────────────────
  static CardThemeData _darkCardTheme(
    double radius,
    double elevation,
    Color surface,
  ) => CardThemeData(
    color: surface,
    elevation: elevation, // We'll handle soft shadows manually in the widgets
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
    ),
    margin: EdgeInsets.zero,
  );

  // ─── Light Card ───────────────────────────────────────────────────
  static CardThemeData _lightCardTheme(
    double radius,
    double elevation,
    Color surface,
  ) => CardThemeData(
    color: surface,
    elevation: elevation, // Handled manually or via implicit shadows
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
    ),
    margin: EdgeInsets.zero,
  );

  // ─── Elevated Button (shared) ─────────────────────────────────────
  static ElevatedButtonThemeData _elevatedButtonTheme(
    TextTheme textTheme,
    ColorScheme colorScheme,
    double radius,
  ) => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
      disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  // ─── Outlined Button (shared) ─────────────────────────────────────
  static OutlinedButtonThemeData _outlinedButtonTheme(
    TextTheme textTheme,
    Color primary,
  ) => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primary,
      side: BorderSide(color: primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  // ─── Text Button (shared) ────────────────────────────────────────
  static TextButtonThemeData _textButtonTheme(
    TextTheme textTheme,
    Color primary,
  ) => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primary,
      textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  // ─── Dark Input Decoration ────────────────────────────────────────
  static InputDecorationTheme _darkInputDecorationTheme(
    TextTheme textTheme,
    Color primary,
    Color surface,
  ) => InputDecorationTheme(
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
    labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    prefixIconColor: AppColors.textTertiary,
    suffixIconColor: AppColors.textTertiary,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
  );

  // ─── Light Input Decoration ───────────────────────────────────────
  static InputDecorationTheme _lightInputDecorationTheme(
    TextTheme textTheme,
    Color primary,
    Color surface,
  ) => InputDecorationTheme(
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    hintStyle: textTheme.bodyMedium?.copyWith(
      color: AppColors.lightTextTertiary,
    ),
    labelStyle: textTheme.bodyMedium?.copyWith(
      color: AppColors.lightTextSecondary,
    ),
    prefixIconColor: AppColors.lightTextTertiary,
    suffixIconColor: AppColors.lightTextTertiary,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightCardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightCardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
  );

  // ─── Dark SnackBar ────────────────────────────────────────────────
  static SnackBarThemeData _darkSnackBarTheme(TextTheme textTheme) =>
      SnackBarThemeData(
        backgroundColor: AppColors.cardLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      );

  // ─── Light SnackBar ───────────────────────────────────────────────
  static SnackBarThemeData _lightSnackBarTheme(TextTheme textTheme) =>
      SnackBarThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      );

  // ─── Dark Dialog ──────────────────────────────────────────────────
  static DialogThemeData _darkDialogTheme(TextTheme textTheme) =>
      DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );

  // ─── Light Dialog ─────────────────────────────────────────────────
  static DialogThemeData _lightDialogTheme(TextTheme textTheme) =>
      DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightCardBorder),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.lightTextSecondary,
        ),
      );

  static BottomNavigationBarThemeData _bottomNavTheme({
    required Color surface,
    required Color primary,
    required Color unselected,
  }) => BottomNavigationBarThemeData(
    backgroundColor: surface,
    selectedItemColor: primary,
    unselectedItemColor: unselected,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  );
}
