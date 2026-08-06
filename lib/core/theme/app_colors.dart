import 'package:flutter/material.dart';

/// SkillForge AI — Centralized Color System
/// Dark futuristic theme palette designed for a premium feel.
/// Now includes a light theme palette for theme switching.
abstract final class AppColors {
  // ─── Primary Palette ────────────────────────────────────────────────
  static const Color primary = Color(0xFF5B7CFF);
  static const Color primaryLight = Color(0xFF8DA3FF);
  static const Color primaryDark = Color(0xFF3A5AE0);

  // ─── Secondary Palette ──────────────────────────────────────────────
  static const Color secondary = Color(0xFF8A5CFF);
  static const Color secondaryLight = Color(0xFFAD8AFF);
  static const Color secondaryDark = Color(0xFF6B3FDB);

  // ─── Accent ─────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF00D1FF);
  static const Color accentLight = Color(0xFF66E3FF);
  static const Color accentDark = Color(0xFF009EC2);

  // ═══════════════════════════════════════════════════════════════════
  // DARK THEME COLORS
  // ═══════════════════════════════════════════════════════════════════

  // ─── Background & Surface (Dark) ───────────────────────────────────
  static const Color background = Color(0xFF0A0F1F);
  static const Color surface = Color(0xFF121A2E);
  static const Color elevatedSurface = Color(0xFF18233D);
  static const Color card = Color(0xFF121A2E);
  static const Color cardLight = Color(0xFF1A2540);
  static const Color cardBorder = Color(0xFF1E2A45);
  static const Color scaffoldBackground = Color(0xFF0A0F1F);

  // ─── Text Colors (Dark) ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8CD);
  static const Color textTertiary = Color(0xFF6B7494);
  static const Color textDisabled = Color(0xFF3D4560);

  // ═══════════════════════════════════════════════════════════════════
  // LIGHT THEME COLORS
  // ═══════════════════════════════════════════════════════════════════

  // ─── Background & Surface (Light) ──────────────────────────────────
  static const Color lightBackground = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardLight = Color(0xFFF9FAFB);
  static const Color lightCardBorder = Color(0xFFE5E7EB);
  static const Color lightScaffoldBackground = Color(0xFFF3F4F6);

  // ─── Text Colors (Light) ───────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF334155);
  static const Color lightTextTertiary = Color(0xFF475569);
  static const Color lightTextDisabled = Color(0xFF94A3B8);

  // ═══════════════════════════════════════════════════════════════════
  // SEMANTIC & SHARED COLORS
  // ═══════════════════════════════════════════════════════════════════

  // ─── Semantic Colors ───────────────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB00);
  static const Color warningDark = Color(0xFFFF8F00);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color info = Color(0xFF448AFF);

  // ─── Gradient Presets ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [cardLight, card],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light theme gradients
  static const LinearGradient lightSurfaceGradient = LinearGradient(
    colors: [lightSurface, lightBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    colors: [lightCard, lightCardLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Overlay & Misc ────────────────────────────────────────────────
  static const Color overlay = Color(0x80000000);
  static const Color lightOverlay = Color(0x40000000);
  static const Color divider = Color(0xFF1E2A45);
  static const Color lightDivider = Color(0xFFE2E6F0);
  static const Color shimmerBase = Color(0xFF1A2540);
  static const Color shimmerHighlight = Color(0xFF2A3555);
  static const Color lightShimmerBase = Color(0xFFE8EBF2);
  static const Color lightShimmerHighlight = Color(0xFFF5F7FC);

  // ─── Role-Specific Colors ─────────────────────────────────────────
  static const Color studentPrimary = Color(0xFF5B7CFF);
  static const Color studentSecondary = Color(0xFF3A5AE0);
  static const Color teacherPrimary = Color(0xFF8A5CFF);
  static const Color teacherSecondary = Color(0xFF6B3FDB);
  static const Color freelancerPrimary = Color(0xFF00D1FF);
  static const Color freelancerSecondary = Color(0xFF0099CC);
  static const Color companyPrimary = Color(0xFF00E676);
  static const Color companySecondary = Color(0xFF00C853);
  static const Color adminPrimary = Color(0xFFEF4444);
  static const Color adminSecondary = Color(0xFFDC2626);
  static const Color superAdminPrimary = Color(0xFF8B5CF6);
  static const Color superAdminSecondary = Color(0xFF7C3AED);
}
