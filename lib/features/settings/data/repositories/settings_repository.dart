import '../models/language_settings_model.dart';
import '../models/motion_settings_model.dart';
import '../models/theme_settings_model.dart';

abstract class SettingsRepository {
  Stream<ThemeSettingsModel?> watchThemeSettings();
  Future<void> updateThemeSettings(
    ThemeSettingsModel settings, {
    required String adminId,
  });

  Stream<MotionSettingsModel?> watchMotionSettings();
  Future<void> updateMotionSettings(
    MotionSettingsModel settings, {
    required String adminId,
  });

  Stream<LanguageSettingsModel?> watchLanguageSettings();
  Future<void> updateLanguageSettings(
    LanguageSettingsModel settings, {
    required String adminId,
  });
}
