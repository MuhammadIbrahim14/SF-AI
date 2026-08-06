import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_spatial/engine/sie_spatial_coordinate_engine.dart';
import 'package:skillforge_sie/src/sie_spatial/logging/sie_spatial_logger.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_config.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_status.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';
import 'package:skillforge_sie/src/sie_spatial/ports/spatial_coordinate_engine_port.dart';

/// Spatial engine config (low frequency).
final sieSpatialEngineConfigProvider =
    NotifierProvider<SieSpatialEngineConfigNotifier, SieSpatialEngineConfig>(
  SieSpatialEngineConfigNotifier.new,
);

/// Holds [SieSpatialEngineConfig].
final class SieSpatialEngineConfigNotifier
    extends Notifier<SieSpatialEngineConfig> {
  @override
  SieSpatialEngineConfig build() => SieSpatialEngineConfig.sieDefaults;

  /// Replaces config.
  // ignore: use_setters_to_change_properties
  void update(SieSpatialEngineConfig config) => state = config;
}

/// Current viewport geometry (host updates on resize / rotation).
///
/// Does **not** stream per-frame coordinates (ADR-008).
final sieSpatialViewportProvider =
    NotifierProvider<SieSpatialViewportNotifier, SieViewportGeometry>(
  SieSpatialViewportNotifier.new,
);

/// Holds [SieViewportGeometry] and pushes updates into the engine.
final class SieSpatialViewportNotifier extends Notifier<SieViewportGeometry> {
  @override
  SieViewportGeometry build() => SieViewportGeometry.unset;

  /// Replaces viewport and notifies the engine when available.
  void update(SieViewportGeometry viewport) {
    state = viewport;
    ref.read(sieSpatialCoordinateEngineProvider).updateViewport(viewport);
  }
}

/// Spatial coordinate engine (snapshots are not published to Riverpod).
final sieSpatialCoordinateEngineProvider =
    Provider<SpatialCoordinateEnginePort>((ref) {
  final engine = SieSpatialCoordinateEngine(
    config: ref.watch(sieSpatialEngineConfigProvider),
    logger: const DeveloperSieSpatialLogger(),
  );
  final initial = ref.read(sieSpatialViewportProvider);
  if (initial != SieViewportGeometry.unset) {
    engine.updateViewport(initial);
  }
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieSpatialEngineStatusProvider =
    StreamProvider<SieSpatialEngineStatus>((ref) {
  return ref.watch(sieSpatialCoordinateEngineProvider).status;
});

/// Availability / viewport / orientation / health for host UI.
final sieSpatialEngineAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieViewportGeometry viewport,
  SieCameraOrientation orientation,
  SieSpatialEngineHealth health,
  SieSpatialEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieSpatialEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  final SieViewportGeometry viewport =
      status?.viewport ?? ref.watch(sieSpatialViewportProvider);
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    viewport: viewport,
    orientation: viewport.orientation,
    health: status?.health ?? SieSpatialEngineHealth.idle,
    status: status,
  );
});
