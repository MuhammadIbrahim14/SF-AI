import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Immutable spatial snapshot for one hand.
final class SieSpatialHandSnapshot {
  /// Creates a hand spatial snapshot.
  const SieSpatialHandSnapshot({
    required this.handId,
    required this.handedness,
    required this.handednessScore,
    required this.handConfidence,
    required this.landmarks,
  });

  /// Hand id from Landmark Engine.
  final int handId;

  /// Preserved handedness.
  final SieHandedness handedness;

  /// Preserved handedness confidence.
  final double handednessScore;

  /// Preserved hand confidence.
  final double handConfidence;

  /// Transformed landmarks.
  final List<SieSpatialLandmark> landmarks;

  /// Index fingertip (8) when present.
  SieSpatialLandmark? get indexFingertip {
    for (final lm in landmarks) {
      if (lm.index == 8) return lm;
    }
    return landmarks.isEmpty ? null : landmarks.first;
  }
}
