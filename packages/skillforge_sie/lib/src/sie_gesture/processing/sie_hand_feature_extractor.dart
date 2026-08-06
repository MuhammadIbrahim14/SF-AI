import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_hand_landmark_index.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Per-frame hand geometric features for classifiers (immutable).
final class SieHandGestureFeatures {
  /// Creates features.
  const SieHandGestureFeatures({
    required this.handId,
    required this.pinchDistance,
    required this.openness,
    required this.fistCurl,
    required this.indexTip,
    required this.indexTipScreen,
    required this.palmCenter,
    required this.tipVelocity,
    required this.valid,
  });

  /// Invalid / missing hand.
  static const SieHandGestureFeatures invalid = SieHandGestureFeatures(
    handId: -1,
    pinchDistance: 1,
    openness: 0,
    fistCurl: 1,
    indexTip: SieSpatialPoint2D.zero,
    indexTipScreen: SieSpatialPoint2D.zero,
    palmCenter: SieSpatialPoint2D.zero,
    tipVelocity: SieSpatialPoint2D.zero,
    valid: false,
  );

  /// Hand id.
  final int handId;

  /// Thumb–index tip distance (normalized).
  final double pinchDistance;

  /// Mean finger extension score [0,1].
  final double openness;

  /// Mean tip-to-MCP curl; low ⇒ fist.
  final double fistCurl;

  /// Index fingertip normalized position (classifier geometry).
  final SieSpatialPoint2D indexTip;

  /// Index fingertip in screen logical pixels (cursor / pointer).
  final SieSpatialPoint2D indexTipScreen;

  /// Approximate palm center.
  final SieSpatialPoint2D palmCenter;

  /// Index tip velocity (normalized / ms).
  final SieSpatialPoint2D tipVelocity;

  /// Whether features were computed from a full hand.
  final bool valid;
}

/// Extracts gesture features from calibrated landmarks.
final class SieHandFeatureExtractor {
  /// Creates extractor.
  const SieHandFeatureExtractor();

  /// Extract features; [previousTip] enables velocity.
  SieHandGestureFeatures extract({
    required SieCalibratedHandSnapshot hand,
    SieSpatialPoint2D? previousTip,
    double? previousTimestampMs,
    required double timestampMs,
  }) {
    if (hand.landmarks.length < 21) {
      return SieHandGestureFeatures.invalid;
    }

    SieSpatialPoint2D tip(int index) {
      for (final lm in hand.landmarks) {
        if (lm.index == index) return lm.normalizedCalibrated;
      }
      return SieSpatialPoint2D.zero;
    }

    // Prefer spatial Flutter pixels (already screen-space); then calibrated.
    SieSpatialPoint2D tipScreen(int index) {
      for (final lm in hand.landmarks) {
        if (lm.index != index) continue;
        final flutter = lm.originalFlutter;
        if (flutter.x.abs() > 1 || flutter.y.abs() > 1) return flutter;
        final c = lm.calibrated;
        if (c.x.abs() > 1 || c.y.abs() > 1) return c;
        return flutter;
      }
      return SieSpatialPoint2D.zero;
    }

    final thumb = tip(SieHandLandmarkIndex.thumbTip);
    final index = tip(SieHandLandmarkIndex.indexTip);
    final indexScreen = tipScreen(SieHandLandmarkIndex.indexTip);
    final middle = tip(SieHandLandmarkIndex.middleTip);
    final ring = tip(SieHandLandmarkIndex.ringTip);
    final pinky = tip(SieHandLandmarkIndex.pinkyTip);
    final indexMcp = tip(SieHandLandmarkIndex.indexMcp);
    final middleMcp = tip(SieHandLandmarkIndex.middleMcp);
    final ringMcp = tip(13);
    final pinkyMcp = tip(SieHandLandmarkIndex.pinkyMcp);
    final wrist = tip(SieHandLandmarkIndex.wrist);

    final pinch = _dist(thumb, index);
    final curl = (_dist(index, indexMcp) +
            _dist(middle, middleMcp) +
            _dist(ring, ringMcp) +
            _dist(pinky, pinkyMcp)) /
        4.0;

    final span = _dist(indexMcp, pinkyMcp).clamp(0.05, 1.0);
    final open = ((_dist(index, wrist) +
                _dist(middle, wrist) +
                _dist(ring, wrist) +
                _dist(pinky, wrist)) /
            4.0 /
            span)
        .clamp(0.0, 1.5) /
        1.5;

    final palm = SieSpatialPoint2D(
      (wrist.x + indexMcp.x + pinkyMcp.x) / 3,
      (wrist.y + indexMcp.y + pinkyMcp.y) / 3,
    );

    var velocity = SieSpatialPoint2D.zero;
    if (previousTip != null &&
        previousTimestampMs != null &&
        timestampMs > previousTimestampMs) {
      final dt = timestampMs - previousTimestampMs;
      velocity = SieSpatialPoint2D(
        (index.x - previousTip.x) / dt,
        (index.y - previousTip.y) / dt,
      );
    }

    return SieHandGestureFeatures(
      handId: hand.handId,
      pinchDistance: pinch,
      openness: open.toDouble(),
      fistCurl: curl,
      indexTip: index,
      indexTipScreen: indexScreen,
      palmCenter: palm,
      tipVelocity: velocity,
      valid: true,
    );
  }

  static double _dist(SieSpatialPoint2D a, SieSpatialPoint2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
