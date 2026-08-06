import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';

/// Low-frequency spatial engine status (Riverpod-safe).
final class SieSpatialEngineStatus {
  /// Creates status.
  const SieSpatialEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.viewport,
    this.lastError,
    this.lastEvent,
  });

  /// Idle default.
  factory SieSpatialEngineStatus.idle() => const SieSpatialEngineStatus(
        health: SieSpatialEngineHealth.idle,
        initialized: false,
        running: false,
        viewport: SieViewportGeometry.unset,
      );

  /// Engine health.
  final SieSpatialEngineHealth health;

  /// Whether initialized.
  final bool initialized;

  /// Whether consuming landmark snapshots.
  final bool running;

  /// Current viewport geometry.
  final SieViewportGeometry viewport;

  /// Last error.
  final SieFailure? lastError;

  /// Last event label.
  final String? lastEvent;

  /// Copy with overrides.
  SieSpatialEngineStatus copyWith({
    SieSpatialEngineHealth? health,
    bool? initialized,
    bool? running,
    SieViewportGeometry? viewport,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieSpatialEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      viewport: viewport ?? this.viewport,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}
