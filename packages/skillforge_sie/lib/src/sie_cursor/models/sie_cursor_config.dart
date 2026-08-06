import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Motion filter / prediction / acceleration / snap tunables.
final class SieCursorMotionConfig {
  /// Creates config.
  const SieCursorMotionConfig({
    this.smoothingAlpha = 0.28,
    this.minSmoothingAlpha = 0.12,
    this.maxSmoothingAlpha = 0.40,
    this.velocityAdaptive = true,
    this.jitterEpsilon = 0.8,
    this.spikeThreshold = 40,
    this.predictionHorizonMs = 24,
    this.maxPredictionPx = 12,
    this.predictionEnabled = false,
    this.accelerationGain = 1.0,
    this.precisionGain = 0.75,
    this.fastGain = 1.35,
    this.accessibilityGain = 0.9,
    this.snapEnabled = true,
    this.snapRadius = 28,
    this.snapStrength = 0.35,
    this.snapReleaseHysteresis = 1.35,
    this.edgeResistance = 0.25,
    this.safeMargin = 0,
    this.idleHideMs = 8000,
    this.fadeInMs = 120,
    this.fadeOutMs = 220,
    this.lostTrackingFadeOpacity = 0.35,
    this.hoverAcquireMs = 80,
    this.reducedMotion = false,
  });

  /// Standard profile.
  static const SieCursorMotionConfig standard = SieCursorMotionConfig();

  /// Precision.
  static const SieCursorMotionConfig precision = SieCursorMotionConfig(
    smoothingAlpha: 0.28,
    accelerationGain: 0.75,
    precisionGain: 0.65,
    fastGain: 1.0,
    snapRadius: 22,
    snapStrength: 0.25,
  );

  /// Fast.
  static const SieCursorMotionConfig fast = SieCursorMotionConfig(
    smoothingAlpha: 0.45,
    accelerationGain: 1.0,
    fastGain: 1.35,
    predictionHorizonMs: 32,
    maxPredictionPx: 16,
    snapStrength: 0.3,
  );

  /// Accessibility.
  static const SieCursorMotionConfig accessibility = SieCursorMotionConfig(
    smoothingAlpha: 0.22,
    minSmoothingAlpha: 0.12,
    maxSmoothingAlpha: 0.4,
    accelerationGain: 0.9,
    accessibilityGain: 0.85,
    jitterEpsilon: 1.2,
    snapRadius: 36,
    snapStrength: 0.4,
    idleHideMs: 12000,
    reducedMotion: true,
  );

  /// EMA base alpha (higher = more responsive).
  final double smoothingAlpha;

  /// Adaptive floor.
  final double minSmoothingAlpha;

  /// Adaptive ceiling.
  final double maxSmoothingAlpha;

  /// Velocity-aware alpha.
  final bool velocityAdaptive;

  /// Ignore sub-pixel jitter below this (logical px).
  final double jitterEpsilon;

  /// Cap raw delta spikes (logical px / frame).
  final double spikeThreshold;

  /// Prediction look-ahead (ms).
  final double predictionHorizonMs;

  /// Max prediction offset (logical px).
  final double maxPredictionPx;

  /// Master prediction switch.
  final bool predictionEnabled;

  /// Base gain for standard profile.
  final double accelerationGain;

  /// Precision profile gain.
  final double precisionGain;

  /// Fast profile gain (IDS: off while Armed).
  final double fastGain;

  /// Accessibility gain.
  final double accessibilityGain;

  /// Magnetic snap master.
  final bool snapEnabled;

  /// Snap engage radius (logical px).
  final double snapRadius;

  /// Pull strength [0,1].
  final double snapStrength;

  /// Release radius multiplier vs engage.
  final double snapReleaseHysteresis;

  /// Edge soft resistance [0,1].
  final double edgeResistance;

  /// Extra clamp inset (logical px).
  final double safeMargin;

  /// Hide after idle (ms); 0 = never.
  final double idleHideMs;

  /// Fade-in duration.
  final double fadeInMs;

  /// Fade-out duration.
  final double fadeOutMs;

  /// Opacity while LostTracking.
  final double lostTrackingFadeOpacity;

  /// Hover acquire dwell (ms) for state.
  final double hoverAcquireMs;

  /// Reduced motion — skip pulse animations.
  final bool reducedMotion;

  /// Whether config is usable.
  bool get isValid =>
      smoothingAlpha > 0 &&
      smoothingAlpha <= 1 &&
      minSmoothingAlpha > 0 &&
      maxSmoothingAlpha >= minSmoothingAlpha &&
      maxPredictionPx >= 0 &&
      snapRadius >= 0 &&
      snapStrength >= 0 &&
      snapStrength <= 1;

