import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_camera_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_display_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_handedness_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_interaction_zone_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_user_calibration.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Mutable builder for a guided calibration session (engine-internal state).
///
/// Host UI drives this via [CalibrationEnginePort] methods — no Flutter widgets.
final class SieCalibrationSession {
  /// Creates a session.
  SieCalibrationSession({
    required this.phase,
    required this.startedAt,
    SieCalibrationProfile? baseline,
  })  : draft = (baseline ?? SieCalibrationProfile.identity(now: startedAt))
            .copyWith(
          profileId: baseline?.isIdentity == false
              ? baseline!.profileId
              : 'user_default',
          isIdentity: false,
          validated: false,
          updatedAt: startedAt,
          createdAt: baseline?.isIdentity == false
              ? baseline!.createdAt
              : startedAt,
        );

  /// Session phase.
  SieCalibrationSessionPhase phase;

  /// Start time.
  final DateTime startedAt;

  /// Working profile draft.
  SieCalibrationProfile draft;

  /// Optional fingertip samples in normalized space (validation).
  final List<SieSpatialPoint2D> samples = [];

  /// Apply user section.
  void applyUser(SieUserCalibration user) {
    draft = draft.copyWith(user: user, updatedAt: DateTime.now().toUtc());
  }

  /// Apply camera section.
  void applyCamera(SieCameraCalibration camera) {
    draft = draft.copyWith(camera: camera, updatedAt: DateTime.now().toUtc());
  }

  /// Apply display section.
  void applyDisplay(SieDisplayCalibration display) {
    draft = draft.copyWith(display: display, updatedAt: DateTime.now().toUtc());
  }

  /// Apply handedness section.
  void applyHandedness(SieHandednessCalibration handedness) {
    draft = draft.copyWith(
      handedness: handedness,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Apply interaction zone.
  void applyInteractionZone(SieInteractionZoneCalibration zone) {
    draft = draft.copyWith(
      interactionZone: zone,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Apply sensitivity.
  void applySensitivity(SieSensitivityProfileId sensitivity) {
    draft = draft.copyWith(
      sensitivity: sensitivity,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Record a normalized sample for validation.
  void recordSample(SieSpatialPoint2D normalizedPoint) {
    if (samples.length < 64) {
      samples.add(normalizedPoint);
    }
  }

  /// Whether draft is structurally valid.
  bool get isDraftValid => draft.isValid;

  /// Simple validation: enough samples inside comfort zone (when samples exist).
  bool validateSamples({int minSamples = 3}) {
    if (samples.isEmpty) return isDraftValid;
    if (samples.length < minSamples) return false;
    final zone = draft.interactionZone.comfortRect;
    var inside = 0;
    for (final s in samples) {
      if (zone.contains(s)) inside++;
    }
    return inside >= (samples.length / 2).ceil();
  }
}
