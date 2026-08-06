import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_config.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_normalized_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_hand_landmark.dart';

/// Output of coordinate normalization.
final class SieNormalizationOutput {
  /// Creates normalization output.
  const SieNormalizationOutput({
    required this.landmarks,
    required this.wasClamped,
  });

  /// Normalized landmarks with stable indices.
  final List<SieNormalizedLandmark> landmarks;

  /// Whether any x/y was clamped into [0,1].
  final bool wasClamped;
}

/// Normalizes vision landmarks into a platform-independent domain.
final class SieLandmarkNormalizer {
  /// Creates a normalizer.
  const SieLandmarkNormalizer(this.config);

  /// Active config.
  final SieLandmarkEngineConfig config;

  /// Normalizes an ordered landmark list (must already be validated).
  SieNormalizationOutput normalize(List<SieHandLandmark> raw) {
    var clamped = false;
    final out = <SieNormalizedLandmark>[];
    for (var i = 0; i < raw.length; i++) {
      final lm = raw[i];
      var x = lm.x;
      var y = lm.y;
      if (config.clampToUnitSquare) {
        final cx = x.clamp(0.0, 1.0);
        final cy = y.clamp(0.0, 1.0);
        if (cx != x || cy != y) clamped = true;
        x = cx.toDouble();
        y = cy.toDouble();
      }
      out.add(
        SieNormalizedLandmark(
          index: i,
          x: x,
          y: y,
          z: lm.z,
          visibility: lm.visibility,
          presence: lm.presence,
        ),
      );
    }
    return SieNormalizationOutput(
      landmarks: List.unmodifiable(out),
      wasClamped: clamped,
    );
  }
}
