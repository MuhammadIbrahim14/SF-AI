class LanguageSettingsModel {
  final String defaultLanguage;
  final List<String> enabledLanguages;

  const LanguageSettingsModel({
    this.defaultLanguage = 'en',
    this.enabledLanguages = const ['en', 'ur'],
  });

  String get languageCode => defaultLanguage;

  factory LanguageSettingsModel.fromMap(Map<String, dynamic> map) {
    final rawDefault = (map['defaultLanguage'] ?? map['languageCode'])
        ?.toString();
    final defaultLanguage = rawDefault == 'ur' ? 'ur' : 'en';
    final enabledLanguages = _languages(map['enabledLanguages']);
    return LanguageSettingsModel(
      defaultLanguage: defaultLanguage,
      enabledLanguages: enabledLanguages.contains(defaultLanguage)
          ? enabledLanguages
          : [...enabledLanguages, defaultLanguage],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultLanguage': defaultLanguage,
      'languageCode': defaultLanguage,
      'enabledLanguages': enabledLanguages,
    };
  }

  LanguageSettingsModel copyWith({
    String? defaultLanguage,
    List<String>? enabledLanguages,
  }) {
    return LanguageSettingsModel(
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      enabledLanguages: enabledLanguages ?? this.enabledLanguages,
    );
  }
}

List<String> _languages(Object? value) {
  final languages = value is Iterable
      ? value
            .whereType<String>()
            .where((item) => item == 'en' || item == 'ur')
            .toList()
      : <String>[];
  return languages.isEmpty ? const ['en', 'ur'] : languages;
}
