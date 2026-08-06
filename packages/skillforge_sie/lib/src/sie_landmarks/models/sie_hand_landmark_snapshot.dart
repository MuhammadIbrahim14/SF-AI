import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_enums.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_normalized_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Immutable snapshot of one validated hand.
///
/// Higher layers must never mutate this object.
final class SieHandLandmarkSnapshot {
  /// Creates a hand snapshot.
  const SieHandLandmarkSnapshot({
    required this.handId,
    required this.handedness,
    required this.handednessScore,
    required this.handConfidence,
    required this.landmarks,
    required this.validationState,
    this.rejectionReason,
    this.wasStabilized = false,
    this.wasClamped = false,
  });

  /// Rejected-hand helper (empty landmarks).
  factory SieHandLandmarkSnapshot.rejected({
    required int handId,
    required SieHandedness handedness,
    required double handednessScore,
    required double handConfidence,
    required SieLandmarkRejectionReason reason,
  }) {
    return SieHandLandmarkSnapshot(
      handId: handId,
      handedness: handedness,
      handednessScore: handednessScore,
      handConfidence: handConfidence,
      landmarks: const [],
      validationState: SieLandmarkValidationState.rejected,
      rejectionReason: reason,
    );
  }

  /// Stable hand id for this frame (vision index; tracking id later).
  final int handId;

  /// Preserved handedness (not reinterpreted).
  final SieHandedness handedness;

  /// Preserved handedness confidence.
  final double handednessScore;

  /// Preserved hand detection confidence.
  final double handConfidence;

  /// Validated / normalized / optionally stabilized landmarks.
  final List<SieNormalizedLandmark> landmarks;

  /// Validation outcome.
  final SieLandmarkValidationState validationState;

  /// Present when [validationState] is rejected.
  final SieLandmarkRejectionReason? rejectionReason;

  /// Whether temporal EMA was applied.
  final bool wasStabilized;

  /// Whether any coordinate was clamped into the unit square.
  final bool wasClamped;

  /// Usable by Spatial Coordinate Engine.
  bool get isUsable =>
      validationState == SieLandmarkValidationState.valid ||
      validationState == SieLandmarkValidationState.degraded;
}
