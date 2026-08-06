import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_sources.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Immutable confidence snapshot — canonical reliability authority.
final class SieConfidenceFrameSnapshot {
  /// Creates a confidence snapshot.
  const SieConfidenceFrameSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.visionTrackingState,
    required this.trackingState,
    required this.overallConfidence,
    required this.sources,
    required this.temporalStabilityScore,
    required this.frameValidation,
    required this.policyId,
    required this.recovery,
    required this.gestureReady,
    required this.mayConsume,
    required this.processingMs,
    this.hands = const [],
    this.profile,
    this.viewWidth = 0,
    this.viewHeight = 0,
    this.smoothedConfidence = 0,
  });

  /// Rejected / empty helper.
  factory SieConfidenceFrameSnapshot.rejected({
    required DateTime timestamp,
    required int frameSequence,
    required SieVisionTrackingState visionTrackingState,
    required SieTrackingReliabilityState trackingState,
    required SieConfidencePolicyId policyId,
    required SieConfidenceSources sources,
    required double overallConfidence,
    required double temporalStabilityScore,
    required SieRecoveryStatus recovery,
    required SieConfidenceFrameValidation frameValidation,
    double processingMs = 0,
    SieCalibrationProfile? profile,
    double viewWidth = 0,
    double viewHeight = 0,
    double smoothedConfidence = 0,
  }) {
    return SieConfidenceFrameSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      visionTrackingState: visionTrackingState,
      trackingState: trackingState,
      overallConfidence: overallConfidence,
      sources: sources,
      temporalStabilityScore: temporalStabilityScore,
      frameValidation: frameValidation,
      policyId: policyId,
      recovery: recovery,
      gestureReady: false,
      mayConsume: false,
      processingMs: processingMs,
      profile: profile,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      smoothedConfidence: smoothedConfidence,
    );
  }

  /// Preserved timestamp.
  final DateTime timestamp;

  /// Preserved frame sequence.
  final int frameSequence;

  /// Preserved vision tracking state.
  final SieVisionTrackingState visionTrackingState;

  /// Authoritative tracking reliability state.
  final SieTrackingReliabilityState trackingState;

  /// Overall confidence [0,1] (weakest-link after smoothing).
  final double overallConfidence;

  /// Per-source confidence values.
  final SieConfidenceSources sources;

  /// Temporal stability score [0,1].
  final double temporalStabilityScore;

  /// Frame validation outcome.
  final SieConfidenceFrameValidation frameValidation;

  /// Active policy.
  final SieConfidencePolicyId policyId;

  /// Recovery grace status.
  final SieRecoveryStatus recovery;

  /// Whether confidence clears gesture-ready hysteresis (not a gesture).
  final bool gestureReady;

  /// Whether downstream modules may consume coordinates this frame.
  final bool mayConsume;

  /// Engine processing time (ms).
  final double processingMs;

  /// Forwarded calibrated hands when consumable / for diagnostics.
  final List<SieCalibratedHandSnapshot> hands;

  /// Active calibration profile when present.
  final SieCalibrationProfile? profile;

  /// View width.
  final double viewWidth;

  /// View height.
  final double viewHeight;

  /// EMA-smoothed confidence (noise-suppressed).
  final double smoothedConfidence;

  /// Primary hand when present.
  SieCalibratedHandSnapshot? get primaryHand =>
      hands.isEmpty ? null : hands.first;

  /// Whether commits must be suppressed (LostTracking / Recovering).
  bool get commitsSuppressed =>
      recovery.commitsSuppressed ||
      trackingState == SieTrackingReliabilityState.lostTracking ||
      trackingState == SieTrackingReliabilityState.disabled ||
      trackingState == SieTrackingReliabilityState.error;

  /// Whether tracking is usable for cursor locomotion.
  bool get allowsLocomotion =>
      mayConsume &&
      (trackingState == SieTrackingReliabilityState.tracking ||
          trackingState == SieTrackingReliabilityState.stable ||
          trackingState == SieTrackingReliabilityState.degraded ||
          trackingState == SieTrackingReliabilityState.recovering);
}
