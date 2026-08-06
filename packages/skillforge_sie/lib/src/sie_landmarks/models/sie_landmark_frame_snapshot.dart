import 'package:skillforge_sie/src/sie_landmarks/models/sie_hand_landmark_snapshot.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_enums.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Immutable frame-level landmark snapshot (trusted downstream input).
///
/// Timestamps are preserved from the Vision Provider — never invented.
final class SieLandmarkFrameSnapshot {
  /// Creates a frame snapshot.
  const SieLandmarkFrameSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.visionTrackingState,
    required this.hands,
    required this.validationState,
    required this.processingMs,
    this.visionInferenceMs,
  });

  /// Empty frame (no hands) — valid empty, not a rejection.
  factory SieLandmarkFrameSnapshot.empty({
    required DateTime timestamp,
    required int frameSequence,
    required SieVisionTrackingState visionTrackingState,
    double processingMs = 0,
    double? visionInferenceMs,
  }) {
    return SieLandmarkFrameSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      visionTrackingState: visionTrackingState,
      hands: const [],
      validationState: SieLandmarkValidationState.empty,
      processingMs: processingMs,
      visionInferenceMs: visionInferenceMs,
    );
  }

  /// Vision / capture timestamp (preserved).
  final DateTime timestamp;

  /// Camera / vision frame sequence (preserved).
  final int frameSequence;

  /// Vision tracking state at source (preserved, not remapped to gestures).
  final SieVisionTrackingState visionTrackingState;

  /// Per-hand snapshots (rejected hands may be omitted or included as rejected).
  final List<SieHandLandmarkSnapshot> hands;

  /// Aggregate validation state for the frame.
  final SieLandmarkValidationState validationState;

  /// Landmark Engine processing time (ms).
  final double processingMs;

  /// Preserved vision inference time when available.
  final double? visionInferenceMs;

  /// Usable hands only.
  List<SieHandLandmarkSnapshot> get usableHands =>
      hands.where((h) => h.isUsable).toList(growable: false);

  /// Primary usable hand for v1.
  SieHandLandmarkSnapshot? get primaryHand {
    for (final h in hands) {
      if (h.isUsable) return h;
    }
    return null;
  }

  /// Whether any usable hand exists.
  bool get hasUsableHand => primaryHand != null;
}
