/// Display / logical-size calibration (immutable).
final class SieDisplayCalibration {
  /// Creates display calibration.
  const SieDisplayCalibration({
    this.referenceLogicalWidth = 1280,
    this.referenceLogicalHeight = 720,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.devicePixelRatioRef = 1.0,
    this.browserZoom = 1.0,
  });

  /// Identity defaults.
  static const SieDisplayCalibration identity = SieDisplayCalibration();

  /// Reference logical width when profile was built.
  final double referenceLogicalWidth;

  /// Reference logical height when profile was built.
  final double referenceLogicalHeight;

  /// Extra host scale X (browser zoom compensation when known).
  final double scaleX;

  /// Extra host scale Y.
  final double scaleY;

  /// DPR at calibration time (diagnostic + soft gain).
  final double devicePixelRatioRef;

  /// Browser zoom factor when available (1 = 100%).
  final double browserZoom;

  /// Whether values are usable.
  bool get isValid =>
      referenceLogicalWidth > 0 &&
      referenceLogicalHeight > 0 &&
      scaleX.isFinite &&
      scaleX > 0 &&
      scaleY.isFinite &&
      scaleY > 0 &&
      devicePixelRatioRef > 0 &&
      browserZoom.isFinite &&
      browserZoom > 0;

  /// Copy with overrides.
  SieDisplayCalibration copyWith({
    double? referenceLogicalWidth,
    double? referenceLogicalHeight,
    double? scaleX,
    double? scaleY,
    double? devicePixelRatioRef,
    double? browserZoom,
  }) {
    return SieDisplayCalibration(
      referenceLogicalWidth:
          referenceLogicalWidth ?? this.referenceLogicalWidth,
      referenceLogicalHeight:
          referenceLogicalHeight ?? this.referenceLogicalHeight,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      devicePixelRatioRef: devicePixelRatioRef ?? this.devicePixelRatioRef,
      browserZoom: browserZoom ?? this.browserZoom,
    );
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'referenceLogicalWidth': referenceLogicalWidth,
        'referenceLogicalHeight': referenceLogicalHeight,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'devicePixelRatioRef': devicePixelRatioRef,
        'browserZoom': browserZoom,
      };

  /// Parse JSON.
  static SieDisplayCalibration fromJson(Map<String, Object?> json) {
    return SieDisplayCalibration(
      referenceLogicalWidth:
          (json['referenceLogicalWidth'] as num?)?.toDouble() ?? 1280,
      referenceLogicalHeight:
          (json['referenceLogicalHeight'] as num?)?.toDouble() ?? 720,
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1,
      devicePixelRatioRef:
          (json['devicePixelRatioRef'] as num?)?.toDouble() ?? 1,
      browserZoom: (json['browserZoom'] as num?)?.toDouble() ?? 1,
    );
  }
}
