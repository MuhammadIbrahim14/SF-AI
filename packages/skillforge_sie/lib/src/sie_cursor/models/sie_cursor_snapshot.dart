import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Immutable cursor snapshot — authoritative for Pointer Bridge / overlay.
final class SieCursorSnapshot {
  /// Creates snapshot.
  const SieCursorSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.position,
    required this.rawPosition,
    required this.velocity,
    required this.direction,
    required this.acceleration,
    required this.state,
    required this.visibility,
    required this.opacity,
    required this.theme,
    required this.interactionMode,
    required this.trackingState,
    this.hoverTargetId,
    this.snapTargetId,
    this.snapped = false,
    this.predictionOffset = SieSpatialPoint2D.zero,
    this.smoothingAlpha = 0,
    this.animationPhase = 0,
    this.processingMs = 0,
    this.metadata = const {},
  });

  /// Hidden idle snapshot.
  factory SieCursorSnapshot.hidden({
    required DateTime timestamp,
    required int frameSequence,
    SieCursorThemeId theme = SieCursorThemeId.standard,
  }) {
    return SieCursorSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      position: SieSpatialPoint2D.zero,
      rawPosition: SieSpatialPoint2D.zero,
      velocity: SieSpatialPoint2D.zero,
      direction: SieSpatialPoint2D.zero,
      acceleration: 0,
      state: SieCursorState.hidden,
      visibility: SieCursorVisibilityMode.hidden,
      opacity: 0,
      theme: theme,
      interactionMode: SieInteractionMode.idle,
      trackingState: SieTrackingReliabilityState.idle,
    );
  }

  /// Timestamp (from intent / wall).
  final DateTime timestamp;

  /// Frame sequence (from intent).
  final int frameSequence;

  /// Smoothed + predicted + snapped logical position.
  final SieSpatialPoint2D position;

  /// Last raw intent position (pre-filter).
  final SieSpatialPoint2D rawPosition;

  /// Velocity (logical px / ms).
  final SieSpatialPoint2D velocity;

  /// Unit direction (or zero).
  final SieSpatialPoint2D direction;

  /// Scalar acceleration magnitude.
  final double acceleration;

  /// Cursor state.
  final SieCursorState state;

  /// Visibility mode.
  final SieCursorVisibilityMode visibility;

  /// Opacity [0,1].
  final double opacity;

  /// Theme.
  final SieCursorThemeId theme;

  /// Coarse interaction mode from intents.
  final SieInteractionMode interactionMode;

  /// Tracking reliability.
  final SieTrackingReliabilityState trackingState;

  /// Hover target reference (host).
  final String? hoverTargetId;

  /// Active snap target id.
  final String? snapTargetId;

  /// Whether snap influence applied this frame.
  final bool snapped;

  /// Prediction offset applied.
  final SieSpatialPoint2D predictionOffset;

  /// Effective smoothing alpha.
  final double smoothingAlpha;

  /// Animation phase [0,1] (frame-rate independent).
  final double animationPhase;

  /// Processing ms.
  final double processingMs;

  /// Diagnostics.
  final Map<String, Object?> metadata;

  /// Whether cursor should be drawn.
  bool get isVisible =>
      visibility != SieCursorVisibilityMode.hidden && opacity > 0.01;
}
