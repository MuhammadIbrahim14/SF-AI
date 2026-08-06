import 'package:skillforge_sie/src/sie_vision/models/sie_hand_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// One detected hand from the Vision Provider (no gesture interpretation).
final class SieDetectedHand {
  /// Creates a detected hand.
  const SieDetectedHand({
    required this.landmarks,
    required this.handedness,
    required this.handednessScore,
    required this.handConfidence,
    this.index = 0,
  });

  /// MediaPipe 21-point landmark list (may be shorter if backend degraded).
  final List<SieHandLandmark> landmarks;

  /// Left / right / unknown.
  final SieHandedness handedness;

  /// Score for [handedness] classification (0–1).
  final double handednessScore;

  /// Overall hand detection / presence confidence (0–1).
  final double handConfidence;

  /// Index among hands in the same result (0 = primary for v1).
  final int index;

  /// Whether landmark count looks like a full MediaPipe hand.
  bool get hasFullLandmarkSet => landmarks.length >= 21;
}
