import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Low-frequency calibration engine status (Riverpod-safe).
final class SieCalibrationEngineStatus {
  /// Creates status.
  const SieCalibrationEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.availability,
    required this.sessionPhase,
    required this.activeProfile,
    this.recalibrationRecommended = false,
    this.recalibrationReason,
    this.lastError,
    this.lastEvent,
  });

  /// Idle default.
  factory SieCalibrationEngineStatus.idle() => SieCalibrationEngineStatus(
        health: SieCalibrationEngineHealth.idle,
        initialized: false,
        running: false,
        availability: SieCalibrationAvailability.missing,
        sessionPhase: SieCalibrationSessionPhase.idle,
        activeProfile: SieCalibrationProfile.identity(),
      );

  /// Engine health.
  final SieCalibrationEngineHealth health;

  /// Whether initialized.
  final bool initialized;

  /// Whether consuming spatial snapshots.
  final bool running;

  /// Calibration availability.
  final SieCalibrationAvailability availability;

  /// Guided session phase.
  final SieCalibrationSessionPhase sessionPhase;

  /// Active profile.
  final SieCalibrationProfile activeProfile;

  /// Soft recommendation flag (never auto-applied).
  final bool recalibrationRecommended;

  /// Why recalibration is recommended.
  final SieRecalibrationReason? recalibrationReason;

  /// Last error.
  final SieFailure? lastError;

  /// Last event label.
  final String? lastEvent;

  /// Active sensitivity id.
  SieSensitivityProfileId get activeSensitivity => activeProfile.sensitivity;

  /// Schema version.
  int get calibrationVersion => activeProfile.schemaVersion;

  /// Copy with overrides.
  SieCalibrationEngineStatus copyWith({
    SieCalibrationEngineHealth? health,
    bool? initialized,
    bool? running,
    SieCalibrationAvailability? availability,
    SieCalibrationSessionPhase? sessionPhase,
    SieCalibrationProfile? activeProfile,
    bool? recalibrationRecommended,
    SieRecalibrationReason? recalibrationReason,
    bool clearRecalibration = false,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieCalibrationEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      availability: availability ?? this.availability,
      sessionPhase: sessionPhase ?? this.sessionPhase,
      activeProfile: activeProfile ?? this.activeProfile,
      recalibrationRecommended: clearRecalibration
          ? false
          : (recalibrationRecommended ?? this.recalibrationRecommended),
      recalibrationReason: clearRecalibration
          ? null
          : (recalibrationReason ?? this.recalibrationReason),
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics for the Calibration Engine.
final class SieCalibrationEngineMetrics {
  /// Creates metrics.
  const SieCalibrationEngineMetrics({
    this.framesProcessed = 0,
    this.landmarksCalibrated = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
    this.recalibrationRequests = 0,
    this.profileSaves = 0,
    this.profileLoads = 0,
    this.migrations = 0,
    this.sessionCompletions = 0,
  });

  /// Frames processed.
  final int framesProcessed;

  /// Landmarks calibrated.
  final int landmarksCalibrated;

  /// Mean processing time.
  final double averageProcessingMs;

  /// Last processing time.
  final double lastProcessingMs;

  /// Recalibration recommendation / request count.
  final int recalibrationRequests;

  /// Successful saves.
  final int profileSaves;

  /// Successful loads.
  final int profileLoads;

  /// Schema migrations applied.
  final int migrations;

  /// Completed guided sessions.
  final int sessionCompletions;

  /// Copy with overrides.
  SieCalibrationEngineMetrics copyWith({
    int? framesProcessed,
    int? landmarksCalibrated,
    double? averageProcessingMs,
    double? lastProcessingMs,
    int? recalibrationRequests,
    int? profileSaves,
    int? profileLoads,
    int? migrations,
    int? sessionCompletions,
  }) {
    return SieCalibrationEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      landmarksCalibrated: landmarksCalibrated ?? this.landmarksCalibrated,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
      recalibrationRequests:
          recalibrationRequests ?? this.recalibrationRequests,
      profileSaves: profileSaves ?? this.profileSaves,
      profileLoads: profileLoads ?? this.profileLoads,
      migrations: migrations ?? this.migrations,
      sessionCompletions: sessionCompletions ?? this.sessionCompletions,
    );
  }
}
