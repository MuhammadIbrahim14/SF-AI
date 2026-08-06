import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/language_settings_model.dart';
import '../data/models/motion_settings_model.dart';
import '../data/models/theme_settings_model.dart';
import '../data/repositories/settings_repository_impl.dart';

final themeSettingsStreamProvider = StreamProvider<ThemeSettingsModel?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchThemeSettings();
});

final motionSettingsStreamProvider = StreamProvider<MotionSettingsModel?>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchMotionSettings();
});

final languageSettingsStreamProvider = StreamProvider<LanguageSettingsModel?>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchLanguageSettings();
});
