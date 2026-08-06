import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_hand_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Deterministic spatial → calibrated transform.
///
/// Applies user, camera, display, handedness, zone, and sensitivity calibration.
final class SieCalibrationTransformPipeline {
  /// Creates the pipeline.
  const SieCalibrationTransformPipeline();

  /// Calibrate one landmark.
  SieCalibratedLandmark transformLandmark({
    required SieSpatialLandmark landmark,
    required SieCalibrationProfile profile,
    required double viewWidth,
    required double viewHeight,
    required bool mirrorX,
  }) {
    final w = viewWidth <= 0 ? 1.0 : viewWidth;
    final h = viewHeight <= 0 ? 1.0 : viewHeight;

    // 1) Flutter → normalized view
    var nx = (landmark.flutter.x / w).clamp(0.0, 1.0).toDouble();
    var ny = (landmark.flutter.y / h).clamp(0.0, 1.0).toDouble();

    // 2) Camera offsets / soft pitch bias
    final cam = profile.camera;
    nx = (nx - cam.offsetX).clamp(0.0, 1.0).toDouble();
    ny = (ny - cam.offsetY).clamp(0.0, 1.0).toDouble();
    final pitchRad = cam.anglePitchDegrees * math.pi / 180.0;
    final pitchBias = math.sin(pitchRad) * 0.05 * cam.distanceEstimate;
    ny = (ny - pitchBias + (cam.heightNormalized - 0.5) * 0.04)
        .clamp(0.0, 1.0)
        .toDouble();

    // 3) User reach scale about preferred zone center
    final user = profile.user;
    final reach = (user.armLengthScale * user.comfortableReachScale)
        .clamp(0.25, 3.0)
        .toDouble();
    nx = user.preferredZoneCenterX +
        (nx - user.preferredZoneCenterX) / reach;
    ny = user.preferredZoneCenterY +
        (ny - user.preferredZoneCenterY) / reach;

    // 4) Map preferred / comfort zone → full interactive plane
    final zone = profile.interactionZone;
    final comfort = zone.comfortRect;
    final cx = comfort.width <= 0
        ? 0.5
        : ((nx - comfort.left) / comfort.width).clamp(0.0, 1.0).toDouble();
    final cy = comfort.height <= 0
        ? 0.5
        : ((ny - comfort.top) / comfort.height).clamp(0.0, 1.0).toDouble();

    // Expand slightly by reachLimitScale around center
    final rls = zone.reachLimitScale.clamp(0.5, 2.0).toDouble();
    var mx = 0.5 + (cx - 0.5) * rls;
    var my = 0.5 + (cy - 0.5) * rls;

    // 5) Sensitivity gain about center
    final sens = profile.sensitivityParameters;
    mx = 0.5 + (mx - 0.5) * sens.gain;
    my = 0.5 + (my - 0.5) * sens.gain;

    // Mild tremor damping (pull toward center)
    if (sens.tremorDamping > 0) {
      mx = mx + (0.5 - mx) * sens.tremorDamping;
      my = my + (0.5 - my) * sens.tremorDamping;
    }

    // Soft edge (blend toward center near edges)
    if (sens.edgeSoftness > 0) {
      final edgeX = math.min(mx, 1.0 - mx);
      final edgeY = math.min(my, 1.0 - my);
      final edge = math.min(edgeX, edgeY);
      if (edge < zone.edgeMargin + 1e-9) {
        final t = (edge / (zone.edgeMargin + 1e-9)).clamp(0.0, 1.0);
        final blend = (1.0 - t) * sens.edgeSoftness;
        mx = mx + (0.5 - mx) * blend;
        my = my + (0.5 - my) * blend;
      }
    }

    // 6) Handedness mirror
    if (mirrorX) {
      mx = 1.0 - mx;
    }

    // 7) Display scale / browser zoom (about center)
    final disp = profile.display;
    final sx = (disp.scaleX / disp.browserZoom).clamp(0.25, 4.0).toDouble();
    final sy = (disp.scaleY / disp.browserZoom).clamp(0.25, 4.0).toDouble();
    mx = 0.5 + (mx - 0.5) * sx;
    my = 0.5 + (my - 0.5) * sy;

    // Relative display size vs reference (responsive layouts)
    if (disp.referenceLogicalWidth > 0 && disp.referenceLogicalHeight > 0) {
      final aspectNow = w / h;
      final aspectRef =
          disp.referenceLogicalWidth / disp.referenceLogicalHeight;
      if (aspectRef > 0 && aspectNow.isFinite) {
        final aspectCorr = (aspectNow / aspectRef).clamp(0.5, 2.0).toDouble();
        mx = 0.5 + (mx - 0.5) * math.sqrt(aspectCorr);
      }
    }

    // Zone classification before clamp
    final inRest = my >= zone.restTop && my <= zone.restBottom;
    final dzL = zone.deadZoneLeft + sens.deadZoneBoost;
    final dzT = zone.deadZoneTop + sens.deadZoneBoost;
    final dzR = zone.deadZoneRight + sens.deadZoneBoost;
    final dzB = zone.deadZoneBottom + sens.deadZoneBoost;
    final inDead = mx < dzL ||
        mx > 1.0 - dzR ||
        my < dzT ||
        my > 1.0 - dzB;

    // 8) Clamp to [0,1] interaction plane
    final beforeX = mx;
    final beforeY = my;
    mx = mx.clamp(0.0, 1.0).toDouble();
    my = my.clamp(0.0, 1.0).toDouble();
    final clamped = beforeX != mx || beforeY != my || inDead;

    return SieCalibratedLandmark(
      index: landmark.index,
      originalFlutter: landmark.flutter,
      calibrated: SieSpatialPoint2D(mx * w, my * h),
      normalizedCalibrated: SieSpatialPoint2D(mx, my),
      inDeadZone: inDead,
      inRestZone: inRest,
      clamped: clamped,
      z: landmark.z,
      visibility: landmark.visibility,
      presence: landmark.presence,
    );
  }

