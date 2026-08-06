import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_config.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_enums.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_detected_hand.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_hand_landmark.dart';

/// Result of validating one hand's landmarks.
final class SieLandmarkValidationResult {
  /// Creates a validation result.
  const SieLandmarkValidationResult({
    required this.isValid,
    this.reason,
  });

  /// Passed.
  factory SieLandmarkValidationResult.ok() =>
      const SieLandmarkValidationResult(isValid: true);

  /// Failed.
  factory SieLandmarkValidationResult.fail(SieLandmarkRejectionReason reason) =>
      SieLandmarkValidationResult(isValid: false, reason: reason);

  /// Whether the set may proceed to normalization.
  final bool isValid;

  /// Rejection reason when invalid.
  final SieLandmarkRejectionReason? reason;
}

/// Validates raw vision landmarks (integrity only — no gestures).
final class SieLandmarkValidator {
  /// Creates a validator.
  const SieLandmarkValidator(this.config);

  /// Active config.
  final SieLandmarkEngineConfig config;

  /// Validates a detected hand's landmark list.
  SieLandmarkValidationResult validateHand(SieDetectedHand hand) {
    final landmarks = hand.landmarks;
    if (landmarks.length < config.minLandmarkCount ||
        landmarks.length != config.expectedLandmarkCount) {
      return SieLandmarkValidationResult.fail(
        SieLandmarkRejectionReason.invalidCount,
      );
    }

    for (final lm in landmarks) {
      if (_isNan(lm)) {
        return SieLandmarkValidationResult.fail(
          SieLandmarkRejectionReason.nanValue,
        );
      }
      if (_isInfinite(lm)) {
        return SieLandmarkValidationResult.fail(
          SieLandmarkRejectionReason.infiniteValue,
        );
      }
      if (_outOfSoftRange(lm)) {
        return SieLandmarkValidationResult.fail(
          SieLandmarkRejectionReason.outOfRange,
        );
      }
    }

    if (config.rejectCollapsedHands && _isCollapsed(landmarks)) {
      return SieLandmarkValidationResult.fail(
        SieLandmarkRejectionReason.collapsedStructure,
      );
    }

    // Confidence consistency: reject NaN confidence.
    if (hand.handConfidence.isNaN ||
        hand.handednessScore.isNaN ||
        hand.handConfidence.isInfinite ||
        hand.handednessScore.isInfinite) {
      return SieLandmarkValidationResult.fail(
        SieLandmarkRejectionReason.corrupted,
      );
    }

    return SieLandmarkValidationResult.ok();
  }

  bool _isNan(SieHandLandmark lm) =>
      lm.x.isNaN || lm.y.isNaN || lm.z.isNaN;

  bool _isInfinite(SieHandLandmark lm) =>
      lm.x.isInfinite || lm.y.isInfinite || lm.z.isInfinite;

  bool _outOfSoftRange(SieHandLandmark lm) {
    return lm.x < config.coordinateMin ||
        lm.x > config.coordinateMax ||
        lm.y < config.coordinateMin ||
        lm.y > config.coordinateMax;
  }

  bool _isCollapsed(List<SieHandLandmark> landmarks) {
    final first = landmarks.first;
    for (var i = 1; i < landmarks.length; i++) {
      final d = landmarks[i];
      if ((d.x - first.x).abs() > config.collapsedEpsilon ||
          (d.y - first.y).abs() > config.collapsedEpsilon ||
          (d.z - first.z).abs() > config.collapsedEpsilon) {
        return false;
      }
    }
    return true;
  }
}
