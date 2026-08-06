import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';

/// Sensitivity parameters derived from a named profile.
final class SieSensitivityParameters {
  /// Creates parameters.
  const SieSensitivityParameters({
    required this.gain,
    required this.deadZoneBoost,
    required this.edgeSoftness,
    required this.tremorDamping,
  });

  /// Cursor-plane gain multiplier (calibration only).
  final double gain;

  /// Extra dead-zone expansion.
  final double deadZoneBoost;

  /// Soft edge falloff weight [0,1].
  final double edgeSoftness;

  /// Tremor damping weight [0,1] (applied as mild centering bias).
  final double tremorDamping;

  /// Lookup for [SieSensitivityProfileId].
  static SieSensitivityParameters forProfile(SieSensitivityProfileId id) {
    return switch (id) {
      SieSensitivityProfileId.standard => const SieSensitivityParameters(
          gain: 1.0,
          deadZoneBoost: 0,
          edgeSoftness: 0.15,
          tremorDamping: 0,
        ),
      SieSensitivityProfileId.precision => const SieSensitivityParameters(
          gain: 0.75,
          deadZoneBoost: 0.01,
          edgeSoftness: 0.25,
          tremorDamping: 0.05,
        ),
      SieSensitivityProfileId.fast => const SieSensitivityParameters(
          gain: 1.35,
          deadZoneBoost: 0,
          edgeSoftness: 0.05,
          tremorDamping: 0,
        ),
      SieSensitivityProfileId.accessibility => const SieSensitivityParameters(
          gain: 0.9,
          deadZoneBoost: 0.02,
          edgeSoftness: 0.35,
          tremorDamping: 0.1,
        ),
      SieSensitivityProfileId.tremorTolerant => const SieSensitivityParameters(
          gain: 0.7,
          deadZoneBoost: 0.03,
          edgeSoftness: 0.4,
          tremorDamping: 0.35,
        ),
    };
  }
}
