import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_enums.dart';

/// Low-frequency Landmark Engine status (Riverpod-safe).
final class SieLandmarkEngineStatus {
  /// Creates status.
  const SieLandmarkEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    this.lastError,
    this.lastEvent,
  });

  /// Idle default.
  factory SieLandmarkEngineStatus.idle() => const SieLandmarkEngineStatus(
        health: SieLandmarkEngineHealth.idle,
        initialized: false,
        running: false,
      );

  /// Engine health.
  final SieLandmarkEngineHealth health;

  /// Whether [initialize] completed.
  final bool initialized;

  /// Whether attached to a vision stream.
  final bool running;

  /// Last failure if any.
  final SieFailure? lastError;

  /// Last lifecycle event.
  final String? lastEvent;

  /// Copy with overrides.
  SieLandmarkEngineStatus copyWith({
    SieLandmarkEngineHealth? health,
    bool? initialized,
    bool? running,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieLandmarkEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}