  /// Lookup by motion profile.
  static SieCursorMotionConfig forProfile(SieCursorMotionProfileId id) {
    return switch (id) {
      SieCursorMotionProfileId.standard => standard,
      SieCursorMotionProfileId.precision => precision,
      SieCursorMotionProfileId.fast => fast,
      SieCursorMotionProfileId.accessibility => accessibility,
    };
  }
}

/// Display bounds for clamping.
final class SieCursorDisplayBounds {
  /// Creates bounds.
  const SieCursorDisplayBounds({
    required this.width,
    required this.height,
    this.marginLeft = 0,
    this.marginTop = 0,
    this.marginRight = 0,
    this.marginBottom = 0,
    this.devicePixelRatio = 1,
  });

  /// Default 800×600.
  static const SieCursorDisplayBounds fallback = SieCursorDisplayBounds(
    width: 800,
    height: 600,
  );

  /// Logical width.
  final double width;

  /// Logical height.
  final double height;

  /// Safe margins.
  final double marginLeft;

  /// Top.
  final double marginTop;

  /// Right.
  final double marginRight;

  /// Bottom.
  final double marginBottom;

  /// DPR (diagnostic).
  final double devicePixelRatio;

  /// Whether usable.
  bool get isValid => width > 0 && height > 0;

  /// Clampable rect.
  SieSpatialRect get usable => SieSpatialRect(
    left: marginLeft,
    top: marginTop,
    width: (width - marginLeft - marginRight).clamp(0, width),
    height: (height - marginTop - marginBottom).clamp(0, height),
  );

  /// Copy.
  SieCursorDisplayBounds copyWith({
    double? width,
    double? height,
    double? marginLeft,
    double? marginTop,
    double? marginRight,
    double? marginBottom,
    double? devicePixelRatio,
  }) {
    return SieCursorDisplayBounds(
      width: width ?? this.width,
      height: height ?? this.height,
      marginLeft: marginLeft ?? this.marginLeft,
      marginTop: marginTop ?? this.marginTop,
      marginRight: marginRight ?? this.marginRight,
      marginBottom: marginBottom ?? this.marginBottom,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }
}

/// Optional snap target supplied by host (hit-test external).
final class SieCursorSnapTarget {
  /// Creates target.
  const SieCursorSnapTarget({
    required this.id,
    required this.center,
    this.radius,
    this.isLarge = true,
  });

  /// Target id.
  final String id;

  /// Snap center (logical).
  final SieSpatialPoint2D center;

  /// Optional override radius.
  final double? radius;

  /// IDS: snap on large targets only.
  final bool isLarge;
}

/// Full engine configuration.
final class SieCursorEngineConfig {
  /// Creates config.
  const SieCursorEngineConfig({
    this.theme = SieCursorThemeId.standard,
    this.motionProfile = SieCursorMotionProfileId.standard,
    this.motion = SieCursorMotionConfig.standard,
    this.bounds = SieCursorDisplayBounds.fallback,
    this.snapDisabledBySecurity = false,
    this.securitySensitiveRoute = false,
  });

  /// Theme (appearance).
  final SieCursorThemeId theme;

  /// Motion profile id.
  final SieCursorMotionProfileId motionProfile;

  /// Motion tunables.
  final SieCursorMotionConfig motion;

  /// Display bounds.
  final SieCursorDisplayBounds bounds;

  /// Host forces snap off (L3/admin dense).
  final bool snapDisabledBySecurity;

  /// Route marked security-sensitive.
  final bool securitySensitiveRoute;

  /// Effective snap permission.
  bool get snapAllowed =>
      motion.snapEnabled && !snapDisabledBySecurity && !securitySensitiveRoute;

  /// Copy.
  SieCursorEngineConfig copyWith({
    SieCursorThemeId? theme,
    SieCursorMotionProfileId? motionProfile,
    SieCursorMotionConfig? motion,
    SieCursorDisplayBounds? bounds,
    bool? snapDisabledBySecurity,
    bool? securitySensitiveRoute,
  }) {
    return SieCursorEngineConfig(
      theme: theme ?? this.theme,
      motionProfile: motionProfile ?? this.motionProfile,
      motion: motion ?? this.motion,
      bounds: bounds ?? this.bounds,
      snapDisabledBySecurity:
          snapDisabledBySecurity ?? this.snapDisabledBySecurity,
      securitySensitiveRoute:
          securitySensitiveRoute ?? this.securitySensitiveRoute,
    );
  }
}
