class ThemeSettingsModel {
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final String? backgroundColor;
  final String? surfaceColor;
  final String? themeMode;
  final double? borderRadius;
  final double? cardElevation;
  final bool glassmorphismEnabled;

  const ThemeSettingsModel({
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.backgroundColor,
    this.surfaceColor,
    this.themeMode,
    this.borderRadius,
    this.cardElevation,
    this.glassmorphismEnabled = true,
  });

  factory ThemeSettingsModel.fromMap(Map<String, dynamic> map) {
    return ThemeSettingsModel(
      primaryColor: map['primaryColor'] as String?,
      secondaryColor: map['secondaryColor'] as String?,
      accentColor: map['accentColor'] as String?,
      backgroundColor: map['backgroundColor'] as String?,
      surfaceColor: map['surfaceColor'] as String?,
      themeMode: map['themeMode'] as String?,
      borderRadius: (map['borderRadius'] as num?)?.toDouble().clamp(0.0, 40.0),
      cardElevation: (map['cardElevation'] as num?)?.toDouble().clamp(
        0.0,
        20.0,
      ),
      glassmorphismEnabled: map['glassmorphismEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'surfaceColor': surfaceColor,
      'themeMode': themeMode ?? 'system',
      'borderRadius': borderRadius ?? 20.0,
      'cardElevation': cardElevation ?? 0.0,
      'glassmorphismEnabled': glassmorphismEnabled,
    };
  }

  ThemeSettingsModel copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? backgroundColor,
    String? surfaceColor,
    String? themeMode,
    double? borderRadius,
    double? cardElevation,
    bool? glassmorphismEnabled,
  }) {
    return ThemeSettingsModel(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      themeMode: themeMode ?? this.themeMode,
      borderRadius: borderRadius ?? this.borderRadius,
      cardElevation: cardElevation ?? this.cardElevation,
      glassmorphismEnabled: glassmorphismEnabled ?? this.glassmorphismEnabled,
    );
  }
}
