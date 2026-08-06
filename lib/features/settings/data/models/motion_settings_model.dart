class MotionSettingsModel {
  final bool animationsEnabled;
  final double animationSpeed;
  final bool shimmerEnabled;
  final bool particlesEnabled;
  final bool reducedMotion;

  const MotionSettingsModel({
    this.animationsEnabled = true,
    this.animationSpeed = 1.0,
    this.shimmerEnabled = true,
    this.particlesEnabled = true,
    this.reducedMotion = false,
  });

  factory MotionSettingsModel.fromMap(Map<String, dynamic> map) {
    return MotionSettingsModel(
      animationsEnabled: map['animationsEnabled'] as bool? ?? true,
      animationSpeed:
          (map['animationSpeed'] as num?)?.toDouble().clamp(0.1, 3.0) ?? 1.0,
      shimmerEnabled: map['shimmerEnabled'] as bool? ?? true,
      particlesEnabled:
          (map['particlesEnabled'] ?? map['particleEffectsEnabled']) as bool? ??
          true,
      reducedMotion: map['reducedMotion'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'animationsEnabled': animationsEnabled,
      'animationSpeed': animationSpeed,
      'shimmerEnabled': shimmerEnabled,
      'particlesEnabled': particlesEnabled,
      'particleEffectsEnabled': particlesEnabled,
      'reducedMotion': reducedMotion,
    };
  }

  MotionSettingsModel copyWith({
    bool? animationsEnabled,
    double? animationSpeed,
    bool? shimmerEnabled,
    bool? particlesEnabled,
    bool? reducedMotion,
  }) {
    return MotionSettingsModel(
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      shimmerEnabled: shimmerEnabled ?? this.shimmerEnabled,
      particlesEnabled: particlesEnabled ?? this.particlesEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }
}
