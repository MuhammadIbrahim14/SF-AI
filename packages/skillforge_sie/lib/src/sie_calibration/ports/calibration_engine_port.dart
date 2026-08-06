import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_engine_status.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_camera_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_display_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_handedness_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_interaction_zone_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_user_calibration.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Calibration Engine port — personalized interaction coordinates.
///
/// Purpose: calibration only (no gestures / cursor).
/// Inputs: [SieSpatialFrameSnapshot] from Spatial Coordinate Engine.
/// Outputs: immutable [SieCalibratedFrameSnapshot] stream (not Riverpod).
abstract interface class CalibrationEnginePort {
  /// Low-frequency status.
  Stream<SieCalibrationEngineStatus> get status;

  /// High-frequency calibrated snapshots — **not** Riverpod (ADR-008).
  Stream<SieCalibratedFrameSnapshot> get snapshots;

  /// Latest status.
  SieCalibrationEngineStatus get currentStatus;

  /// Latest metrics.
  SieCalibrationEngineMetrics get metrics;

  /// Active profile.
  SieCalibrationProfile get activeProfile;

  /// Prepare engine and optionally load persistence.
  Future<void> initialize({bool loadPersisted = true});

  /// Attach to Spatial Coordinate Engine snapshots.
  Future<void> start(Stream<SieSpatialFrameSnapshot> spatialSnapshots);

  /// Detach.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous calibrate for tests / replay.
  SieCalibratedFrameSnapshot process(SieSpatialFrameSnapshot input);

  /// Begin guided session.
  Future<void> beginSession({
    SieCalibrationSessionPhase phase =
        SieCalibrationSessionPhase.firstRun,
  });

  /// Update draft user section (session or live partial).
  Future<void> updateUserCalibration(SieUserCalibration user);

  /// Update draft camera section.
  Future<void> updateCameraCalibration(SieCameraCalibration camera);

  /// Update draft display section.
  Future<void> updateDisplayCalibration(SieDisplayCalibration display);

  /// Update draft handedness section.
  Future<void> updateHandednessCalibration(SieHandednessCalibration handedness);

  /// Update draft interaction zone.
  Future<void> updateInteractionZone(SieInteractionZoneCalibration zone);

  /// Switch sensitivity profile (persists when session completes or immediately
  /// when no session is active).
  Future<void> setSensitivityProfile(SieSensitivityProfileId profile);

  /// Record a normalized validation sample during a session.
  void recordSessionSample(SieSpatialPoint2D normalizedPoint);

  /// Complete session, validate, activate, optionally persist.
  Future<SieCalibrationProfile> completeSession({bool persist = true});

  /// Cancel session without applying draft.
  Future<void> cancelSession();

  /// Apply profile immediately (manual / host).
  Future<void> applyProfile(
    SieCalibrationProfile profile, {
    bool persist = true,
  });

  /// Reset to identity defaults.
  Future<void> resetProfile({bool persist = true});

  /// Persist active profile.
  Future<void> save();

  /// Reload from store (with migration).
  Future<SieCalibrationProfile?> load();

  /// Recommend recalibration without mutating the active profile.
  void recommendRecalibration(SieRecalibrationReason reason);

  /// Clear recalibration recommendation after user acts.
  void clearRecalibrationRecommendation();

  /// Environment signal — recommends recalibration, does not auto-apply.
  void notifyEnvironmentChange(SieRecalibrationReason reason);
}
