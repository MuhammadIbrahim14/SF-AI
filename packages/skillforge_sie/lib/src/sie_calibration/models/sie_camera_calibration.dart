/// Camera placement calibration (immutable).
final class SieCameraCalibration {
  /// Creates camera calibration.
  const SieCameraCalibration({
    this.heightNormalized = 0.5,
    this.anglePitchDegrees = 0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.distanceEstimate = 1.0,
    this.assumedFovDegrees = 70,
  });

  /// Identity defaults.
  static const SieCameraCalibration identity = SieCameraCalibration();

  /// Relative camera height in [0,1] (0.5 = typical laptop).
  final double heightNormalized;

  /// Pitch compensation in degrees (positive = camera tilted down).
  final double anglePitchDegrees;

  /// Horizontal optical center offset in normalized space.
  final double offsetX;

  /// Vertical optical center offset in normalized space.
  final double offsetY;

  /// Relative distance estimate (1 = nominal).
  final double distanceEstimate;

  /// Assumed horizontal FOV (degrees) for soft perspective bias.
  final double assumedFovDegrees;

  /// Whether values are finite / usable.
  bool get isValid =>
      heightNormalized.isFinite &&
      anglePitchDegrees.isFinite &&
      offsetX.isFinite &&
      offsetY.isFinite &&
      distanceEstimate.isFinite &&
      distanceEstimate > 0 &&
      assumedFovDegrees.isFinite &&
      assumedFovDegrees > 0;

  /// Copy with overrides.
  SieCameraCalibration copyWith({
    double? heightNormalized,
    double? anglePitchDegrees,
    double? offsetX,
    double? offsetY,
    double? distanceEstimate,
    double? assumedFovDegrees,
  }) {
    return SieCameraCalibration(
      heightNormalized: heightNormalized ?? this.heightNormalized,
      anglePitchDegrees: anglePitchDegrees ?? this.anglePitchDegrees,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      distanceEstimate: distanceEstimate ?? this.distanceEstimate,
      assumedFovDegrees: assumedFovDegrees ?? this.assumedFovDegrees,
    );
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'heightNormalized': heightNormalized,
        'anglePitchDegrees': anglePitchDegrees,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'distanceEstimate': distanceEstimate,
        'assumedFovDegrees': assumedFovDegrees,
      };

  /// Parse JSON.
  static SieCameraCalibration fromJson(Map<String, Object?> json) {
    return SieCameraCalibration(
      heightNormalized: (json['heightNormalized'] as num?)?.toDouble() ?? 0.5,
      anglePitchDegrees: (json['anglePitchDegrees'] as num?)?.toDouble() ?? 0,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      distanceEstimate: (json['distanceEstimate'] as num?)?.toDouble() ?? 1,
      assumedFovDegrees: (json['assumedFovDegrees'] as num?)?.toDouble() ?? 70,
    );
  }
}
