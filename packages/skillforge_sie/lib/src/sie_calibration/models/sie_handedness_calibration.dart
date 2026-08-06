import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';

/// Handedness preference + optional manual override.
final class SieHandednessCalibration {
  /// Creates handedness calibration.
  const SieHandednessCalibration({
    this.preference = SieCalibratedHandedness.auto,
    this.manualOverride,
    this.mirrorInteractionForLeft = false,
  });

  /// Identity / auto.
  static const SieHandednessCalibration identity = SieHandednessCalibration();

  /// Preferred mode.
  final SieCalibratedHandedness preference;

  /// Manual override when set (wins over auto / preference).
  final SieCalibratedHandedness? manualOverride;

  /// When resolved hand is left, optionally mirror X for interaction.
  ///
  /// Gesture language stays identical; only coordinate space flips.
  final bool mirrorInteractionForLeft;

  /// Effective preference after override.
  SieCalibratedHandedness get effectivePreference =>
      manualOverride ?? preference;

  /// Whether values are usable.
  bool get isValid => true;

  /// Copy with overrides.
  SieHandednessCalibration copyWith({
    SieCalibratedHandedness? preference,
    SieCalibratedHandedness? manualOverride,
    bool clearManualOverride = false,
    bool? mirrorInteractionForLeft,
  }) {
    return SieHandednessCalibration(
      preference: preference ?? this.preference,
      manualOverride: clearManualOverride
          ? null
          : (manualOverride ?? this.manualOverride),
      mirrorInteractionForLeft:
          mirrorInteractionForLeft ?? this.mirrorInteractionForLeft,
    );
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'preference': preference.name,
        'manualOverride': manualOverride?.name,
        'mirrorInteractionForLeft': mirrorInteractionForLeft,
      };

  /// Parse JSON.
  static SieHandednessCalibration fromJson(Map<String, Object?> json) {
    return SieHandednessCalibration(
      preference: _hand(json['preference'] as String?) ??
          SieCalibratedHandedness.auto,
      manualOverride: _hand(json['manualOverride'] as String?),
      mirrorInteractionForLeft:
          json['mirrorInteractionForLeft'] as bool? ?? false,
    );
  }

  static SieCalibratedHandedness? _hand(String? name) {
    return switch (name) {
      'right' => SieCalibratedHandedness.right,
      'left' => SieCalibratedHandedness.left,
      'auto' => SieCalibratedHandedness.auto,
      _ => null,
    };
  }
}
