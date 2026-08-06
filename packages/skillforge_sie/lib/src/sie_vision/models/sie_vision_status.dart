import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Low-frequency vision backend status (Riverpod-safe).
final class SieVisionStatus {
  /// Creates a status snapshot.
  const SieVisionStatus({
    required this.trackingState,
    required this.backend,
    required this.initialized,
    required this.running,
    this.providerId = 'sie.vision',
    this.lastError,
    this.lastEvent,
  });

  /// Idle default.
  factory SieVisionStatus.idle({
    SieVisionBackendKind backend = SieVisionBackendKind.unsupported,
  }) {
    return SieVisionStatus(
      trackingState: SieVisionTrackingState.idle,
      backend: backend,
      initialized: false,
      running: false,
    );
  }

  /// Coarse tracking / lifecycle state.
  final SieVisionTrackingState trackingState;

  /// Active backend kind.
  final SieVisionBackendKind backend;

  /// Model / runtime loaded.
  final bool initialized;

  /// Attached to a frame source and processing.
  final bool running;

  /// Stable provider id for diagnostics.
  final String providerId;

  /// Last failure if any.
  final SieFailure? lastError;

  /// Last lifecycle event label.
  final String? lastEvent;

  /// Copy with overrides.
  SieVisionStatus copyWith({
    SieVisionTrackingState? trackingState,
    SieVisionBackendKind? backend,
    bool? initialized,
    bool? running,
    String? providerId,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieVisionStatus(
      trackingState: trackingState ?? this.trackingState,
      backend: backend ?? this.backend,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      providerId: providerId ?? this.providerId,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}
