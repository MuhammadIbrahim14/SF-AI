import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_providers.dart';

/// Provides the current Locale based on the LanguageSettingsModel from Firestore.
/// Defaults to 'en' (English).
final currentLocaleProvider = Provider<Locale>((ref) {
  final languageSettingsAsync = ref.watch(languageSettingsStreamProvider);

  return languageSettingsAsync.when(
    data: (settings) {
      if (settings != null) {
        final language =
            settings.enabledLanguages.contains(settings.defaultLanguage)
            ? settings.defaultLanguage
            : 'en';
        return Locale(language);
      }
      return const Locale('en');
    },
    loading: () => const Locale('en'),
    error: (_, stackTrace) => const Locale('en'),
  );
});
