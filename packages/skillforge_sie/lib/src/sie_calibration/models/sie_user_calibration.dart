import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// User-facing body / reach calibration (immutable).
final class SieUserCalibration {
  /// Creates user calibration.
  const SieUserCalibration({
    this.armLengthScale = 1.0,
    this.comfortableReachScale = 1.0,
    this.posture = SieUserPosture.sitting,
    this.preferredZoneCenterX = 0.5,
    this.preferredZoneCenterY = 0.45,
    this.preferredZoneWidth = 0.7,
    this.preferredZoneHeight = 0.55,
  });

  /// Identity defaults.
  static const SieUserCalibration identity = SieUserCalibration();

  /// Relative arm-length scale (1 = average).
  final double armLengthScale;

  /// Comfortable reach multiplier.
  final double comfortableReachScale;

  /// Sitting / standing hint.
  final SieUserPosture posture;

  /// Preferred interaction zone center X in [0,1].
  final double preferredZoneCenterX;

  /// Preferred interaction zone center Y in [0,1].
  final double preferredZoneCenterY;

  /// Preferred zone width in [0,1].
  final double preferredZoneWidth;

  /// Preferred zone height in [0,1].
  final double preferredZoneHeight;

  /// Preferred zone as normalized rect.
  SieSpatialRect get preferredZone {
    final left = (preferredZoneCenterX - preferredZoneWidth / 2).clamp(0.0, 1.0);
    final top = (preferredZoneCenterY - preferredZoneHeight / 2).clamp(0.0, 1.0);
    final right =
        (preferredZoneCenterX + preferredZoneWidth / 2).clamp(0.0, 1.0);
    final bottom =
        (preferredZoneCenterY + preferredZoneHeight / 2).clamp(0.0, 1.0);
    return SieSpatialRect(
      left: left.toDouble(),
      top: top.toDouble(),
      width: (right - left).toDouble(),
      height: (bottom - top).toDouble(),
    );
  }

  /// Whether values are finite and in a usable range.
  bool get isValid =>
      armLengthScale.isFinite &&
      armLengthScale > 0 &&
      comfortableReachScale.isFinite &&
      comfortableReachScale > 0 &&
      preferredZoneWidth > 0 &&
      preferredZoneHeight > 0 &&
      preferredZoneCenterX.isFinite &&
      preferredZoneCenterY.isFinite;

  /// Copy with overrides.
  SieUserCalibration copyWith({
    double? armLengthScale,
    double? comfortableReachScale,
    SieUserPosture? posture,
    double? preferredZoneCenterX,
    double? preferredZoneCenterY,
    double? preferredZoneWidth,
    double? preferredZoneHeight,
  }) {
    return SieUserCalibration(
      armLengthScale: armLengthScale ?? this.armLengthScale,
      comfortableReachScale:
          comfortableReachScale ?? this.comfortableReachScale,
      posture: posture ?? this.posture,
      preferredZoneCenterX: preferredZoneCenterX ?? this.preferredZoneCenterX,
      preferredZoneCenterY: preferredZoneCenterY ?? this.preferredZoneCenterY,
      preferredZoneWidth: preferredZoneWidth ?? this.preferredZoneWidth,
      preferredZoneHeight: preferredZoneHeight ?? this.preferredZoneHeight,
    );
  }

  /// JSON map (schema fragment).
  Map<String, Object?> toJson() => {
        'armLengthScale': armLengthScale,
        'comfortableReachScale': comfortableReachScale,
        'posture': posture.name,
        'preferredZoneCenterX': preferredZoneCenterX,
        'preferredZoneCenterY': preferredZoneCenterY,
        'preferredZoneWidth': preferredZoneWidth,
        'preferredZoneHeight': preferredZoneHeight,
      };

  /// Parse JSON map.
  static SieUserCalibration fromJson(Map<String, Object?> json) {
    return SieUserCalibration(
      armLengthScale: (json['armLengthScale'] as num?)?.toDouble() ?? 1,
      comfortableReachScale:
          (json['comfortableReachScale'] as num?)?.toDouble() ?? 1,
      posture: _posture(json['posture'] as String?),
      preferredZoneCenterX:
          (json['preferredZoneCenterX'] as num?)?.toDouble() ?? 0.5,
      preferredZoneCenterY:
          (json['preferredZoneCenterY'] as num?)?.toDouble() ?? 0.45,
      preferredZoneWidth:
          (json['preferredZoneWidth'] as num?)?.toDouble() ?? 0.7,
      preferredZoneHeight:
          (json['preferredZoneHeight'] as num?)?.toDouble() ?? 0.55,
    );
  }

  static SieUserPosture _posture(String? name) {
    return switch (name) {
      'standing' => SieUserPosture.standing,
      _ => SieUserPosture.sitting,
    };
  }
}
