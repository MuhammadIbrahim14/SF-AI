import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Configurable interaction regions in normalized view space [0,1].
final class SieInteractionZoneCalibration {
  /// Creates interaction-zone calibration.
  const SieInteractionZoneCalibration({
    this.comfortLeft = 0.08,
    this.comfortTop = 0.08,
    this.comfortRight = 0.92,
    this.comfortBottom = 0.88,
    this.restTop = 0.88,
    this.restBottom = 1.0,
    this.edgeMargin = 0.02,
    this.deadZoneLeft = 0.0,
    this.deadZoneTop = 0.0,
    this.deadZoneRight = 0.0,
    this.deadZoneBottom = 0.0,
    this.reachLimitScale = 1.0,
  });

  /// Identity / default comfort zone.
  static const SieInteractionZoneCalibration identity =
      SieInteractionZoneCalibration();

  /// Comfortable zone left edge [0,1].
  final double comfortLeft;

  /// Comfortable zone top.
  final double comfortTop;

  /// Comfortable zone right.
  final double comfortRight;

  /// Comfortable zone bottom.
  final double comfortBottom;

  /// Rest / lowered-hand zone top (IDS rest zone).
  final double restTop;

  /// Rest zone bottom.
  final double restBottom;

  /// Soft edge margin inside comfort zone.
  final double edgeMargin;

  /// Absolute dead zone from left (normalized).
  final double deadZoneLeft;

  /// Absolute dead zone from top.
  final double deadZoneTop;

  /// Absolute dead zone from right.
  final double deadZoneRight;

  /// Absolute dead zone from bottom.
  final double deadZoneBottom;

  /// Soft reach-limit scale (1 = use comfort bounds).
  final double reachLimitScale;

  /// Comfort rect.
  SieSpatialRect get comfortRect => SieSpatialRect(
        left: comfortLeft,
        top: comfortTop,
        width: (comfortRight - comfortLeft).clamp(0.0, 1.0),
        height: (comfortBottom - comfortTop).clamp(0.0, 1.0),
      );

  /// Whether geometry is usable.
  bool get isValid =>
      comfortLeft < comfortRight &&
      comfortTop < comfortBottom &&
      restTop <= restBottom &&
      edgeMargin >= 0 &&
      reachLimitScale > 0 &&
      deadZoneLeft >= 0 &&
      deadZoneTop >= 0 &&
      deadZoneRight >= 0 &&
      deadZoneBottom >= 0;

  /// Copy with overrides.
  SieInteractionZoneCalibration copyWith({
    double? comfortLeft,
    double? comfortTop,
    double? comfortRight,
    double? comfortBottom,
    double? restTop,
    double? restBottom,
    double? edgeMargin,
    double? deadZoneLeft,
    double? deadZoneTop,
    double? deadZoneRight,
    double? deadZoneBottom,
    double? reachLimitScale,
  }) {
    return SieInteractionZoneCalibration(
      comfortLeft: comfortLeft ?? this.comfortLeft,
      comfortTop: comfortTop ?? this.comfortTop,
      comfortRight: comfortRight ?? this.comfortRight,
      comfortBottom: comfortBottom ?? this.comfortBottom,
      restTop: restTop ?? this.restTop,
      restBottom: restBottom ?? this.restBottom,
      edgeMargin: edgeMargin ?? this.edgeMargin,
      deadZoneLeft: deadZoneLeft ?? this.deadZoneLeft,
      deadZoneTop: deadZoneTop ?? this.deadZoneTop,
      deadZoneRight: deadZoneRight ?? this.deadZoneRight,
      deadZoneBottom: deadZoneBottom ?? this.deadZoneBottom,
      reachLimitScale: reachLimitScale ?? this.reachLimitScale,
    );
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'comfortLeft': comfortLeft,
        'comfortTop': comfortTop,
        'comfortRight': comfortRight,
        'comfortBottom': comfortBottom,
        'restTop': restTop,
        'restBottom': restBottom,
        'edgeMargin': edgeMargin,
        'deadZoneLeft': deadZoneLeft,
        'deadZoneTop': deadZoneTop,
        'deadZoneRight': deadZoneRight,
        'deadZoneBottom': deadZoneBottom,
        'reachLimitScale': reachLimitScale,
      };

  /// Parse JSON.
  static SieInteractionZoneCalibration fromJson(Map<String, Object?> json) {
    return SieInteractionZoneCalibration(
      comfortLeft: (json['comfortLeft'] as num?)?.toDouble() ?? 0.08,
      comfortTop: (json['comfortTop'] as num?)?.toDouble() ?? 0.08,
      comfortRight: (json['comfortRight'] as num?)?.toDouble() ?? 0.92,
      comfortBottom: (json['comfortBottom'] as num?)?.toDouble() ?? 0.88,
      restTop: (json['restTop'] as num?)?.toDouble() ?? 0.88,
      restBottom: (json['restBottom'] as num?)?.toDouble() ?? 1.0,
      edgeMargin: (json['edgeMargin'] as num?)?.toDouble() ?? 0.02,
      deadZoneLeft: (json['deadZoneLeft'] as num?)?.toDouble() ?? 0,
      deadZoneTop: (json['deadZoneTop'] as num?)?.toDouble() ?? 0,
      deadZoneRight: (json['deadZoneRight'] as num?)?.toDouble() ?? 0,
      deadZoneBottom: (json['deadZoneBottom'] as num?)?.toDouble() ?? 0,
      reachLimitScale: (json['reachLimitScale'] as num?)?.toDouble() ?? 1,
    );
  }
}
