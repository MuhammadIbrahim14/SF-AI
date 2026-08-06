import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';

/// Low-frequency pointer bridge status (Riverpod-safe).
final class SiePointerBridgeStatus {
  /// Creates status.
  const SiePointerBridgeStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.lifecycle,
    this.pointerId = 0,
    this.hovering = false,
    this.pressed = false,
    this.lastError,
    this.lastEvent,
  });

  /// Idle.
  factory SiePointerBridgeStatus.idle() => const SiePointerBridgeStatus(
        health: SiePointerBridgeHealth.idle,
        initialized: false,
        running: false,
        lifecycle: SiePointerLifecycleState.absent,
      );

  /// Health.
  final SiePointerBridgeHealth health;

  /// Initialized.
  final bool initialized;

  /// Running.
  final bool running;

  /// Lifecycle.
  final SiePointerLifecycleState lifecycle;

  /// Active pointer id.
  final int pointerId;

  /// Hovering.
  final bool hovering;

  /// Pressed.
  final bool pressed;

  /// Last error.
  final SieFailure? lastError;

  /// Last event label.
  final String? lastEvent;

  /// Copy.
  SiePointerBridgeStatus copyWith({
    SiePointerBridgeHealth? health,
    bool? initialized,
    bool? running,
    SiePointerLifecycleState? lifecycle,
    int? pointerId,
    bool? hovering,
    bool? pressed,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SiePointerBridgeStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      lifecycle: lifecycle ?? this.lifecycle,
      pointerId: pointerId ?? this.pointerId,
      hovering: hovering ?? this.hovering,
      pressed: pressed ?? this.pressed,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics.
final class SiePointerBridgeMetrics {
  /// Creates metrics.
  const SiePointerBridgeMetrics({
    this.framesProcessed = 0,
    this.eventsEmitted = 0,
    this.pointerDowns = 0,
    this.pointerUps = 0,
    this.scrolls = 0,
    this.dragsStarted = 0,
    this.pointerRecreations = 0,
    this.lostTrackingCleanups = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
  });

  /// Frames.
  final int framesProcessed;

  /// Events.
  final int eventsEmitted;

  /// Downs.
  final int pointerDowns;

  /// Ups.
  final int pointerUps;

  /// Scrolls.
  final int scrolls;

  /// Drag starts.
  final int dragsStarted;

  /// Pointer remove+add cycles.
  final int pointerRecreations;

  /// LostTracking cleanups.
  final int lostTrackingCleanups;

  /// Avg ms.
  final double averageProcessingMs;

  /// Last ms.
  final double lastProcessingMs;

  /// Copy.
  SiePointerBridgeMetrics copyWith({
    int? framesProcessed,
    int? eventsEmitted,
    int? pointerDowns,
    int? pointerUps,
    int? scrolls,
    int? dragsStarted,
    int? pointerRecreations,
    int? lostTrackingCleanups,
    double? averageProcessingMs,
    double? lastProcessingMs,
  }) {
    return SiePointerBridgeMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      eventsEmitted: eventsEmitted ?? this.eventsEmitted,
      pointerDowns: pointerDowns ?? this.pointerDowns,
      pointerUps: pointerUps ?? this.pointerUps,
      scrolls: scrolls ?? this.scrolls,
      dragsStarted: dragsStarted ?? this.dragsStarted,
      pointerRecreations: pointerRecreations ?? this.pointerRecreations,
      lostTrackingCleanups:
          lostTrackingCleanups ?? this.lostTrackingCleanups,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
    );
  }
}

/// Bridge configuration.
final class SiePointerBridgeConfig {
  /// Creates config.
  const SiePointerBridgeConfig({
    this.basePointerId = 900001,
    this.injectEnabled = true,
    this.cancelOnLostTracking = true,
    this.removeOnLostTracking = true,
    this.emitHoverWhileMoving = true,
    this.minMoveEpsilon = 0.01,
    this.scrollPixelsGain = 1,
    this.tapSlopPixels = 48,
  });

  /// Default config.
  static const SiePointerBridgeConfig standard = SiePointerBridgeConfig();

  /// Stable SIE pointer id base (avoids collision with OS pointers).
  final int basePointerId;

  /// Whether to call [PointerInjectionPort].
  final bool injectEnabled;

  /// Cancel press on LostTracking (IDS: loss ≠ confirm).
  final bool cancelOnLostTracking;

  /// Remove pointer device on LostTracking.
  final bool removeOnLostTracking;

  /// Emit hover for moveCursor when not pressed.
  final bool emitHoverWhileMoving;

  /// Ignore sub-pixel moves.
  final double minMoveEpsilon;

  /// Multiplier on scroll axisDelta. Classifier already emits logical pixels.
  final double scrollPixelsGain;

  /// Ignore pressed moves below this (logical px) so pinch stays a tap.
  final double tapSlopPixels;
}
