import 'package:skillforge_sie/src/sie_vision/models/sie_detected_hand.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// One vision inference output for a camera frame (Landmark Engine input).
///
/// Purpose: sole landmark truth source from Vision Provider.
/// Does not contain gestures, intents, or cursor data.
final class SieVisionResult {
  /// Creates a vision result.
  const SieVisionResult({
    required this.timestamp,
    required this.frameSequence,
    required this.hands,
    required this.trackingState,
    required this.inferenceMs,
    required this.detected,
    this.droppedBeforeInfer = false,
  });

  /// Empty / no-hand result helper.
  factory SieVisionResult.none({
    required DateTime timestamp,
    required int frameSequence,
    required SieVisionTrackingState trackingState,
    required double inferenceMs,
    bool droppedBeforeInfer = false,
  }) {
    return SieVisionResult(
      timestamp: timestamp,
      frameSequence: frameSequence,
      hands: const [],
      trackingState: trackingState,
      inferenceMs: inferenceMs,
      detected: false,
      droppedBeforeInfer: droppedBeforeInfer,
    );
  }

  /// Wall time when the result was produced.
  final DateTime timestamp;

  /// Source [SieCameraFrame.sequence].
  final int frameSequence;

  /// Detected hands (v1 consumers typically use `hands.first`).
  final List<SieDetectedHand> hands;

  /// Coarse tracking state at emit time.
  final SieVisionTrackingState trackingState;

  /// Backend inference duration in milliseconds.
  final double inferenceMs;

  /// Convenience: [hands] is non-empty.
  final bool detected;

  /// True when this slot was skipped due to back-pressure (rare; usually
  /// skipped frames are not emitted).
  final bool droppedBeforeInfer;

  /// Hand count.
  int get handCount => hands.length;

  /// Primary hand for v1 (first), if any.
  SieDetectedHand? get primaryHand => hands.isEmpty ? null : hands.first;
}
