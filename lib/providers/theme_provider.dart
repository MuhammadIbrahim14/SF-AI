import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SkillForge AI — Theme Provider
/// Manages light/dark mode state across the entire application.

/// Provides the current [ThemeMode] and allows toggling.
final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  /// Toggles between light and dark mode.
  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Sets a specific theme mode.
  void setTheme(ThemeMode mode) {
    state = mode;
  }

  /// Whether the current theme is dark.
  bool get isDark => state == ThemeMode.dark;
}
