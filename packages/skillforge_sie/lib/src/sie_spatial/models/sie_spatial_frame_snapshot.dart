import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_hand_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Immutable frame-level spatial snapshot (canonical for downstream modules).
final class SieSpatialFrameSnapshot {
  /// Creates a frame snapshot.
  const SieSpatialFrameSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.visionTrackingState,
    required this.viewport,
    required this.hands,
    required this.processingMs,
    this.outOfBoundsCount = 0,
  });

  /// Empty frame helper.
  factory SieSpatialFrameSnapshot.empty({
    required DateTime timestamp,
    required int frameSequence,
    required SieVisionTrackingState visionTrackingState,
    required SieViewportGeometry viewport,
    double processingMs = 0,
  }) {
    return SieSpatialFrameSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      visionTrackingState: visionTrackingState,
      viewport: viewport,
      hands: const [],
      processingMs: processingMs,
    );
  }

  /// Preserved timestamp from landmarks / vision.
  final DateTime timestamp;

  /// Preserved frame sequence.
  final int frameSequence;

  /// Preserved vision tracking state.
  final SieVisionTrackingState visionTrackingState;

  /// Viewport used for this transform (immutable copy).
  final SieViewportGeometry viewport;

  /// Transformed hands (usable landmark hands only).
  final List<SieSpatialHandSnapshot> hands;

  /// Transform latency (ms).
  final double processingMs;

  /// Landmarks that were outside content before clamp.
  final int outOfBoundsCount;

  /// Primary hand for v1.
  SieSpatialHandSnapshot? get primaryHand =>
      hands.isEmpty ? null : hands.first;

  /// Whether any hand was mapped.
  bool get hasHand => hands.isNotEmpty;
}
