import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/core/theme/app_theme.dart';
import 'package:skillforge_ai/features/settings/data/models/theme_settings_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'forced light theme converts dark custom surfaces to readable light ones',
    () {
      const settings = ThemeSettingsModel(
        themeMode: 'light',
        backgroundColor: '#080D1A',
        surfaceColor: '#121A2E',
      );

      final theme = AppTheme.lightTheme(settings);

      expect(theme.brightness, Brightness.light);
      expect(
        theme.scaffoldBackgroundColor.computeLuminance(),
        greaterThan(0.6),
      );
      expect(theme.colorScheme.surface.computeLuminance(), greaterThan(0.6));
      expect(
        theme.colorScheme.onSurface.computeLuminance(),
        lessThan(theme.colorScheme.surface.computeLuminance()),
      );
    },
  );
}
