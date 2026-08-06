import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_engine_status.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_snapshot.dart';

/// Confidence Engine port — authoritative tracking reliability.
///
/// Purpose: confidence evaluation only (no gestures / cursor).
/// Inputs: [SieCalibratedFrameSnapshot] from Calibration Engine.
/// Outputs: immutable [SieConfidenceFrameSnapshot] stream (not Riverpod).
abstract interface class ConfidenceEnginePort {
  /// Low-frequency status.
  Stream<SieConfidenceEngineStatus> get status;

  /// High-frequency confidence snapshots — **not** Riverpod (ADR-008).
  Stream<SieConfidenceFrameSnapshot> get snapshots;

  /// Latest status.
  SieConfidenceEngineStatus get currentStatus;

  /// Latest metrics.
  SieConfidenceEngineMetrics get metrics;

  /// Active policy.
  SieConfidencePolicy get policy;

  /// Prepare engine.
  Future<void> initialize({SieConfidencePolicy? policy});

  /// Attach to Calibration Engine snapshots.
  Future<void> start(Stream<SieCalibratedFrameSnapshot> calibratedSnapshots);

  /// Detach.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous evaluate for tests / replay.
  SieConfidenceFrameSnapshot process(SieCalibratedFrameSnapshot input);

  /// Switch confidence policy (thresholds only).
  Future<void> setPolicy(SieConfidencePolicyId policyId);

  /// Enable / disable tracking (Disabled state).
  void setEnabled(bool enabled);
}
