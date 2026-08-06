import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_calibration/engine/sie_calibration_engine.dart';
import 'package:skillforge_sie/src/sie_calibration/logging/sie_calibration_logger.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_engine_status.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_calibration/persistence/calibration_store_port.dart';
import 'package:skillforge_sie/src/sie_calibration/ports/calibration_engine_port.dart';

/// Host-overridable calibration store (defaults to in-memory).
final sieCalibrationStoreProvider = Provider<CalibrationStorePort>((ref) {
  return InMemoryCalibrationStore();
});

/// Calibration engine instance (snapshots are not published to Riverpod).
final sieCalibrationEngineProvider = Provider<CalibrationEnginePort>((ref) {
  final engine = SieCalibrationEngine(
    store: ref.watch(sieCalibrationStoreProvider),
    logger: const DeveloperSieCalibrationLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieCalibrationEngineStatusProvider =
    StreamProvider<SieCalibrationEngineStatus>((ref) {
  return ref.watch(sieCalibrationEngineProvider).status;
});

/// Availability / active profile / health for host UI (no per-frame data).
final sieCalibrationAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieCalibrationAvailability availability,
  SieSensitivityProfileId sensitivity,
  int calibrationVersion,
  SieCalibrationEngineHealth health,
  bool recalibrationRecommended,
  SieRecalibrationReason? recalibrationReason,
  SieCalibrationProfile? profile,
  SieCalibrationEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieCalibrationEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  final profile = status?.activeProfile;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    availability:
        status?.availability ?? SieCalibrationAvailability.missing,
    sensitivity: profile?.sensitivity ?? SieSensitivityProfileId.standard,
    calibrationVersion: profile?.schemaVersion ?? kSieCalibrationSchemaVersion,
    health: status?.health ?? SieCalibrationEngineHealth.idle,
    recalibrationRecommended: status?.recalibrationRecommended ?? false,
    recalibrationReason: status?.recalibrationReason,
    profile: profile,
    status: status,
  );
});
