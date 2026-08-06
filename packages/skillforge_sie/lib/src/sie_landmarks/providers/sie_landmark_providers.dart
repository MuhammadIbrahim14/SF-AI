import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_landmarks/engine/sie_landmark_engine.dart';
import 'package:skillforge_sie/src/sie_landmarks/logging/sie_landmark_logger.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_config.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_status.dart';
import 'package:skillforge_sie/src/sie_landmarks/ports/landmark_engine_port.dart';

/// Landmark engine config (low frequency).
final sieLandmarkEngineConfigProvider =
    NotifierProvider<SieLandmarkEngineConfigNotifier, SieLandmarkEngineConfig>(
  SieLandmarkEngineConfigNotifier.new,
);

/// Holds [SieLandmarkEngineConfig].
final class SieLandmarkEngineConfigNotifier
    extends Notifier<SieLandmarkEngineConfig> {
  @override
  SieLandmarkEngineConfig build() => SieLandmarkEngineConfig.sieDefaults;

  /// Replaces config.
  // ignore: use_setters_to_change_properties
  void update(SieLandmarkEngineConfig config) => state = config;
}

/// Landmark engine instance (snapshots are not published to Riverpod).
final sieLandmarkEngineProvider = Provider<LandmarkEnginePort>((ref) {
  final engine = SieLandmarkEngine(
    config: ref.watch(sieLandmarkEngineConfigProvider),
    logger: const DeveloperSieLandmarkLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieLandmarkEngineStatusProvider =
    StreamProvider<SieLandmarkEngineStatus>((ref) {
  return ref.watch(sieLandmarkEngineProvider).status;
});

/// Availability / init / health for host UI.
final sieLandmarkEngineAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieLandmarkEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieLandmarkEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    status: status,
  );
});
