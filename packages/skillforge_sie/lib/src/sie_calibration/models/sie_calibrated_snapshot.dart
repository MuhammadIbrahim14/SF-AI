import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Per-landmark calibrated coordinates.
final class SieCalibratedLandmark {
  /// Creates a calibrated landmark.
  const SieCalibratedLandmark({
    required this.index,
    required this.originalFlutter,
    required this.calibrated,
    required this.normalizedCalibrated,
    required this.inDeadZone,
    required this.inRestZone,
    required this.clamped,
    this.z = 0,
    this.visibility,
    this.presence,
  });

  /// Topology index.
  final int index;

  /// Original spatial Flutter logical point.
  final SieSpatialPoint2D originalFlutter;

  /// Calibrated Flutter logical point (canonical for downstream).
  final SieSpatialPoint2D calibrated;

  /// Calibrated position in normalized view [0,1].
  final SieSpatialPoint2D normalizedCalibrated;

  /// Whether point fell into a dead zone before clamp.
  final bool inDeadZone;

  /// Whether point is in the rest zone.
  final bool inRestZone;

  /// Whether calibrated point was clamped to interaction bounds.
  final bool clamped;

  /// Preserved depth.
  final double z;

  /// Preserved visibility.
  final double? visibility;

  /// Preserved presence.
  final double? presence;
}

/// Immutable calibrated hand snapshot.
final class SieCalibratedHandSnapshot {
  /// Creates a hand snapshot.
  const SieCalibratedHandSnapshot({
    required this.handId,
    required this.handedness,
    required this.handednessScore,
    required this.handConfidence,
    required this.landmarks,
    required this.resolvedHandedness,
    required this.mirrored,
  });

  /// Hand id.
  final int handId;

  /// Vision/spatial handedness (preserved).
  final SieHandedness handedness;

  /// Preserved handedness score.
  final double handednessScore;

  /// Preserved hand confidence.
  final double handConfidence;

  /// Calibrated landmarks.
  final List<SieCalibratedLandmark> landmarks;

  /// Handedness used for calibration decisions.
  final SieCalibratedHandedness resolvedHandedness;

  /// Whether X was mirrored for interaction.
  final bool mirrored;

  /// Index fingertip when present.
  SieCalibratedLandmark? get indexFingertip {
    for (final lm in landmarks) {
      if (lm.index == 8) return lm;
    }
    return landmarks.isEmpty ? null : landmarks.first;
  }
}

/// Immutable frame-level calibrated snapshot (canonical for Confidence+).
final class SieCalibratedFrameSnapshot {
  /// Creates a frame snapshot.
  const SieCalibratedFrameSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.visionTrackingState,
    required this.profile,
    required this.hands,
    required this.processingMs,
    this.viewWidth = 0,
    this.viewHeight = 0,
  });

  /// Empty helper.
  factory SieCalibratedFrameSnapshot.empty({
    required DateTime timestamp,
    required int frameSequence,
    required SieVisionTrackingState visionTrackingState,
    required SieCalibrationProfile profile,
    double processingMs = 0,
    double viewWidth = 0,
    double viewHeight = 0,
  }) {
    return SieCalibratedFrameSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      visionTrackingState: visionTrackingState,
      profile: profile,
      hands: const [],
      processingMs: processingMs,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
    );
  }

  /// Preserved timestamp.
  final DateTime timestamp;

  /// Preserved frame sequence.
  final int frameSequence;

  /// Preserved vision tracking state.
  final SieVisionTrackingState visionTrackingState;

  /// Active calibration profile (immutable reference).
  final SieCalibrationProfile profile;

  /// Calibrated hands.
  final List<SieCalibratedHandSnapshot> hands;

  /// Calibration processing time (ms).
  final double processingMs;

  /// View width used for this frame.
  final double viewWidth;

  /// View height used for this frame.
  final double viewHeight;

  /// Primary hand.
  SieCalibratedHandSnapshot? get primaryHand =>
      hands.isEmpty ? null : hands.first;

  /// Whether any hand present.
  bool get hasHand => hands.isNotEmpty;

  /// Calibration schema version on this snapshot.
  int get calibrationVersion => profile.schemaVersion;
}
