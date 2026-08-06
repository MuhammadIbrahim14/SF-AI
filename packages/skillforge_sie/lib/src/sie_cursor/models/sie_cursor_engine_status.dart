import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Low-frequency cursor engine status (Riverpod-safe).
final class SieCursorEngineStatus {
  /// Creates status.
  const SieCursorEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.state,
    required this.theme,
    required this.motionProfile,
    this.visible = false,
    this.lastError,
    this.lastEvent,
  });

  /// Idle.
  factory SieCursorEngineStatus.idle() => const SieCursorEngineStatus(
        health: SieCursorEngineHealth.idle,
        initialized: false,
        running: false,
        state: SieCursorState.hidden,
        theme: SieCursorThemeId.standard,
        motionProfile: SieCursorMotionProfileId.standard,
      );

  /// Health.
  final SieCursorEngineHealth health;

  /// Initialized.
  final bool initialized;

  /// Running.
  final bool running;

  /// Coarse cursor state.
  final SieCursorState state;

  /// Theme.
  final SieCursorThemeId theme;

  /// Motion profile.
  final SieCursorMotionProfileId motionProfile;

  /// Whether considered visible.
  final bool visible;

  /// Last error.
  final SieFailure? lastError;

  /// Last event.
  final String? lastEvent;

  /// Copy.
  SieCursorEngineStatus copyWith({
    SieCursorEngineHealth? health,
    bool? initialized,
    bool? running,
    SieCursorState? state,
    SieCursorThemeId? theme,
    SieCursorMotionProfileId? motionProfile,
    bool? visible,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieCursorEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      state: state ?? this.state,
      theme: theme ?? this.theme,
      motionProfile: motionProfile ?? this.motionProfile,
      visible: visible ?? this.visible,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics.
final class SieCursorEngineMetrics {
  /// Creates metrics.
  const SieCursorEngineMetrics({
    this.framesProcessed = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
    this.averageVelocity = 0,
    this.lastPredictionPx = 0,
    this.lastSmoothingAlpha = 0,
    this.snapEngagements = 0,
    this.clampEvents = 0,
  });

  /// Frames.
  final int framesProcessed;

  /// Avg ms.
  final double averageProcessingMs;

  /// Last ms.
  final double lastProcessingMs;

  /// Avg speed (px/ms).
  final double averageVelocity;

  /// Last prediction magnitude.
  final double lastPredictionPx;

  /// Last alpha.
  final double lastSmoothingAlpha;

  /// Snap engagements.
  final int snapEngagements;

  /// Clamp events.
  final int clampEvents;

  /// Copy.
  SieCursorEngineMetrics copyWith({
    int? framesProcessed,
    double? averageProcessingMs,
    double? lastProcessingMs,
    double? averageVelocity,
    double? lastPredictionPx,
    double? lastSmoothingAlpha,
    int? snapEngagements,
    int? clampEvents,
  }) {
    return SieCursorEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
      averageVelocity: averageVelocity ?? this.averageVelocity,
      lastPredictionPx: lastPredictionPx ?? this.lastPredictionPx,
      lastSmoothingAlpha: lastSmoothingAlpha ?? this.lastSmoothingAlpha,
      snapEngagements: snapEngagements ?? this.snapEngagements,
      clampEvents: clampEvents ?? this.clampEvents,
    );
  }
}

/// Mutable working model (engine-private); snapshots are immutable.
final class SieCursorWorkingModel {
  /// Creates model.
  SieCursorWorkingModel({
    this.position = SieSpatialPoint2D.zero,
    this.rawPosition = SieSpatialPoint2D.zero,
    this.velocity = SieSpatialPoint2D.zero,
    this.state = SieCursorState.hidden,
    this.opacity = 0,
    this.visibility = SieCursorVisibilityMode.hidden,
    this.hoverTargetId,
    this.snapTargetId,
    this.snapped = false,
    this.lastMoveAt,
    this.hoverSince,
    this.animationPhase = 0,
  });

  /// Smoothed position.
  SieSpatialPoint2D position;

  /// Raw.
  SieSpatialPoint2D rawPosition;

  /// Velocity.
  SieSpatialPoint2D velocity;

  /// State.
  SieCursorState state;

  /// Opacity.
  double opacity;

  /// Visibility.
  SieCursorVisibilityMode visibility;

  /// Hover id.
  String? hoverTargetId;

  /// Snap id.
  String? snapTargetId;

  /// Snapped.
  bool snapped;

  /// Last move timestamp.
  DateTime? lastMoveAt;

  /// Hover acquire start.
  DateTime? hoverSince;

  /// Animation phase.
  double animationPhase;
}