  /// Resolve effective handedness for a spatial hand.
  ({SieCalibratedHandedness resolved, bool mirrorX}) resolveHandedness({
    required SieCalibrationProfile profile,
    required SieHandedness visionHandedness,
  }) {
    final pref = profile.handedness.effectivePreference;
    final resolved = switch (pref) {
      SieCalibratedHandedness.right => SieCalibratedHandedness.right,
      SieCalibratedHandedness.left => SieCalibratedHandedness.left,
      SieCalibratedHandedness.auto => switch (visionHandedness) {
          SieHandedness.left => SieCalibratedHandedness.left,
          SieHandedness.right => SieCalibratedHandedness.right,
          SieHandedness.unknown => SieCalibratedHandedness.right,
        },
    };
    final mirror = profile.handedness.mirrorInteractionForLeft &&
        resolved == SieCalibratedHandedness.left;
    return (resolved: resolved, mirrorX: mirror);
  }

  /// Calibrate one hand.
  SieCalibratedHandSnapshot transformHand({
    required SieSpatialHandSnapshot hand,
    required SieCalibrationProfile profile,
    required double viewWidth,
    required double viewHeight,
  }) {
    final handed = resolveHandedness(
      profile: profile,
      visionHandedness: hand.handedness,
    );
    final landmarks = <SieCalibratedLandmark>[
      for (final lm in hand.landmarks)
        transformLandmark(
          landmark: lm,
          profile: profile,
          viewWidth: viewWidth,
          viewHeight: viewHeight,
          mirrorX: handed.mirrorX,
        ),
    ];
    return SieCalibratedHandSnapshot(
      handId: hand.handId,
      handedness: hand.handedness,
      handednessScore: hand.handednessScore,
      handConfidence: hand.handConfidence,
      landmarks: List.unmodifiable(landmarks),
      resolvedHandedness: handed.resolved,
      mirrored: handed.mirrorX,
    );
  }
}
